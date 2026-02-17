function Test-RedshiftClusterNonDefaultDatabaseName {
    <#
    .SYNOPSIS
        Redshift cluster does not use the default database name dev

    .DESCRIPTION
        **Amazon Redshift clusters** are identified when the database name equals the default `dev`, rather than a custom name.

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

    # TODO: Implement check logic based on Prowler check: redshift_cluster_non_default_database_name

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check redshift_cluster_non_default_database_name for reference.', 'N/A', 'redshift Resources')
}
