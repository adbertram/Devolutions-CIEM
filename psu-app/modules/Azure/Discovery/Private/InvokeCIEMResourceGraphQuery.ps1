function InvokeCIEMResourceGraphQuery {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Resources', 'ResourceContainers', 'AuthorizationResources')]
        [string]$Query
    )

    $now = (Get-Date).ToString('o')

    $body = @{
        query   = "$Query | project id, type, name, location, resourceGroup, subscriptionId, tenantId, kind, sku, identity, managedBy, plan, zones, tags, properties"
        options = @{ '$top' = 1000 }
    }

    $armApi = Get-CIEMAzureProviderApi -Name 'ARM'
    $uri = "$(($armApi.BaseUrl).TrimEnd('/'))/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"

    $results = Invoke-AzureApi -Uri $uri -Method POST -Body $body -ResourceName "ResourceGraph/$Query"

    foreach ($item in $results) {
        $resource = [CIEMAzureArmResource]::new()
        $resource.Id             = $item.id
        $resource.Type           = $item.type
        $resource.Name           = $item.name
        $resource.Location       = $item.location
        $resource.ResourceGroup  = $item.resourceGroup
        $resource.SubscriptionId = $item.subscriptionId
        $resource.TenantId       = $item.tenantId
        $resource.Kind           = $item.kind
        $resource.Sku            = if ($item.sku)      { $item.sku      | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Identity       = if ($item.identity) { $item.identity | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.ManagedBy      = $item.managedBy
        $resource.Plan           = if ($item.plan)     { $item.plan     | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Zones          = if ($item.zones)    { $item.zones    | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Tags           = if ($item.tags)     { $item.tags     | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Properties     = if ($item.properties) { $item.properties | ConvertTo-Json -Depth 10 -Compress } else { $null }
        $resource.CollectedAt    = $now
        $resource
    }
}
