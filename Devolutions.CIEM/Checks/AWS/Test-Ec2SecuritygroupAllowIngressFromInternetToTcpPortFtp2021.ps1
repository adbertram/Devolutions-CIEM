function Test-Ec2SecuritygroupAllowIngressFromInternetToTcpPortFtp2021 {
    <#
    .SYNOPSIS
        Security group does not allow ingress from 0.0.0.0/0 or ::/0 to FTP ports 20 or 21

    .DESCRIPTION
        EC2 security groups are evaluated for Internet-exposed **FTP**: any inbound rule allowing `tcp` ports `20` or `21` from `0.0.0.0/0` or `::/0`.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_ftp_20_21

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_ftp_20_21 for reference.', 'N/A', 'ec2 Resources')
}
