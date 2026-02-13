function Test-PostgresqlFlexibleServerEnforceSslEnabled {
    <#
    .SYNOPSIS
        PostgreSQL Flexible Server enforces SSL connections

    .DESCRIPTION
        **Azure Database for PostgreSQL flexible servers** are evaluated for **encrypted in-transit connections**, specifically whether `require_secure_transport` is set to `ON` to force TLS for all client sessions.

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

    # TODO: Implement check logic based on Prowler check: postgresql_flexible_server_enforce_ssl_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check postgresql_flexible_server_enforce_ssl_enabled for reference.', 'N/A', 'postgresql Resources')
}
