# Shared Pester E2E test helper — ensures PSU is running and provides Run-OnPSU functions.
#
# Usage in E2E test BeforeAll:
#   $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..path..')
#   . (Join-Path $projectRoot 'psu-app' 'Tests' 'E2E' 'PesterE2EHelper.ps1')
#   Initialize-PesterE2E -ProjectRoot $projectRoot

function script:Initialize-PesterE2E {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [int]$TimeoutSeconds = 120
    )

    Import-Module (Join-Path $ProjectRoot 'Devolutions.CIEM.Admin' 'Devolutions.CIEM.Admin.psd1') -Force

    $psuUrl = 'http://localhost:5001'
    $healthUrl = "$psuUrl/api/v1/alive"
    $isReady = $false

    try {
        $response = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5 -ErrorAction Stop
        $isReady = $response.loading -eq $false
    } catch {
        $isReady = $false
    }

    if (-not $isReady) {
        Write-Host '[pester-e2e] PSU not ready, starting...'
        $setupScript = Join-Path $ProjectRoot 'scripts' 'setup-local-psu.sh'
        & bash $setupScript start --no-wait

        $startTime = Get-Date
        $deadline = $startTime.AddSeconds($TimeoutSeconds)

        while ((Get-Date) -lt $deadline) {
            try {
                $response = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5 -ErrorAction Stop
                if ($response.loading -eq $false) {
                    $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
                    Write-Host "[pester-e2e] PSU is ready (took ${elapsed}s)"
                    $isReady = $true
                    break
                }
            } catch {}
            Start-Sleep -Seconds 2
        }

        if (-not $isReady) {
            throw "PSU server did not become ready within ${TimeoutSeconds}s"
        }
    } else {
        Write-Host '[pester-e2e] PSU is already running.'
    }

    Connect-PSU -Local | Out-Null
}

function script:Run-OnPSU {
    param(
        [Parameter(Mandatory)][string]$Command,
        [int]$TimeoutSeconds = 60
    )

    $wrappedCommand = @"
`$ErrorActionPreference = 'Continue'
`$__result = & { $Command }
if (`$null -ne `$__result) { `$__result | ConvertTo-Json -Depth 5 -Compress } else { '___NULL___' }
"@
    $allOutput = @(Invoke-TestCommand -ScriptBlock ([scriptblock]::Create($wrappedCommand)) -TimeoutSeconds $TimeoutSeconds)
    $jobResult = $allOutput | Where-Object { $_.PSObject.Properties.Name -contains 'JobId' } | Select-Object -Last 1

    if (-not $jobResult) { throw "PSU command returned no job result." }
    if ($jobResult.Status -eq 'Failed') {
        $errMsgs = @($jobResult.Output) | Where-Object { $_.type -eq 4 } | ForEach-Object { $_.message }
        throw "PSU command failed: $($errMsgs -join '; ')"
    }
    if ($jobResult.Status -notin @('Completed', 'Warning')) {
        throw "PSU job $($jobResult.JobId) did not complete. Status: $($jobResult.Status)"
    }

    $pipelineItems = @($jobResult.PipelineOutput)
    if ($pipelineItems.Count -eq 0) { return $null }

    $lastItem = $pipelineItems[-1]
    $jsonDataStr = $lastItem.jsonData
    if (-not $jsonDataStr) { return $null }

    $jsonEntries = $jsonDataStr | ConvertFrom-Json
    $rawValue = ($jsonEntries | Select-Object -Last 1).value

    if ($rawValue -eq '___NULL___') { return $null }

    try { $rawValue | ConvertFrom-Json }
    catch { $rawValue }
}

function script:Run-OnPSU-LongRunning {
    param(
        [Parameter(Mandatory)][string]$Command,
        [int]$TimeoutSeconds = 600
    )

    $wrappedCommand = @"
`$ErrorActionPreference = 'Continue'
`$__result = & { $Command }
if (`$null -ne `$__result) { `$__result | ConvertTo-Json -Depth 5 -Compress } else { '___NULL___' }
"@
    # Start the job with a short timeout — we just need the job ID
    $allOutput = @(Invoke-TestCommand -ScriptBlock ([scriptblock]::Create($wrappedCommand)) -TimeoutSeconds 5)
    $jobResult = $allOutput | Where-Object { $_.PSObject.Properties.Name -contains 'JobId' } | Select-Object -Last 1

    if (-not $jobResult -or -not $jobResult.JobId) { throw "PSU command returned no job result." }

    $jobId = $jobResult.JobId
    Write-Host "Started PSU job $jobId, waiting up to ${TimeoutSeconds}s..."

    # Wait for completion using PSU's gRPC-based Wait-PSUJob
    Wait-PSUJob -JobId $jobId -Timeout $TimeoutSeconds | Out-Null

    # Get final status (Status is PowerShellUniversal.JobStatus enum — string comparison works)
    $finalJob = Get-PSUJob -Id $jobId
    $statusName = "$($finalJob.Status)"

    if ($statusName -eq 'Failed') {
        $errOutput = Get-PSUJobOutput -JobId $jobId
        $errMsgs = @($errOutput) | Where-Object { $_.Type -eq 4 } | ForEach-Object { $_.Message }
        throw "PSU job $jobId failed: $($errMsgs -join '; ')"
    }
    if ($statusName -notin @('Completed', 'Warning')) {
        throw "PSU job $jobId did not complete within ${TimeoutSeconds}s. Status: $statusName"
    }

    Write-Host "PSU job $jobId completed with status: $statusName"

    # Get-PSUJobPipelineOutput returns raw strings (the JSON our wrapper emitted)
    $pipelineOutput = Get-PSUJobPipelineOutput -JobId $jobId
    if (-not $pipelineOutput) { return $null }

    $rawValue = @($pipelineOutput)[-1]
    if ($rawValue -eq '___NULL___') { return $null }

    try { $rawValue | ConvertFrom-Json }
    catch { $rawValue }
}
