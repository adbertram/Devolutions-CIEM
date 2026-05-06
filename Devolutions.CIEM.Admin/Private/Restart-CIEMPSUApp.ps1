function Restart-CIEMPSUApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath,

        [Parameter(Mandatory)]
        [int]$StepNumber
    )

    $ErrorActionPreference = 'Stop'

    Write-Host ''
    Write-Host "Step ${StepNumber}: Restarting app..." -ForegroundColor Yellow
    $appName = Get-CIEMPSUAppName -ModulePath $ModulePath
    Stop-PSUApp -Name $appName
    Start-PSUApp -Name $appName
    Write-Host "  [OK] App '$appName' restarted" -ForegroundColor Green

    Write-Host ''
    Write-Host "Step $($StepNumber + 1): Verifying app is healthy..." -ForegroundColor Yellow
    $healthUrl = "$($script:PSUConnection.Url)/api/v1/alive"
    $healthy = $false
    for ($i = 1; $i -le 10; $i++) {
        Write-Host "  Checking health (attempt $i/10)..." -ForegroundColor Gray
        try {
            $resp = Invoke-RestMethod -Uri $healthUrl -Headers @{ 'ngrok-skip-browser-warning' = 'true' } -Method Get -TimeoutSec 5 -ErrorAction Stop
            if ($resp.loading -eq $false -and $resp.hasError -eq $false) {
                $healthy = $true
                break
            }
            Write-Host "  Still loading: $($resp.loadingInfo)" -ForegroundColor Gray
        }
        catch {
            Write-Host '  Not responding yet...' -ForegroundColor Gray
        }
        Start-Sleep -Seconds 3
    }
    if (-not $healthy) {
        throw "App failed health check after restart. $healthUrl did not return healthy within 30 seconds."
    }
    Write-Host '  [OK] App is healthy' -ForegroundColor Green
}
