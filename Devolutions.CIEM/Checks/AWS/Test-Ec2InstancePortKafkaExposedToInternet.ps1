function Test-Ec2InstancePortKafkaExposedToInternet {
    <#
    .SYNOPSIS
        EC2 instance does not allow ingress from the Internet to TCP port 9092 (Kafka)

    .DESCRIPTION
        **EC2 instances** with security group rules that allow inbound `TCP 9092` (Kafka) from the Internet are reported. The evaluation inspects ingress rules to detect broad sources (for example `0.0.0.0/0` or `::/0`) that expose Kafka brokers.

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

    # TODO: Implement check logic based on Prowler check: ec2_instance_port_kafka_exposed_to_internet

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check ec2_instance_port_kafka_exposed_to_internet for reference.', 'N/A', 'ec2 Resources')
}
