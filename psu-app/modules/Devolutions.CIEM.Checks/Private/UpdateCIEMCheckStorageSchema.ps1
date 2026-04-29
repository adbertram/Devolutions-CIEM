function UpdateCIEMCheckStorageSchema {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $columns = @(
        Invoke-CIEMQuery -Query 'PRAGMA table_info(checks)'
    )

    if ($columns.Count -eq 0) {
        throw "Checks table does not exist."
    }

    $columnNames = @($columns | ForEach-Object { $_.name })
    if (@(Compare-Object -ReferenceObject @('id', 'disabled') -DifferenceObject $columnNames).Count -eq 0) {
        return
    }

    $databasePath = Get-CIEMDatabasePath
    $connection = Open-PSUSQLiteConnection -Database $databasePath
    try {
        Invoke-PSUSQLiteQuery -Connection $connection -Query 'PRAGMA foreign_keys=OFF' -AsNonQuery | Out-Null
        Invoke-PSUSQLiteQuery -Connection $connection -Query @"
CREATE TABLE IF NOT EXISTS checks_state_migration (
    id TEXT PRIMARY KEY,
    disabled INTEGER NOT NULL DEFAULT 0
)
"@ -AsNonQuery | Out-Null
        Invoke-PSUSQLiteQuery -Connection $connection -Query @"
INSERT INTO checks_state_migration (id, disabled)
SELECT id, disabled FROM checks
"@ -AsNonQuery | Out-Null
        Invoke-PSUSQLiteQuery -Connection $connection -Query 'DROP TABLE checks' -AsNonQuery | Out-Null
        Invoke-PSUSQLiteQuery -Connection $connection -Query 'ALTER TABLE checks_state_migration RENAME TO checks' -AsNonQuery | Out-Null
        Invoke-PSUSQLiteQuery -Connection $connection -Query 'PRAGMA foreign_keys=ON' -AsNonQuery | Out-Null
    }
    finally {
        $connection.Dispose()
    }
}
