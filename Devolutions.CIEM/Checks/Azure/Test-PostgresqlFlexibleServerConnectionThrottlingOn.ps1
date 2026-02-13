function Test-PostgresqlFlexibleServerConnectionThrottlingOn {
    <#
    .SYNOPSIS
        Flexible PostgreSQL server has connection_throttling enabled

    .DESCRIPTION
        **Azure PostgreSQL flexible servers** where the `connection_throttling` parameter is set to `ON`

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

    # TODO: Implement check logic based on Prowler check: postgresql_flexible_server_connection_throttling_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check postgresql_flexible_server_connection_throttling_on for reference.', 'N/A', 'postgresql Resources')
}
