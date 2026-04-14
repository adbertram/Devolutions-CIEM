function Test-DefenderEnsureDefenderForServerIsOn {
    <#
    .SYNOPSIS
        Defender for Servers is set to On (Standard pricing tier)

    .DESCRIPTION
        **Microsoft Defender for Servers** subscription plan (`VirtualMachines`) is configured to the `Standard` tier. The evaluation checks whether the Servers plan is enabled at this level for all server workloads in the subscription.

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

    # TODO: Implement check logic based on Prowler check: defender_ensure_defender_for_server_is_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check defender_ensure_defender_for_server_is_on for reference.', 'N/A', 'defender Resources')
}
