function Test-ElasticacheRedisClusterRestEncryptionEnabled {
    <#
    .SYNOPSIS
        ElastiCache Redis cache cluster has at rest encryption enabled

    .DESCRIPTION
        **ElastiCache for Redis replication groups** are evaluated for **encryption at rest** of on-disk cache data and backups. The finding pinpoints groups where this protection is not enabled.

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

    # TODO: Implement check logic based on Prowler check: elasticache_redis_cluster_rest_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check elasticache_redis_cluster_rest_encryption_enabled for reference.', 'N/A', 'elasticache Resources')
}
