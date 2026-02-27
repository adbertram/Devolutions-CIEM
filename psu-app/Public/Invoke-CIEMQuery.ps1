function Invoke-CIEMQuery {
    <#
    .SYNOPSIS
        Executes a SQL query against the CIEM SQLite database.
    .DESCRIPTION
        Wraps Invoke-PSUSQLiteQuery with automatic database path resolution.
        If $script:DatabasePath is not set, lazy-initializes the database via
        New-CIEMDatabase.

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
        Invoke-CIEMQuery -Query "INSERT INTO providers (id, name, type, enabled, is_default, created_at, updated_at) VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)" -Parameters @{ id = 'azure'; name = 'Azure'; type = 'Azure'; enabled = 1; is_default = 1; now = (Get-Date).ToString('o') } -AsNonQuery
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [hashtable]$Parameters,

        [switch]$AsNonQuery,

        [Parameter()]
        $Connection
    )

    # Lazy-init: resolve database path if not already set
    if (-not $script:DatabasePath) {
        $script:DatabasePath = New-CIEMDatabase -PassThru
    }

    $invokeParams = @{
        Query = $Query
    }

    if ($Connection) {
        $invokeParams.Connection = $Connection
    } else {
        $invokeParams.Database = $script:DatabasePath
    }

    if ($Parameters) {
        $invokeParams.Parameters = $Parameters
    }

    if ($AsNonQuery) {
        $invokeParams.AsNonQuery = $true
    }

    Invoke-PSUSQLiteQuery @invokeParams
}
