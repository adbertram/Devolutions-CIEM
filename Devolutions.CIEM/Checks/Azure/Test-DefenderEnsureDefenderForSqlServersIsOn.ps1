function Test-DefenderEnsureDefenderForSqlServersIsOn {
    <#
    .SYNOPSIS
        Defender for SQL servers on machines is set to On (Standard pricing tier)

    .DESCRIPTION
        **Subscription pricing** for **Defender for SQL Server on Machines** is configured to the `Standard` plan, covering SQL Server instances running on virtual machines.

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

    # TODO: Implement check logic based on Prowler check: defender_ensure_defender_for_sql_servers_is_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check defender_ensure_defender_for_sql_servers_is_on for reference.', 'N/A', 'defender Resources')
}
