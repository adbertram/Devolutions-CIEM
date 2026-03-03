function Get-CIEMResourceType {
    <#
    .SYNOPSIS
        Lists resource types from the SQLite resource_types table.

    .DESCRIPTION
        Queries the resource_types table and returns typed objects per provider.
        Returns PSCustomObjects (not class instances) to ensure compatibility with
        PSU runspaces, matching the pattern used by Get-CIEMProviderService.

    .PARAMETER Provider
        Filter by cloud provider (Azure, AWS).

    .PARAMETER Name
        Filter by resource type name (e.g., "KeyVault", "S3Bucket").

    .OUTPUTS
        [PSCustomObject[]] Array of resource type objects.

    .EXAMPLE
        Get-CIEMResourceType
        # Returns all resource types across all providers

    .EXAMPLE
        Get-CIEMResourceType -Provider Azure
        # Returns Azure resource types only

    .EXAMPLE
        Get-CIEMResourceType -Provider Azure -Name KeyVault
        # Returns the KeyVault resource type
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $params = @{}

    if ($PSBoundParameters.ContainsKey('Provider')) {
        $conditions += "provider = @provider"
        $params.provider = $Provider
    }
    if ($PSBoundParameters.ContainsKey('Name')) {
        $conditions += "name = @name"
        $params.name = $Name
    }

    $query = "SELECT * FROM resource_types"
    if ($conditions.Count -gt 0) {
        $query += " WHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)

    @(foreach ($row in $rows) {
        [PSCustomObject]@{
            Name              = $row.name
            DisplayName       = $row.display_name
            Provider          = $row.provider
            ServiceName       = $row.service_name
            ArmProviderPrefix = $row.arm_provider_prefix
            ArnServicePrefix  = $row.arn_service_prefix
        }
    })
}
