function Test-RedshiftClusterEncryptedAtRest {
    <#
    .SYNOPSIS
        Redshift cluster is encrypted at rest

    .DESCRIPTION
        **Amazon Redshift clusters** use **encryption at rest**. The evaluation inspects the cluster's encryption setting to determine if on-disk data and snapshots are protected with a managed key.

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

    # TODO: Implement check logic based on Prowler check: redshift_cluster_encrypted_at_rest

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check redshift_cluster_encrypted_at_rest for reference.', 'N/A', 'redshift Resources')
}
