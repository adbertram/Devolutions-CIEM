function Test-RdsInstanceNonDefaultPort {
    <#
    .SYNOPSIS
        RDS instance uses a non-default port for its engine

    .DESCRIPTION
        **RDS DB instances** are evaluated for use of a port that differs from the engine's default. Matching an engine with its default port-`3306` (MySQL/MariaDB/Aurora MySQL), `5432` (PostgreSQL/Aurora), `1521` (Oracle), `1433` (SQL Server), `50000` (Db2)-indicates the instance uses the default listener.

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

    # TODO: Implement check logic based on Prowler check: rds_instance_non_default_port

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check rds_instance_non_default_port for reference.', 'N/A', 'rds Resources')
}
