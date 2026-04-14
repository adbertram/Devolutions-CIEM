function New-CIEMDatabase {
    <#
    .SYNOPSIS
        Creates and initializes the CIEM SQLite database.
    .DESCRIPTION
        Creates the CIEM database file using the schema.sql definition with all
        19 tables. Safe to call multiple times — all CREATE statements use
        IF NOT EXISTS.

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

    $modulesDir = Join-Path $script:ModuleRoot 'modules'
    foreach ($providerName in @('Azure', 'AWS')) {
        $catalogFile = Join-Path $modulesDir "$providerName/Checks/check_catalog.json"
        if (Test-Path $catalogFile) {
            SyncCIEMCheckCatalog -Provider $providerName
        }
    }

    if ($PassThru) {
        $Path
    }
}
