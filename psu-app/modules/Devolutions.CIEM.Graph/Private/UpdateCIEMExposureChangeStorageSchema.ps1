function UpdateCIEMExposureChangeStorageSchema {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $columns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('ciem_exposure_changes')")) {
        $columns[[string]$column.name] = [string]$column.type
    }
    if ($columns.Count -eq 0) {
        throw "Cannot migrate exposure-change storage because table 'ciem_exposure_changes' does not exist."
    }

    if (-not $columns.ContainsKey('title')) {
        Invoke-CIEMQuery -Query "ALTER TABLE ciem_exposure_changes ADD COLUMN title TEXT NOT NULL DEFAULT ''" -AsNonQuery | Out-Null
    }
}
