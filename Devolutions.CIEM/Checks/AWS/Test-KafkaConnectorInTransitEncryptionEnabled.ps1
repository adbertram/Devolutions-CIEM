function Test-KafkaConnectorInTransitEncryptionEnabled {
    <#
    .SYNOPSIS
        MSK Connect connector has encryption in transit enabled

    .DESCRIPTION
        **MSK Connect connectors** are evaluated for **in-transit encryption** using `TLS` on client connections to Kafka brokers and connected systems.

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

    # TODO: Implement check logic based on Prowler check: kafka_connector_in_transit_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check kafka_connector_in_transit_encryption_enabled for reference.', 'N/A', 'kafka Resources')
}
