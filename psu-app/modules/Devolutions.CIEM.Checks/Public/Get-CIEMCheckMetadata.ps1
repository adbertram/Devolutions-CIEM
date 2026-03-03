function Get-CIEMCheckMetadata {
    <#
    .SYNOPSIS
        Returns check metadata records from the database.

    .DESCRIPTION
        Queries the checks table for metadata records. Returns raw PSCustomObjects
        with column values (no JSON parsing). Use Get-CIEMCheck for fully hydrated objects.

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

    $conditions = @()
    $params = @{}

    if ($Id) {
        $conditions += "id = @id"
        $params.id = $Id
    }

    if ($Provider) {
        $conditions += "provider = @provider"
        $params.provider = $Provider
    }

    $query = "SELECT * FROM checks"
    if ($conditions.Count -gt 0) {
        $query += " WHERE " + ($conditions -join ' AND ')
    }

    Invoke-CIEMQuery -Query $query -Parameters $params
}
