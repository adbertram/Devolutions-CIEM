$ErrorActionPreference = 'Stop'

function Invoke-CIEMPSUSetup {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $ErrorActionPreference = 'Stop'

    $dashboardResourcePath = Join-Path -Path $script:ModuleRoot -ChildPath '.universal/dashboards.ps1'
    if (-not (Test-Path -Path $dashboardResourcePath -PathType Leaf)) {
        throw "CIEM PSU app registration resource not found: $dashboardResourcePath"
    }

    $dashboardResourceContent = Get-Content -Path $dashboardResourcePath -Raw
    foreach ($requiredPattern in @(
            'New-PSUApp',
            "-Name\s+'Devolutions CIEM'",
            "-BaseUrl\s+'/ciem'",
            "-Module\s+'Devolutions\.CIEM'",
            "-Command\s+'New-DevolutionsCIEMApp'"
        )) {
        if ($dashboardResourceContent -notmatch $requiredPattern) {
            throw "CIEM PSU app registration resource is missing required pattern: $requiredPattern"
        }
    }

    $scriptResourcePath = Join-Path -Path $script:ModuleRoot -ChildPath '.universal/scripts.ps1'
    if (-not (Test-Path -Path $scriptResourcePath -PathType Leaf)) {
        throw "CIEM PSU script registration resource not found: $scriptResourcePath"
    }

    $scriptResourceContent = Get-Content -Path $scriptResourcePath -Raw
    foreach ($requiredPattern in @(
            'New-PSUScript',
            "-Module\s+'Devolutions\.CIEM'",
            "-Command\s+'New-CIEMScanRun'",
            "-Command\s+'Start-CIEMAzureDiscovery'",
            "-Command\s+'Invoke-CIEMAttackPathRemediation'",
            'ManagedBy=Devolutions\.CIEM;Source=data/psu-scripts\.json'
        )) {
        if ($scriptResourceContent -notmatch $requiredPattern) {
            throw "CIEM PSU script registration resource is missing required pattern: $requiredPattern"
        }
    }

    $scriptDefinitions = @(Get-CIEMPSUScriptDefinition)
    if ($scriptDefinitions.Count -lt 1) {
        throw 'CIEM PSU script definitions could not be resolved from the module package.'
    }

    $databasePath = New-CIEMDatabase -PassThru
    if ([string]::IsNullOrWhiteSpace([string]$databasePath)) {
        throw 'New-CIEMDatabase did not return a database path.'
    }
    if (-not (Test-Path -Path $databasePath -PathType Leaf)) {
        throw "CIEM database was not created at '$databasePath'."
    }

    foreach ($tableName in @('providers', 'provider_auth_methods', 'checks', 'attack_path_rules')) {
        $tableRows = @(Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type = 'table' AND name = '$tableName'")
        if ($tableRows.Count -ne 1) {
            throw "CIEM database verification failed: table '$tableName' was not created."
        }

        $countRows = @(Invoke-CIEMQuery -Query "SELECT COUNT(*) AS RowCount FROM $tableName")
        if ($countRows.Count -ne 1 -or -not $countRows[0].PSObject.Properties['RowCount']) {
            throw "CIEM database verification failed: table '$tableName' did not return a row count."
        }
        if ([int]$countRows[0].RowCount -lt 1) {
            throw "CIEM database verification failed: table '$tableName' contains no rows."
        }
    }

    [pscustomobject]@{
        DashboardResourcePath = $dashboardResourcePath
        ScriptResourcePath    = $scriptResourcePath
        ExpectedScriptCount   = $scriptDefinitions.Count
        DatabasePath          = $databasePath
        DatabaseInitialized   = $true
        Status                = 'Initialized'
    }
}

Invoke-CIEMPSUSetup | Out-Null
