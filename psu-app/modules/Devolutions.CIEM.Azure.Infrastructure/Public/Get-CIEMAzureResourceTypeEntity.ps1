function Get-CIEMAzureResourceTypeEntity {
    [CmdletBinding()]
    [OutputType([CIEMAzureResourceTypeEntity[]])]
    param(
        [Parameter()][string]$Id,
        [Parameter()][int]$ProviderApiId,
        [Parameter()][string]$DisplayName,
        [Parameter()][bool]$IsCollectible
    )

    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}

    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderApiId')) { $conditions += "provider_api_id = @provider_api_id"; $params.provider_api_id = $ProviderApiId }
    if ($PSBoundParameters.ContainsKey('DisplayName')) { $conditions += "display_name = @display_name"; $params.display_name = $DisplayName }
    if ($PSBoundParameters.ContainsKey('IsCollectible')) { $conditions += "is_collectible = @is_collectible"; $params.is_collectible = if ($IsCollectible) { 1 } else { 0 } }

    $query = "SELECT * FROM azure_resource_types"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureResourceTypeEntity]::new()
        $obj.Id = $row.id
        $obj.ProviderApiId = $row.provider_api_id
        $obj.DisplayName = $row.display_name
        $obj.IsCollectible = [bool]$row.is_collectible
        $obj
    })
}
