function Test-VpcPeeringRoutingTablesWithLeastPrivilege {
    <#
    .SYNOPSIS
        VPC peering connection route tables do not include 0.0.0.0/0 or entire requester/accepter VPC CIDR routes

    .DESCRIPTION
        **AWS VPC peering** route tables are assessed for **least-privilege routing**. Routes that target `0.0.0.0/0` or an entire peer VPC CIDR are considered overly broad; only specific subnets or narrower prefixes should be advertised across the peering link.

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

    # TODO: Implement check logic based on Prowler check: vpc_peering_routing_tables_with_least_privilege

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check vpc_peering_routing_tables_with_least_privilege for reference.', 'N/A', 'vpc Resources')
}
