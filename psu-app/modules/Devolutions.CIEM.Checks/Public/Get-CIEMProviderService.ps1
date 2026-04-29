function Get-CIEMProviderService {
    <#
    .SYNOPSIS
        Lists unique services from provider check catalogs.

    .DESCRIPTION
        Reads provider check catalogs for unique service names per provider.
        Returns PSCustomObjects for compatibility with PSU runspaces.

    .PARAMETER Provider
        Filter services by cloud provider (Azure, AWS).

    .OUTPUTS
        [PSCustomObject[]] Array of objects with Name and Provider properties.

    .EXAMPLE
        Get-CIEMProviderService
        # Returns all services across all providers

    .EXAMPLE
        Get-CIEMProviderService -Provider Azure
        # Returns Azure services only
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider
    )

    $ErrorActionPreference = 'Stop'

    $services = @(
        Get-CIEMCheck -Provider $Provider |
            Select-Object -Property Service, Provider -Unique |
            Sort-Object -Property Provider, Service
    )

    foreach ($row in $services) {
        [PSCustomObject]@{
            Name     = $row.Service
            Provider = $row.Provider
        }
    }
}
