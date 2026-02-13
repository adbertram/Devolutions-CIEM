function Test-MonitorAlertDeleteSqlserverFr {
    <#
    .SYNOPSIS
        Subscription has an Activity Log Alert for SQL Server firewall rule deletions

    .DESCRIPTION
        **Azure Monitor Activity log alerts** watch the admin operation `Microsoft.Sql/servers/firewallRules/delete`, indicating when an **Azure SQL firewall rule** is removed across a subscription.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: monitor_alert_delete_sqlserver_fr

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check monitor_alert_delete_sqlserver_fr for reference.', 'N/A', 'monitor Resources')
}
