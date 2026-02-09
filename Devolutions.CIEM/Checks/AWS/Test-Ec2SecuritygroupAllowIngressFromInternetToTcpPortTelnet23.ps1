function Test-Ec2SecuritygroupAllowIngressFromInternetToTcpPortTelnet23 {
    <#
    .SYNOPSIS
        Security group does not allow ingress from the Internet to TCP port 23 (Telnet)

    .DESCRIPTION
        **EC2 security groups** are evaluated for rules that allow **inbound Telnet** on `TCP 23` from the Internet (`0.0.0.0/0` or `::/0`).

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

    # TODO: Implement check logic based on Prowler check: ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_telnet_23

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_telnet_23 for reference.', 'N/A', 'ec2 Resources')
}
