function Get-CIEMProviderService {
    <#
    .SYNOPSIS
        Lists unique services from the CIEM checks database.

    .DESCRIPTION
        Queries the checks table for unique service names per provider.
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

    if ($Provider) {
        $rows = Invoke-CIEMQuery -Query "SELECT DISTINCT service, provider FROM checks WHERE provider = @provider ORDER BY provider, service" -Parameters @{ provider = $Provider }
    } else {
        $rows = Invoke-CIEMQuery -Query "SELECT DISTINCT service, provider FROM checks ORDER BY provider, service"
    }

    foreach ($row in $rows) {
        [PSCustomObject]@{
            Name     = $row.service
            Provider = $row.provider
        }
    }
}
