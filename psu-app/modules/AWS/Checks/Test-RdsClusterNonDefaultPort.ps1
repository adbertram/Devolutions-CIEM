function Test-RdsClusterNonDefaultPort {
    <#
    .SYNOPSIS
        RDS cluster uses a non-default port for its database engine

    .DESCRIPTION
        **RDS DB clusters** are assessed for use of a **non-default database port**.
        
        Evaluation focuses on whether the cluster listens on the engine's well-known default port (e.g., `3306`, `5432`, `1433`, `1521`, `50000`) or on a custom port.

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

    # TODO: Implement check logic based on Prowler check: rds_cluster_non_default_port

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check rds_cluster_non_default_port for reference.', 'N/A', 'rds Resources')
}
