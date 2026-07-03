function InvokeCIEMImmediateTransaction {
    [CmdletBinding()]
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
    $transactionStarted = $false
    try {
        Invoke-PSUSQLiteQuery -Connection $conn -Query 'PRAGMA foreign_keys=ON' -AsNonQuery | Out-Null
        try {
            Invoke-PSUSQLiteQuery -Connection $conn -Query 'BEGIN IMMEDIATE' -AsNonQuery | Out-Null
            $transactionStarted = $true
        }
        catch {
            if ($_.Exception.Message -match 'database is locked|SQLITE_BUSY') {
                throw 'CIEM Azure mutation conflict: another CIEM database writer is already active.'
            }
            throw
        }

        & $ScriptBlock $conn
        Invoke-PSUSQLiteQuery -Connection $conn -Query 'COMMIT' -AsNonQuery | Out-Null
        $transactionStarted = $false
    }
    catch {
        if ($transactionStarted) {
            Invoke-PSUSQLiteQuery -Connection $conn -Query 'ROLLBACK' -AsNonQuery | Out-Null
        }
        throw
    }
    finally {
        $conn.Dispose()
    }
}
