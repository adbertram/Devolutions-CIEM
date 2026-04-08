function Get-CIEMAzureArmResource {
    [CmdletBinding()]
    [OutputType('CIEMAzureArmResource[]')]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$Type,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string]$SubscriptionId,

        [Parameter()]
        [string]$ResourceGroup
    )

    $query = "SELECT id, type, name, location, resource_group, subscription_id, tenant_id, kind, sku, identity, managed_by, plan, zones, tags, properties, collected_at, last_seen_at FROM azure_arm_resources"
    $conditions = @()
    $parameters = @{}

    $columnMap = @{
        Id             = 'id'
        Type           = 'type'
        Name           = 'name'
        SubscriptionId = 'subscription_id'
        ResourceGroup  = 'resource_group'
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
        $obj = [CIEMAzureArmResource]::new()
        $obj.Id = $row.id
        $obj.Type = $row.type
        $obj.Name = $row.name
        $obj.Location = $row.location
        $obj.ResourceGroup = $row.resource_group
        $obj.SubscriptionId = $row.subscription_id
        $obj.TenantId = $row.tenant_id
        $obj.Kind = $row.kind
        $obj.Sku = $row.sku
        $obj.Identity = $row.identity
        $obj.ManagedBy = $row.managed_by
        $obj.Plan = $row.plan
        $obj.Zones = $row.zones
        $obj.Tags = $row.tags
        $obj.Properties = $row.properties
        $obj.CollectedAt = $row.collected_at
        $obj.LastSeenAt = $row.last_seen_at
        $obj
    })
}
