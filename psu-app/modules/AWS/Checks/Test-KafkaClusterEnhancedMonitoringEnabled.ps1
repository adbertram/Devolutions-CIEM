function Test-KafkaClusterEnhancedMonitoringEnabled {
    <#
    .SYNOPSIS
        Amazon MSK cluster has enhanced monitoring enabled

    .DESCRIPTION
        **Amazon MSK clusters** are assessed for **enhanced monitoring** levels beyond `DEFAULT` (e.g., `PER_BROKER`, `PER_TOPIC_PER_BROKER`, `PER_TOPIC_PER_PARTITION`).
        
        *Serverless clusters* include enhanced monitoring by design; provisioned clusters are evaluated by their configured monitoring level.

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

    # TODO: Implement check logic based on Prowler check: kafka_cluster_enhanced_monitoring_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check kafka_cluster_enhanced_monitoring_enabled for reference.', 'N/A', 'kafka Resources')
}
