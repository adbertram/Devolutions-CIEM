function Test-DefenderEnsureDefenderForDnsIsOn {
    <#
    .SYNOPSIS
        Defender for DNS is set to On (Standard pricing tier)

    .DESCRIPTION
        **Microsoft Defender for DNS** is configured at the `Standard` tier for the subscription's Defender pricing

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

    # TODO: Implement check logic based on Prowler check: defender_ensure_defender_for_dns_is_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check defender_ensure_defender_for_dns_is_on for reference.', 'N/A', 'defender Resources')
}
