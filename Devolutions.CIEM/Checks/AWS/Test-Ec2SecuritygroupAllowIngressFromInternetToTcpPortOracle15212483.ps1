function Test-Ec2SecuritygroupAllowIngressFromInternetToTcpPortOracle15212483 {
    <#
    .SYNOPSIS
        Security group does not allow ingress from 0.0.0.0/0 or ::/0 to Oracle TCP ports 1521 or 2483

    .DESCRIPTION
        **EC2 security groups** are evaluated for inbound rules that permit public sources (`0.0.0.0/0` or `::/0`) to `TCP 1521` or `TCP 2483`-Oracle listener ports.
        
        The focus is on rules that make these ports reachable from the Internet over IPv4 or IPv6.

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

    # TODO: Implement check logic based on Prowler check: ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_oracle_1521_2483

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_oracle_1521_2483 for reference.', 'N/A', 'ec2 Resources')
}
