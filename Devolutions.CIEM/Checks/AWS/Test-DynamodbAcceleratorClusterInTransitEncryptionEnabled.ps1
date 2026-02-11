function Test-DynamodbAcceleratorClusterInTransitEncryptionEnabled {
    <#
    .SYNOPSIS
        DynamoDB Accelerator (DAX) cluster has encryption in transit enabled

    .DESCRIPTION
        **DAX clusters** have endpoint encryption set to `TLS`, enforcing **encryption in transit** for client connections to the cluster

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

    # TODO: Implement check logic based on Prowler check: dynamodb_accelerator_cluster_in_transit_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check dynamodb_accelerator_cluster_in_transit_encryption_enabled for reference.', 'N/A', 'dynamodb Resources')
}
