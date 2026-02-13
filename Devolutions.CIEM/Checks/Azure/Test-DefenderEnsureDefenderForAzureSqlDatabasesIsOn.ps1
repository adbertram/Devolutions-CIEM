function Test-DefenderEnsureDefenderForAzureSqlDatabasesIsOn {
    <#
    .SYNOPSIS
        Defender for Azure SQL databases is set to On (Standard pricing tier)

    .DESCRIPTION
        Microsoft Defender for Cloud plan for **Azure SQL Database Servers** is evaluated at subscription scope, expecting the `pricing_tier` set to `Standard` for `SqlServers`. Non-standard tiers indicate the plan isn't enabled.

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

    # TODO: Implement check logic based on Prowler check: defender_ensure_defender_for_azure_sql_databases_is_on

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check defender_ensure_defender_for_azure_sql_databases_is_on for reference.', 'N/A', 'defender Resources')
}
