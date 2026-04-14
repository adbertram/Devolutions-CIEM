function Test-Ec2InstancePortFtpExposedToInternet {
    <#
    .SYNOPSIS
        EC2 instance does not allow ingress from the Internet to TCP ports 20 or 21 (FTP)

    .DESCRIPTION
        **EC2 instances** with security groups permitting inbound **FTP** on `TCP 20-21` from any address (e.g., `0.0.0.0/0` or `::/0`) are identified.
        
        Exposure is contextualized by the instance's public reachability (public IP and subnet).

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_port_ftp_exposed_to_internet

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_port_ftp_exposed_to_internet for reference.', 'N/A', 'ec2 Resources')
}
