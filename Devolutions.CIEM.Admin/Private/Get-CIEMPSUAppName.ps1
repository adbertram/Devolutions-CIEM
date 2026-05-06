function Get-CIEMPSUAppName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ModulePath
    )

    $ErrorActionPreference = 'Stop'

    $appName = $script:DefaultAppName
    $dashboardsPath = Join-Path -Path $ModulePath -ChildPath '.universal' -AdditionalChildPath 'dashboards.ps1'
    if (Test-Path $dashboardsPath) {
        $dashboardContent = Get-Content $dashboardsPath -Raw
        if ($dashboardContent -match "New-PSUApp\s+-Name\s+'([^']+)'") {
            $appName = $matches[1]
        }
    }

    $appName
}
