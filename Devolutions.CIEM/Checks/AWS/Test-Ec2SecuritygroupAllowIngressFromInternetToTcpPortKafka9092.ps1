function Test-Ec2SecuritygroupAllowIngressFromInternetToTcpPortKafka9092 {
    <#
    .SYNOPSIS
        Security group does not allow ingress from 0.0.0.0/0 or ::/0 to TCP port 9092 (Kafka)

    .DESCRIPTION
        **EC2 security groups** are evaluated for ingress rules that expose **Kafka** on `TCP 9092` to the Internet via `0.0.0.0/0` or `::/0`

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

    # TODO: Implement check logic based on Prowler check: ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_kafka_9092

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_securitygroup_allow_ingress_from_internet_to_tcp_port_kafka_9092 for reference.', 'N/A', 'ec2 Resources')
}
