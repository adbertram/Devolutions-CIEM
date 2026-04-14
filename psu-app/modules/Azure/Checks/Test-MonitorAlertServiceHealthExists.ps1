function Test-MonitorAlertServiceHealthExists {
    <#
    .SYNOPSIS
        Azure subscription has an enabled Activity Log alert for Service Health incidents

    .DESCRIPTION
        **Azure Monitor Activity Log alert** is configured for **Service Health** notifications where `category` is `ServiceHealth` and `properties.incidentType` is `Incident`, with the rule enabled.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: monitor_alert_service_health_exists

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check monitor_alert_service_health_exists for reference.', 'N/A', 'monitor Resources')
}
