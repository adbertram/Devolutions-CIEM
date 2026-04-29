function Get-CIEMCheckMetadata {
    <#
    .SYNOPSIS
        Returns check metadata records from provider catalogs.

    .DESCRIPTION
        Static metadata is catalog-owned. This command is kept as a compatibility
        wrapper around Get-CIEMCheck and no longer reads metadata from SQLite.

    .PARAMETER Id
        Filter to a specific check by ID.

    .PARAMETER Provider
        Filter by cloud provider (Azure, AWS).

    .EXAMPLE
        Get-CIEMCheckMetadata -Id 'entra_security_defaults_enabled'

    .EXAMPLE
        Get-CIEMCheckMetadata -Provider Azure
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$Provider
    )

    $ErrorActionPreference = 'Stop'

    $params = @{}
    if ($Id) { $params.CheckId = $Id }
    if ($Provider) { $params.Provider = $Provider }

    Get-CIEMCheck @params
}
