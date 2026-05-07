function InvokeCIEMTransaction {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $ErrorActionPreference = 'Stop'

    $databasePath = Get-CIEMDatabasePath
    if (-not (Test-Path $databasePath)) {
        throw "CIEM database is not initialized at '$databasePath'. Module setup must create or migrate the database before transactions run."
    }

    $conn = Open-PSUSQLiteConnection -Database $databasePath
    Invoke-PSUSQLiteQuery -Connection $conn -Query "PRAGMA foreign_keys=ON" -AsNonQuery | Out-Null
    Invoke-PSUSQLiteQuery -Connection $conn -Query "BEGIN TRANSACTION" -AsNonQuery | Out-Null

    try {
        & $ScriptBlock $conn
        Invoke-PSUSQLiteQuery -Connection $conn -Query "COMMIT" -AsNonQuery | Out-Null
    }
    catch {
        Invoke-PSUSQLiteQuery -Connection $conn -Query "ROLLBACK" -AsNonQuery | Out-Null
        throw
    }
    finally {
        $conn.Dispose()
    }
}
