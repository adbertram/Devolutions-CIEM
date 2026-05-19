function UpdateCIEMNotificationHistorySchema {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $columns = @{}
    foreach ($column in @(Invoke-CIEMQuery -Query "PRAGMA table_info('notification_history')")) {
        $columns[[string]$column.name] = [string]$column.type
    }
    if ($columns.Count -eq 0) {
        throw "Cannot migrate notification history storage because table 'notification_history' does not exist."
    }

    if (-not $columns.ContainsKey('invocation_source')) {
        Invoke-CIEMQuery -Query 'ALTER TABLE notification_history ADD COLUMN invocation_source TEXT' -AsNonQuery | Out-Null
    }
}
