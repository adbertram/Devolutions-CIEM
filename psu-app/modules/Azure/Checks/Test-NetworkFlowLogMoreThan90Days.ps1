function Test-NetworkFlowLogMoreThan90Days {
    <#
    .SYNOPSIS
        Network Watcher has all flow logs enabled with retention set to 0 or at least 90 days

    .DESCRIPTION
        **Azure Network Watcher** has **NSG flow logs** enabled and configured to retain for at least `90` days (or `0` for unlimited). The evaluation checks that flow logging is enabled and that the retention policy meets the required duration for each configured log.

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

    # TODO: Implement check logic based on Prowler check: network_flow_log_more_than_90_days

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check network_flow_log_more_than_90_days for reference.', 'N/A', 'network Resources')
}
