function Test-PostgresqlFlexibleServerLogCheckpointsOn {
    <#
    .SYNOPSIS
        PostgreSQL Flexible Server has checkpoint logging enabled

    .DESCRIPTION
        **Azure PostgreSQL Flexible Server** has **checkpoint logging** enabled when `log_checkpoints=on`, recording each checkpoint in the server logs

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

    # TODO: Implement check logic based on Prowler check: postgresql_flexible_server_log_checkpoints_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check postgresql_flexible_server_log_checkpoints_on for reference.', 'N/A', 'postgresql Resources')
}
