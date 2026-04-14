function Get-CIEMAzureEntraResource {
    [CmdletBinding()]
    [OutputType('CIEMAzureEntraResource[]')]
    param(
        [Parameter()]
        [string]$Id,
        [Parameter()]
        [string]$Type,
        [Parameter()]
        [string]$DisplayName,
        [Parameter()]
        [string]$ParentId
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $parameters = @{}
    $columnMap = @{
        Id          = 'id'
        Type        = 'type'
        DisplayName = 'display_name'
        ParentId    = 'parent_id'
    }

    foreach ($paramName in $columnMap.Keys) {
        if ($PSBoundParameters.ContainsKey($paramName)) {
            $col = $columnMap[$paramName]
            $conditions += "$col = @$col"
            $parameters[$col] = $PSBoundParameters[$paramName]
        }
    }

    $query = "SELECT * FROM azure_entra_resources"
    if ($conditions.Count -gt 0) {
        $query += " WHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        $obj = [CIEMAzureEntraResource]::new()
        $obj.Id = $row.id
        $obj.Type = $row.type
        $obj.DisplayName = $row.display_name
        $obj.ParentId = $row.parent_id
        $obj.Properties = $row.properties
        $obj.CollectedAt = $row.collected_at
        $obj.LastSeenAt = $row.last_seen_at
        $obj
    })
}
