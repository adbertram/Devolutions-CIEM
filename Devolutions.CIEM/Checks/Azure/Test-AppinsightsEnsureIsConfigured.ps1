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
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Appinsights' }).CacheData

    foreach ($subscriptionId in $svc.Keys) {
        $components = $svc[$subscriptionId].Components

        if ($components -and $components.Count -gt 0) {
            $status = 'PASS'
            $statusExtended = "Subscription '$subscriptionId' has $($components.Count) Application Insights component(s) configured."
        }
        else {
            $status = 'FAIL'
            $statusExtended = "Subscription '$subscriptionId' has no Application Insights components configured. Application monitoring is not enabled."
        }

        [CIEMScanResult]::Create($Check, $status, $statusExtended, "/subscriptions/$subscriptionId", "Subscription $subscriptionId")
    }
}
