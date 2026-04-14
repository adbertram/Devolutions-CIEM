function Test-RedshiftClusterInTransitEncryptionEnabled {
    <#
    .SYNOPSIS
        Redshift cluster is encrypted in transit

    .DESCRIPTION
        **Amazon Redshift clusters** enforce **encryption in transit** by requiring **TLS** for client connections when `require_ssl` is enabled.
        
        This evaluation identifies clusters where connections are not forced to use TLS.

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

    # TODO: Implement check logic based on Prowler check: redshift_cluster_in_transit_encryption_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check redshift_cluster_in_transit_encryption_enabled for reference.', 'N/A', 'redshift Resources')
}
