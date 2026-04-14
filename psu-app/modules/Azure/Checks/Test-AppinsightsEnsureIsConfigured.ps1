function Test-AppinsightsEnsureIsConfigured {
    <#
    .SYNOPSIS
        Subscription has at least one Application Insights resource configured

    .DESCRIPTION
        **Azure subscription** contains at least one **Application Insights** resource collecting application telemetry (metrics, traces, logs) for monitored workloads.
        
        The check determines whether telemetry collection exists at the subscription level, indicating that application monitoring is configured.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: appinsights_ensure_is_configured

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check appinsights_ensure_is_configured for reference.', 'N/A', 'appinsights Resources')
}
