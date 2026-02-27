function Test-KafkaClusterInTransitEncryptionEnabled {
    <#
    .SYNOPSIS
        Kafka cluster has encryption in transit enabled

    .DESCRIPTION
        **Amazon MSK clusters** are evaluated for **encryption in transit** on both paths: **clientbroker** set to `TLS` only and **inter-broker** encryption enabled. *Serverless clusters provide this by default*.
        
        The finding highlights clusters where client-broker traffic isn't `TLS`-only or inter-broker encryption is turned off.

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

    # TODO: Implement check logic based on Prowler check: kafka_cluster_in_transit_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check kafka_cluster_in_transit_encryption_enabled for reference.', 'N/A', 'kafka Resources')
}
