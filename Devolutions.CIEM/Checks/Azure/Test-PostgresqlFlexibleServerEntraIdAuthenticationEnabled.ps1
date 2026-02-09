function Test-PostgresqlFlexibleServerEntraIdAuthenticationEnabled {
    <#
    .SYNOPSIS
        Microsoft Entra ID authentication is enabled for PostgreSQL Flexible Server

    .DESCRIPTION
        **PostgreSQL Flexible Servers** must set `authConfig.activeDirectoryAuth` to `Enabled` and keep at least one **Microsoft Entra administrator** assigned so database sessions inherit centrally governed identities instead of unmanaged PostgreSQL accounts.

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

    # TODO: Implement check logic based on Prowler check: postgresql_flexible_server_entra_id_authentication_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check postgresql_flexible_server_entra_id_authentication_enabled for reference.', 'N/A', 'postgresql Resources')
}
