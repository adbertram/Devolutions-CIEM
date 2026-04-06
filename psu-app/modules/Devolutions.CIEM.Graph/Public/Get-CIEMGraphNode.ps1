function Get-CIEMGraphNode {
    [CmdletBinding()]
    [OutputType('CIEMGraphNode[]')]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$Kind,

        [Parameter()]
        [string]$DisplayName,

        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$SubscriptionId
    )

    $ErrorActionPreference = 'Stop'

    $query = "SELECT id, kind, display_name, provider, subscription_id, resource_group, properties, collected_at FROM graph_nodes"
    $conditions = @()
    $parameters = @{}

    $columnMap = @{
        Id             = 'id'
        Kind           = 'kind'
        DisplayName    = 'display_name'
        Provider       = 'provider'
        SubscriptionId = 'subscription_id'
    }

    foreach ($paramName in $columnMap.Keys) {
        if ($PSBoundParameters.ContainsKey($paramName)) {
            $col = $columnMap[$paramName]
            $conditions += "$col = @$col"
            $parameters[$col] = $PSBoundParameters[$paramName]
        }
    }

    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        $obj = [CIEMGraphNode]::new()
        $obj.Id = $row.id
        $obj.Kind = $row.kind
        $obj.DisplayName = $row.display_name
        $obj.Provider = $row.provider
        $obj.SubscriptionId = $row.subscription_id
        $obj.ResourceGroup = $row.resource_group
        $obj.Properties = $row.properties
        $obj.CollectedAt = $row.collected_at
        $obj
    })
}
