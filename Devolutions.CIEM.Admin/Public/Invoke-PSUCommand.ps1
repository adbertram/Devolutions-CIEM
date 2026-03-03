function Invoke-PSUCommand {
    <#
    .SYNOPSIS
        Executes a PowerShell command on the PSU server and returns the output.

    .DESCRIPTION
        Creates a temporary script on the PSU server, executes it, waits for completion,
        retrieves the output, and cleans up the temporary script.

    .PARAMETER Command
        The PowerShell command to execute as a string.

    .PARAMETER ScriptBlock
        The PowerShell command to execute as a script block.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the command to complete. Defaults to 120 seconds.

    .PARAMETER KeepScript
        If specified, does not delete the temporary script after execution.

    .PARAMETER Environment
        The PSU environment to run the script in.

    .EXAMPLE
        Invoke-PSUCommand -Command 'Get-Module -ListAvailable'

    .EXAMPLE
        Invoke-PSUCommand -ScriptBlock { Get-Process | Select-Object -First 5 }
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
        [switch]$KeepScript,

        [Parameter()]
        [string]$Environment
    )

    # Auto-connect if not connected
    if (-not $script:PSUConnection.Url -or -not $script:PSUConnection.Token) {
        Write-Verbose "Not connected to PSU. Attempting auto-connect..."
        try {
            $null = Connect-PSU -ErrorAction Stop
            Write-Verbose "Connected to PSU."
        }
        catch {
            throw "Not connected to PSU and auto-connect failed: $_"
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
        $Command = $ScriptBlock.ToString()
    }

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json'
    }

    $baseUrl = $script:PSUConnection.Url
    $scriptId = $null
    $jobId = $null

    try {
        # Step 1: Create a temporary script
        $scriptName = "InvokePSUCommand_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$([guid]::NewGuid().ToString('N').Substring(0, 8)).ps1"

        Write-Verbose "Creating temporary script: $scriptName"

        $scriptBody = @{
            name        = $scriptName
            fullPath    = $scriptName
            content     = $Command
            description = 'Temporary script created by Invoke-PSUCommand'
            maxHistory  = 1
        }

        if ($Environment) {
            $scriptBody.environment = $Environment
        }

        $scriptJson = $scriptBody | ConvertTo-Json -Depth 10

        $createScriptUri = "$baseUrl/api/v1/script"
        $script:lastScript = Invoke-RestMethod -Uri $createScriptUri -Headers $headers -Method Post -Body $scriptJson -ErrorAction Stop
        $scriptId = $script:lastScript.id

        Write-Verbose "Created script with ID: $scriptId"

        # Step 2: Invoke the script
        Write-Verbose "Invoking script..."

        $invokeUri = "$baseUrl/api/v1/script/$scriptId"
        $invokeBody = @{} | ConvertTo-Json

        $jobResponse = Invoke-RestMethod -Uri $invokeUri -Headers $headers -Method Post -Body $invokeBody -ErrorAction Stop

        if ($jobResponse -is [int] -or $jobResponse -is [long]) {
            $jobId = $jobResponse
        }
        elseif ($jobResponse.id) {
            $jobId = $jobResponse.id
        }
        else {
            throw "Unexpected job response format: $($jobResponse | ConvertTo-Json -Compress)"
        }

        Write-Verbose "Started job with ID: $jobId"

        # Step 3: Poll for job completion
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
                Write-Warning "Job timed out after ${TimeoutSeconds}s. Status: $statusName"
                break
            }

            Write-Verbose "Job status: $statusName (elapsed: $([math]::Round($elapsed.TotalSeconds, 1))s)"

        } while ($jobStatus -notin $terminalStatuses)

        $finalStatusName = $statusNames[$jobStatus]
        Write-Verbose "Job completed with status: $finalStatusName"

        # Step 4: Get job output
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
    catch {
        throw "Failed to execute command on PSU: $_"
    }
    finally {
        # Archive the job by running a tiny script inside PSU.
        # PSU has no external API to archive jobs; Microsoft.Data.Sqlite
        # (available in the PSU process) is the only reliable way.
        if ($jobId) {
            $archiveScriptId = $null
            try {
                Write-Verbose "Archiving job (ID: $jobId)..."
                $archiveScriptName = "ArchiveJob_${jobId}.ps1"
                $archiveContent = "`$dbPath = Join-Path (Split-Path `$Repository -Parent) 'database.db'; `$conn = [Microsoft.Data.Sqlite.SqliteConnection]::new(`"Data Source=`$dbPath`"); `$conn.Open(); `$cmd = `$conn.CreateCommand(); `$cmd.CommandText = 'UPDATE Job SET Archived = 1 WHERE ScriptFullPath LIKE ''InvokePSUCommand_%'' OR ScriptFullPath LIKE ''ArchiveJob_%'''; `$null = `$cmd.ExecuteNonQuery(); `$conn.Close(); `$conn.Dispose()"
                $archiveBody = @{
                    name        = $archiveScriptName
                    fullPath    = $archiveScriptName
                    content     = $archiveContent
                    description = 'Auto-cleanup by Invoke-PSUCommand'
                    maxHistory  = 1
                } | ConvertTo-Json -Depth 10

                $archiveScript = Invoke-RestMethod -Uri "$baseUrl/api/v1/script" -Headers $headers -Method Post -Body $archiveBody -ErrorAction Stop
                $archiveScriptId = $archiveScript.id

                $archiveJobResponse = Invoke-RestMethod -Uri "$baseUrl/api/v1/script/$archiveScriptId" -Headers $headers -Method Post -Body '{}' -ErrorAction Stop
                $archiveJobId = if ($archiveJobResponse -is [int] -or $archiveJobResponse -is [long]) { $archiveJobResponse } else { $archiveJobResponse.id }

                # Wait briefly for the archive script to complete
                $archiveStart = Get-Date
                do {
                    Start-Sleep -Milliseconds 250
                    $archiveJobDetails = Invoke-RestMethod -Uri "$baseUrl/api/v1/job/$archiveJobId" -Headers $headers -Method Get -ErrorAction Stop
                } while ([int]$archiveJobDetails.status -notin @(2, 3, 5, 9, 10, 11) -and ((Get-Date) - $archiveStart).TotalSeconds -lt 10)

                Write-Verbose "Job archived."
            }
            catch {
                Write-Verbose "Failed to archive job: $_"
            }
            finally {
                # Clean up the archive script and its job
                if ($archiveScriptId) {
                    try {
                        $null = Invoke-RestMethod -Uri "$baseUrl/api/v1/script/$archiveScriptId" -Headers $headers -Method Delete -ErrorAction SilentlyContinue
                    }
                    catch {}
                }
            }
        }

        if ($scriptId -and -not $KeepScript) {
            Write-Verbose "Cleaning up temporary script (ID: $scriptId)..."
            try {
                $deleteUri = "$baseUrl/api/v1/script/$scriptId"
                $null = Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction SilentlyContinue
                Write-Verbose "Temporary script deleted."
            }
            catch {
                Write-Warning "Failed to delete temporary script: $_"
            }
        }
        elseif ($KeepScript -and $scriptId) {
            Write-Verbose "Keeping temporary script (ID: $scriptId, Name: $scriptName)"
        }
    }
}
