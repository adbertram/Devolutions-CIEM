function Invoke-PSUSQLiteQuery {
    <#
    .SYNOPSIS
        Executes a SQL query against a SQLite database.
    .DESCRIPTION
        Runs a SQL statement and returns PSCustomObject rows for SELECT queries,
        or the number of affected rows for INSERT/UPDATE/DELETE/DDL statements.

        Supports parameterized queries to prevent SQL injection. Pass an existing
        connection from Open-PSUSQLiteConnection for transaction support.
    .PARAMETER Database
        Path to the SQLite database file. Created automatically if it does not exist.
    .PARAMETER Query
        The SQL statement to execute.
    .PARAMETER Parameters
        Hashtable of query parameters. Keys are mapped to @-prefixed parameter names.
    .PARAMETER AsNonQuery
        Execute as a non-query (INSERT/UPDATE/DELETE/DDL). Returns the number of affected rows.
    .PARAMETER Connection
        An existing open SqliteConnection from Open-PSUSQLiteConnection.
        When provided, the caller owns the connection lifecycle.
    .EXAMPLE
        Invoke-PSUSQLiteQuery -Database './data.db' -Query "SELECT * FROM users WHERE role = @role" -Parameters @{ role = 'admin' }
    .EXAMPLE
        Invoke-PSUSQLiteQuery -Database './data.db' -Query "CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT)" -AsNonQuery
    .EXAMPLE
        $conn = Open-PSUSQLiteConnection -Database './data.db'
        $tx = $conn.BeginTransaction()
        Invoke-PSUSQLiteQuery -Connection $conn -Query "INSERT INTO users VALUES (@id, @name)" -Parameters @{ id = '1'; name = 'Alice' } -AsNonQuery
        $tx.Commit()
        $conn.Dispose()
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByDatabase')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByDatabase')]
        [string]$Database,

        [Parameter(Mandatory)]
        [string]$Query,

        [hashtable]$Parameters,

        [switch]$AsNonQuery,

        [Parameter(Mandatory, ParameterSetName = 'ByConnection')]
        $Connection
    )

    $ErrorActionPreference = 'Stop'

    $ownsConnection = $false
    if ($PSCmdlet.ParameterSetName -eq 'ByDatabase') {
        $Connection = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$Database;Pooling=False")
        $Connection.Open()
        $ownsConnection = $true
    }

    try {
        $cmd = $Connection.CreateCommand()
        $cmd.CommandText = $Query

        if ($Parameters) {
            foreach ($key in $Parameters.Keys) {
                $paramName = if ($key.StartsWith('@')) { $key } else { "@$key" }
                $value = if ($null -eq $Parameters[$key]) { [DBNull]::Value } else { $Parameters[$key] }
                $cmd.Parameters.AddWithValue($paramName, $value) | Out-Null
            }
        }

        if ($AsNonQuery) {
            $cmd.ExecuteNonQuery()
        } else {
            $reader = $cmd.ExecuteReader()
            try {
                while ($reader.Read()) {
                    $row = [ordered]@{}
                    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
                        $name = $reader.GetName($i)
                        $row[$name] = if ($reader.IsDBNull($i)) { $null } else { $reader.GetValue($i) }
                    }
                    [PSCustomObject]$row
                }
            } finally {
                $reader.Close()
            }
        }
    } finally {
        if ($ownsConnection) {
            $Connection.Close()
            $Connection.Dispose()
        }
    }
}
