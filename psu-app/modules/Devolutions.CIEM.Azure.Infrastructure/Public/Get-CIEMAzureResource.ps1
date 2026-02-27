function Get-CIEMAzureResource {
    [CmdletBinding()]
    [OutputType([CIEMAzureResource[]])]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$Type,
        [Parameter()][string]$ParentId,
        [Parameter()][string]$Name,
        [Parameter()][string]$Location
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('Type')) { $conditions += "type = @type"; $params.type = $Type }
    if ($PSBoundParameters.ContainsKey('ParentId')) { $conditions += "parent_id = @parent_id"; $params.parent_id = $ParentId }
    if ($PSBoundParameters.ContainsKey('Name')) { $conditions += "name = @name"; $params.name = $Name }
    if ($PSBoundParameters.ContainsKey('Location')) { $conditions += "location = @location"; $params.location = $Location }
    $query = "SELECT * FROM azure_resources"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureResource]::new()
        $obj.Id = $row.id; $obj.ProviderId = $row.provider_id; $obj.Type = $row.type
        $obj.ParentId = $row.parent_id; $obj.Name = $row.name; $obj.Location = $row.location
        $obj.Tags = $row.tags
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
