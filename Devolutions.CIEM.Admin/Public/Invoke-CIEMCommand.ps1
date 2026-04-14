function Invoke-CIEMCommand {
    <#
    .SYNOPSIS
        Executes a PowerShell command on the PSU server and returns the output.

    .DESCRIPTION
        Uses a persistent executor script on the PSU server to run arbitrary commands.
        The executor script is created once and reused across invocations — no temp
        scripts are created or deleted.

    .PARAMETER Command
        The PowerShell command to execute as a string.

    .PARAMETER ScriptBlock
        The PowerShell command to execute as a script block.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the command to complete. Defaults to 120 seconds.

    .PARAMETER Environment
        The PSU environment to run the script in.

    .EXAMPLE
        Invoke-CIEMCommand -Command 'Get-Module -ListAvailable'

    .EXAMPLE
        Invoke-CIEMCommand -ScriptBlock { Get-Process | Select-Object -First 5 }
    #>
    [CmdletBinding(DefaultParameterSetName = 'Command')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'CLI tooling requires visual output for command results')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Command', Position = 0)]
        [string]$Command,

        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock')]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$TimeoutSeconds = 120,

        [Parameter()]
        [string]$Environment
    )

    $ErrorActionPreference = 'Stop'

    Assert-PSUConnection

    if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
        $Command = $ScriptBlock.ToString()
    }

    $headers = @{
        'Authorization'              = "Bearer $($script:PSUConnection.Token)"
        'Accept'                     = 'application/json'
        'Content-Type'               = 'application/json'
        # ngrok free tunnels inject a browser-warning HTML interstitial for
        # GET requests from browser-like User-Agents (PowerShell included).
        # Without this header, /api/v1/script returns HTML instead of the
        # script list, the executor lookup silently returns nothing, and
        # the code tries to POST a duplicate script.
        'ngrok-skip-browser-warning' = 'true'
    }

    $baseUrl = $script:PSUConnection.Url

    # --- Ensure persistent executor script exists ---
    $executorName = 'CIEMExecutor.ps1'
    $executorContent = @'
param([string]$ScriptContent)
& ([scriptblock]::Create($ScriptContent))
'@

    # Check if executor already exists
    $scripts = Invoke-RestMethod -Uri "$baseUrl/api/v1/script" -Headers $headers -Method Get -ErrorAction Stop
    $executor = $scripts | Where-Object { $_.name -eq $executorName }

    if (-not $executor) {
        Write-Verbose "Creating persistent executor script..."
        $scriptBody = @{
            name        = $executorName
            fullPath    = $executorName
            content     = $executorContent
            description = 'Persistent executor for Invoke-CIEMCommand'
            maxHistory  = 100
        } | ConvertTo-Json -Depth 10

        $executor = Invoke-RestMethod -Uri "$baseUrl/api/v1/script" -Headers $headers -Method Post -Body $scriptBody -ErrorAction Stop
        Write-Verbose "Created executor script with ID: $($executor.id)"
    }

    $scriptId = $executor.id

    # --- Invoke with the command as a parameter ---
    Write-Verbose "Invoking executor (script ID: $scriptId)..."

    $encodedCommand = [System.Uri]::EscapeDataString($Command)
    $invokeUri = "$baseUrl/api/v1/script/$scriptId`?ScriptContent=$encodedCommand"
    if ($Environment) {
        $invokeUri += "&Environment=$([System.Uri]::EscapeDataString($Environment))"
    }

    $jobResponse = Invoke-RestMethod -Uri $invokeUri -Headers $headers -Method Post -Body '{}' -ErrorAction Stop

    $jobId = if ($jobResponse -is [int] -or $jobResponse -is [long]) {
        $jobResponse
    } elseif ($jobResponse.id) {
        $jobResponse.id
    } else {
        throw "Unexpected job response format: $($jobResponse | ConvertTo-Json -Compress)"
    }

    Write-Verbose "Started job with ID: $jobId"

    # --- Poll for job completion ---
    Write-Verbose "Waiting for job to complete (timeout: ${TimeoutSeconds}s)..."

    $startTime = Get-Date
    $jobStatus = $null
    $terminalStatuses = @(2, 3, 5, 9, 10)  # Completed, Failed, Canceled, TimedOut, Warning
    $statusNames = @{
        0  = 'Queued'
        1  = 'Running'
        2  = 'Completed'
        3  = 'Failed'
        4  = 'WaitingOnFeedback'
        5  = 'Canceled'
        6  = 'Canceling'
        7  = 'Historical'
        8  = 'Active'
        9  = 'TimedOut'
        10 = 'Warning'
    }

    do {
        Start-Sleep -Milliseconds 500

        $jobUri = "$baseUrl/api/v1/job/$jobId"
        $jobDetails = Invoke-RestMethod -Uri $jobUri -Headers $headers -Method Get -ErrorAction Stop
        $jobStatus = [int]$jobDetails.status
        $statusName = $statusNames[$jobStatus]

        $elapsed = (Get-Date) - $startTime
        if ($elapsed.TotalSeconds -ge $TimeoutSeconds) {
            throw "Job timed out after ${TimeoutSeconds}s. Status: $statusName"
        }

        Write-Verbose "Job status: $statusName (elapsed: $([math]::Round($elapsed.TotalSeconds, 1))s)"

    } while ($jobStatus -notin $terminalStatuses)

    $finalStatusName = $statusNames[$jobStatus]
    Write-Verbose "Job completed with status: $finalStatusName"

    # --- Get job output ---
    $outputUri = "$baseUrl/api/v1/job/$jobId/output"
    $output = Invoke-RestMethod -Uri $outputUri -Headers $headers -Method Get -ErrorAction Stop

    $pipelineUri = "$baseUrl/api/v1/job/$jobId/pipelineOutput"
    $pipelineOutput = $null
    try {
        $pipelineOutput = Invoke-RestMethod -Uri $pipelineUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
    }
    catch {
        Write-Verbose "No pipeline output available or error retrieving it."
    }

    $result = [PSCustomObject]@{
        JobId          = $jobId
        ScriptId       = $scriptId
        Status         = $finalStatusName
        Output         = $output
        PipelineOutput = $pipelineOutput
        StartTime      = $jobDetails.startTime
        EndTime        = $jobDetails.endTime
    }

    if ($output) {
        Write-Host "`n--- Command Output ---" -ForegroundColor Cyan
        $output | ForEach-Object {
            if ($_ -is [string]) {
                Write-Host $_
            }
            elseif ($_.message) {
                Write-Host $_.message
            }
            elseif ($_.data) {
                Write-Host $_.data
            }
            else {
                Write-Host ($_ | Out-String)
            }
        }
        Write-Host "--- End Output ---`n" -ForegroundColor Cyan
    }

    if ($pipelineOutput) {
        Write-Verbose "Pipeline output available. Access via result.PipelineOutput"
    }

    $result
}
