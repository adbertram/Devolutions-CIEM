# Shared Pester E2E test helper — ensures PSU is running and provides Run-OnPSU functions.
#
# Usage in E2E test BeforeAll:
#   $projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..path..')
#   . (Join-Path $projectRoot 'psu-app' 'Tests' 'E2E' 'PesterE2EHelper.ps1')
#   Initialize-PesterE2E -ProjectRoot $projectRoot

function script:Initialize-PesterE2E {
    param(
        [Parameter(Mandatory)][string]$ProjectRoot,
        [ValidateSet('local', 'azure')]
        [string]$Environment = $(if ($env:CIEM_TEST_ENVIRONMENT) { $env:CIEM_TEST_ENVIRONMENT } else { 'local' }),
        [int]$TimeoutSeconds = 120
    )

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $ProjectRoot 'Devolutions.CIEM.Admin' 'Devolutions.CIEM.Admin.psd1')

    $script:PesterE2EEnvironment = $Environment

    $urlVariableByEnvironment = @{
        local = 'LOCAL_PSU_URL'
        azure = 'AZURE_PSU_URL'
    }
    $urlVariable = $urlVariableByEnvironment[$Environment]

    # Read the target PSU URL from .env.
    $envFile = Join-Path $ProjectRoot '.env'
    $psuUrl = $null
    $publishPointSsh = $null
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match "^$urlVariable=(.+)$") {
                $psuUrl = $matches[1].Trim()
            }
            if ($_ -match '^PUBLISH_POINT_SSH=(.+)$') {
                $publishPointSsh = $matches[1].Trim()
            }
        }
    }
    if (-not $psuUrl) { throw "$urlVariable not found in $envFile" }
    $healthUrl = "$psuUrl/api/v1/alive"
    $isReady = $false
    $lastHealthError = $null

    try {
        $response = Invoke-RestMethod -Uri $healthUrl -TimeoutSec 5 -ErrorAction Stop
        $isReady = $response.loading -eq $false
    } catch {
        $lastHealthError = $_.Exception.Message
        $isReady = $false
    }

    if (-not $isReady) {
        if ($Environment -eq 'azure') {
            throw "Azure PSU is not ready at $healthUrl. Last health error: $lastHealthError"
        }

        if (-not $publishPointSsh) { throw "PUBLISH_POINT_SSH not found in $envFile" }

        Write-Host "[pester-e2e] Local PSU not ready, starting via $publishPointSsh..."
        & ssh $publishPointSsh "sudo launchctl kickstart -k system/com.psu.server"

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
            } catch {
                $lastHealthError = $_.Exception.Message
            }
            Start-Sleep -Seconds 2
        }

        if (-not $isReady) {
            throw "PSU server did not become ready within ${TimeoutSeconds}s. Last health error: $lastHealthError"
        }
    } else {
        Write-Host "[pester-e2e] $Environment PSU is already running."
    }

    if ($Environment -eq 'local') {
        Connect-PSU -Local | Out-Null
    }
    else {
        Connect-PSU | Out-Null
    }
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
    $allOutput = @(Invoke-TestCommand -ScriptBlock ([scriptblock]::Create($wrappedCommand)) -Environment $script:PesterE2EEnvironment -TimeoutSeconds $TimeoutSeconds)
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

    Run-OnPSU -Command $Command -TimeoutSeconds $TimeoutSeconds
}
