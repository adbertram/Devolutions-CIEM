function InvokeCIEMTransaction {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    if (-not $script:DatabasePath) {
        $script:DatabasePath = New-CIEMDatabase -PassThru
    }

    $conn = Open-PSUSQLiteConnection -Database $script:DatabasePath
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
