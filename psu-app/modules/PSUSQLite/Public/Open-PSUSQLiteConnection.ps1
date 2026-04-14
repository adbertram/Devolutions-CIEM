function Open-PSUSQLiteConnection {
    <#
    .SYNOPSIS
        Opens a SQLite database connection for transaction or bulk operations.
    .DESCRIPTION
        Returns an open Microsoft.Data.Sqlite.SqliteConnection. The caller owns the
        connection and must call .Dispose() when finished.

        Use this when you need transaction support or multiple queries against
        the same connection (avoiding per-query open/close overhead).
    .PARAMETER Database
        Path to the SQLite database file. Created automatically if it does not exist.
    .EXAMPLE
        $conn = Open-PSUSQLiteConnection -Database './data.db'
        $tx = $conn.BeginTransaction()
        try {
            Invoke-PSUSQLiteQuery -Connection $conn -Query "INSERT INTO t VALUES (@v)" -Parameters @{ v = 1 } -AsNonQuery
            Invoke-PSUSQLiteQuery -Connection $conn -Query "INSERT INTO t VALUES (@v)" -Parameters @{ v = 2 } -AsNonQuery
            $tx.Commit()
        } catch {
            $tx.Rollback()
            throw
        } finally {
            $conn.Dispose()
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Database
    )

    $ErrorActionPreference = 'Stop'

    $conn = [Microsoft.Data.Sqlite.SqliteConnection]::new("Data Source=$Database;Pooling=False")
    $conn.Open()
    $conn
}
