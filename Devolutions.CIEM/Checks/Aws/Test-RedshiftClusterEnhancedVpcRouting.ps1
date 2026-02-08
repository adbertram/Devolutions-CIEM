function Test-RedshiftClusterEnhancedVpcRouting {
    <#
    .SYNOPSIS
        Redshift cluster has Enhanced VPC Routing enabled

    .DESCRIPTION
        **Amazon Redshift clusters** are assessed for the `EnhancedVpcRouting` setting, which routes all `COPY` and `UNLOAD` traffic between the cluster and data repositories through the VPC, enabling use of VPC security controls and logging.

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

    # TODO: Implement check logic based on Prowler check: redshift_cluster_enhanced_vpc_routing

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check redshift_cluster_enhanced_vpc_routing for reference.', 'N/A', 'redshift Resources')
}
