function Test-PostgresqlFlexibleServerLogDisconnectionsOn {
    <#
    .SYNOPSIS
        PostgreSQL Flexible Server has disconnection logging enabled

    .DESCRIPTION
        **Azure Database for PostgreSQL Flexible Server** uses the `log_disconnections` setting to record when client sessions end and how long they lasted.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: postgresql_flexible_server_log_disconnections_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check postgresql_flexible_server_log_disconnections_on for reference.', 'N/A', 'postgresql Resources')
}
