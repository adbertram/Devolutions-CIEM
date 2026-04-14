function Get-CIEMProviderAuthMethod {
    <#
    .SYNOPSIS
        Returns available authentication methods for a cloud provider.

    .PARAMETER Provider
        The provider name (e.g. 'Azure', 'AWS').

    .OUTPUTS
        [PSCustomObject[]] Objects with Method, DisplayName, SortOrder properties.

    .EXAMPLE
        Get-CIEMProviderAuthMethod -Provider Azure
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider
    )

    $ErrorActionPreference = 'Stop'

    $query = "SELECT method, display_name, sort_order FROM provider_auth_methods WHERE provider = @provider COLLATE NOCASE ORDER BY sort_order"
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters @{ provider = $Provider })

    foreach ($row in $rows) {
        [PSCustomObject]@{
            Method      = $row.method
            DisplayName = $row.display_name
            SortOrder   = $row.sort_order
        }
    }
}
