function Test-NetworkfirewallInAllVpc {
    <#
    .SYNOPSIS
        VPC has Network Firewall enabled

    .DESCRIPTION
        **VPCs** with an **AWS Network Firewall** associated to the same VPC to inspect and filter network traffic.
        
        Identifies VPCs that do not have a Network Firewall resource linked to them.

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

    # TODO: Implement check logic based on Prowler check: networkfirewall_in_all_vpc

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check networkfirewall_in_all_vpc for reference.', 'N/A', 'networkfirewall Resources')
}
