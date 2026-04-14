function Test-Ec2SecuritygroupAllowIngressFromInternetToTcpPortMongodb2701727018 {
    <#
    .SYNOPSIS
        Security group does not allow ingress from 0.0.0.0/0 or ::/0 to MongoDB TCP ports 27017 and 27018

    .DESCRIPTION
        **EC2 security groups** are inspected for inbound rules that expose **MongoDB** on `TCP 27017-27018` to the Internet via `0.0.0.0/0` or `::/0`.
        
        It identifies groups where these ports are reachable from any address.

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

    # TODO: Implement check logic based on Prowler check: ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_mongodb_27017_27018

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_mongodb_27017_27018 for reference.', 'N/A', 'ec2 Resources')
}
