function Get-CIEMAzureResourceType {
    [CmdletBinding()]
    [OutputType('CIEMAzureResourceType[]')]
    param(
        [Parameter()]
        [string]$Type,

        [Parameter()]
        [string]$ApiSource
    )

    $ErrorActionPreference = 'Stop'

    $conditions = @()
    $parameters = @{}

    $columnMap = @{
        Type      = 'type'
        ApiSource = 'api_source'
    }

    foreach ($paramName in $columnMap.Keys) {
        if ($PSBoundParameters.ContainsKey($paramName)) {
            $col = $columnMap[$paramName]
            $conditions += "$col = @$col"
            $parameters[$col] = $PSBoundParameters[$paramName]
        }
    }

    $query = "SELECT type, api_source, graph_table, resource_count, discovered_at, last_collected FROM azure_resource_types"
    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        $obj = [CIEMAzureResourceType]::new()
        $obj.Type = $row.type
        $obj.ApiSource = $row.api_source
        $obj.GraphTable = $row.graph_table
        $obj.ResourceCount = $row.resource_count
        $obj.DiscoveredAt = $row.discovered_at
        $obj.LastCollected = $row.last_collected
        $obj
    })
}
