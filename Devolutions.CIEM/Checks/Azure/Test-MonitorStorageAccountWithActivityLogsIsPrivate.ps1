function Test-MonitorStorageAccountWithActivityLogsIsPrivate {
    <#
    .SYNOPSIS
        Storage account storing activity logs does not allow public blob access

    .DESCRIPTION
        **Azure Monitor Activity Logs** sent to a **Storage account** are evaluated for **Blob public access**. The finding identifies whether the account that stores the logs has `AllowBlobPublicAccess` turned on.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: monitor_storage_account_with_activity_logs_is_private

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check monitor_storage_account_with_activity_logs_is_private for reference.', 'N/A', 'monitor Resources')
}
