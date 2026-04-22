function Invoke-CIEMQuery {
    <#
    .SYNOPSIS
        Executes a SQL query against the CIEM SQLite database.
    .DESCRIPTION
        Wraps Invoke-PSUSQLiteQuery with explicit database path resolution.
        The database must already be initialized before queries run.

        For transaction support, pass an existing connection from
        Open-PSUSQLiteConnection via the -Connection parameter.
    .PARAMETER Query
        The SQL statement to execute.
    .PARAMETER Parameters
        Hashtable of query parameters for parameterized queries.
    .PARAMETER AsNonQuery
        Execute as a non-query (INSERT/UPDATE/DELETE/DDL). Returns affected row count.
    .PARAMETER Connection
        An existing open SqliteConnection for transaction support.
    .EXAMPLE
        Invoke-CIEMQuery -Query "SELECT * FROM providers"
    .EXAMPLE
        Invoke-CIEMQuery -Query "INSERT INTO providers (id, name, type, enabled, created_at, updated_at) VALUES (@id, @name, @type, @enabled, @now, @now)" -Parameters @{ id = 'azure'; name = 'Azure'; type = 'Azure'; enabled = 1; now = (Get-Date).ToString('o') } -AsNonQuery
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [hashtable]$Parameters,

        [switch]$AsNonQuery,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    $ErrorActionPreference = 'Stop'

    $databasePath = Get-CIEMDatabasePath
    if (-not (Test-Path $databasePath)) {
        throw "CIEM database is not initialized at '$databasePath'. Open Configuration and initialize the database before running queries."
    }

    $invokeParams = @{
        Query = $Query
    }

    if ($Connection) {
        $invokeParams.Connection = $Connection
    } else {
        # Open a connection with foreign keys enabled (PRAGMAs are per-connection in SQLite)
        $ownConn = Open-PSUSQLiteConnection -Database $databasePath
        Invoke-PSUSQLiteQuery -Connection $ownConn -Query "PRAGMA foreign_keys=ON" -AsNonQuery | Out-Null
        $invokeParams.Connection = $ownConn
    }

    if ($Parameters) {
        $invokeParams.Parameters = $Parameters
    }

    if ($AsNonQuery) {
        $invokeParams.AsNonQuery = $true
    }

    try {
        Invoke-PSUSQLiteQuery @invokeParams
    }
    finally {
        if ($ownConn) { $ownConn.Dispose() }
    }
}
