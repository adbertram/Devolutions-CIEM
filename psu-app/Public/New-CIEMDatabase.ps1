function New-CIEMDatabase {
    <#
    .SYNOPSIS
        Creates and initializes the CIEM SQLite database.
    .DESCRIPTION
        Creates the CIEM database file, applies provider schemas, and syncs
        static database catalogs. Safe to call multiple times because schema
        creation uses idempotent SQL and catalog sync upserts current data.

        The database is stored inside the psu-app package root at data/ciem.db.
    .PARAMETER Path
        Explicit path to the database file. If omitted, auto-resolved based on
        the runtime context (PSU or local dev).
    .PARAMETER SchemaPath
        Explicit path to the schema SQL file. If omitted, resolved from
        Get-CIEMDefaultConfig relative to the module root.
    .PARAMETER PassThru
        Returns the database file path.
    .EXAMPLE
        New-CIEMDatabase
    .EXAMPLE
        New-CIEMDatabase -Path '/home/data/ciem.db' -PassThru
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$SchemaPath,
        [switch]$PassThru
    )

    $ErrorActionPreference = 'Stop'

    $config = Get-CIEMDefaultConfig

    # Resolve database path — uses $script:DataRoot (set in psm1) which is already
    # resolved to be outside the module version directory so data survives upgrades.
    if (-not $Path) {
        if (-not $script:DataRoot) {
            throw 'New-CIEMDatabase: $script:DataRoot is not set. Module not loaded correctly.'
        }
        $Path = Join-Path $script:DataRoot 'ciem.db'
    }

    # Resolve schema path
    if (-not $SchemaPath) {
        if (-not $script:ModuleRoot) {
            throw 'New-CIEMDatabase: Cannot resolve schema path — $script:ModuleRoot is not set. Provide -SchemaPath explicitly.'
        }
        $SchemaPath = Join-Path $script:ModuleRoot $config.database.schemaPath
    }

    # Validate schema file exists
    if (-not (Test-Path $SchemaPath)) {
        throw "New-CIEMDatabase: Schema file not found at '$SchemaPath'"
    }

    # Ensure the parent directory exists
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
        Write-Verbose "CIEM DB: Created directory $dir"
    }

    $isNew = -not (Test-Path $Path)

    # Read and execute schema SQL. The schema MUST be fully idempotent — every
    # CREATE TABLE / CREATE INDEX uses IF NOT EXISTS, and ALTER TABLE migrations
    # that have been baked into the CREATE TABLE definitions must be removed
    # from the file. If a statement throws, that is a real bug — fail fast.
    $schemaSql = Get-Content -Path $SchemaPath -Raw
    $conn = Open-PSUSQLiteConnection -Database $Path
    try {
        foreach ($statement in ($schemaSql -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-PSUSQLiteQuery -Connection $conn -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    } finally {
        $conn.Dispose()
    }

    if ($isNew) {
        Write-Verbose "CIEM DB: Created new database at $Path"
    } else {
        Write-Verbose "CIEM DB: Database at $Path is up to date"
    }

    # Store path in module scope for other functions
    $script:DatabasePath = $Path

    foreach ($schema in @(
        @{ Path = Join-Path $script:AzureRoot          'Data/azure_schema.sql';     Label = 'Azure' }
        @{ Path = Join-Path $script:AzureDiscoveryRoot 'Data/discovery_schema.sql'; Label = 'AzureDiscovery' }
        @{ Path = Join-Path $script:GraphRoot          'Data/graph_schema.sql';     Label = 'Graph' }
    )) {
        $dbPath = Get-CIEMDatabasePath
        if (-not $dbPath) {
            throw "Database path not resolved for $($schema.Label) schema."
        }
        if (-not (Test-Path $schema.Path)) {
            throw "Schema file not found: $($schema.Path)"
        }

        $providerSchemaSql = Get-Content -Path $schema.Path -Raw
        $providerSchemaConnection = Open-PSUSQLiteConnection -Database $dbPath
        try {
            foreach ($statement in ($providerSchemaSql -split ';\s*\n' | Where-Object { $_.Trim() })) {
                Invoke-PSUSQLiteQuery -Connection $providerSchemaConnection -Query $statement.Trim() -AsNonQuery | Out-Null
            }
        }
        finally {
            $providerSchemaConnection.Dispose()
        }
    }

    UpdateCIEMAttackPathStorageSchema
    $attackPathRuleSync = Sync-CIEMAttackPathRuleCatalog
    Write-Verbose "CIEM DB: Synced $($attackPathRuleSync.RuleCount) attack path rules"

    SyncCIEMCheckCatalog -Provider 'Azure'

    if ($PassThru) {
        $Path
    }
}
