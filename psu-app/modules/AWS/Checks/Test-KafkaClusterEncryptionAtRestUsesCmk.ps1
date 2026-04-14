function Test-KafkaClusterEncryptionAtRestUsesCmk {
    <#
    .SYNOPSIS
        Kafka cluster has encryption at rest enabled with a customer managed key (CMK) or is serverless

    .DESCRIPTION
        Amazon MSK clusters are inspected for **encryption at rest** using a **customer-managed KMS key** for data volumes. Serverless clusters are inherently encrypted. Provisioned clusters are recognized only when the configured `DataVolumeKMSKeyId` corresponds to a customer-managed key.

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

    # TODO: Implement check logic based on Prowler check: kafka_cluster_encryption_at_rest_uses_cmk

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check kafka_cluster_encryption_at_rest_uses_cmk for reference.', 'N/A', 'kafka Resources')
}
