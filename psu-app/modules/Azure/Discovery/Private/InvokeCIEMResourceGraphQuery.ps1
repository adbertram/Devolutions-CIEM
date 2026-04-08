function InvokeCIEMResourceGraphQuery {
    [CmdletBinding(DefaultParameterSetName = 'BySubscription')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Resources', 'ResourceContainers', 'AuthorizationResources')]
        [string]$Query,

        [Parameter(Mandatory, ParameterSetName = 'BySubscription')]
        [AllowEmptyCollection()]
        [string[]]$SubscriptionId,

        [Parameter(Mandatory, ParameterSetName = 'ByManagementGroup')]
        [string]$ManagementGroupId
    )

    $ErrorActionPreference = 'Stop'

    if ($PSCmdlet.ParameterSetName -eq 'BySubscription' -and @($SubscriptionId).Count -eq 0) {
        throw 'InvokeCIEMResourceGraphQuery requires at least one subscription ID.'
    }

    $now = (Get-Date).ToString('o')
    $armApi = Get-CIEMAzureProviderApi -Name 'ARM'
    $uri = "$(($armApi.BaseUrl).TrimEnd('/'))/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01"

    if ($PSCmdlet.ParameterSetName -eq 'BySubscription') {
        for ($offset = 0; $offset -lt $SubscriptionId.Count; $offset += 1000) {
            $remaining = $SubscriptionId.Count - $offset
            $chunkSize = [Math]::Min(1000, $remaining)
            $scopeChunk = @($SubscriptionId[$offset..($offset + $chunkSize - 1)])

            $body = @{
                query = "$Query | project id, type, name, location, resourceGroup, subscriptionId, tenantId, kind, sku, identity, managedBy, plan, zones, tags, properties"
                options = @{ '$top' = 1000 }
                subscriptions = $scopeChunk
            }

            $results = @(Invoke-AzureApi -Api ARM -Uri $uri -Method POST -Body $body -ResourceName "ResourceGraph/$Query")
            foreach ($item in $results) {
                $resource = [CIEMAzureArmResource]::new()
                $resource.Id = $item.id
                $resource.Type = $item.type
                $resource.Name = $item.name
                $resource.Location = $item.location
                $resource.ResourceGroup = $item.resourceGroup
                $resource.SubscriptionId = $item.subscriptionId
                $resource.TenantId = $item.tenantId
                $resource.Kind = $item.kind
                $resource.Sku = if ($item.sku) { $item.sku | ConvertTo-Json -Depth 5 -Compress } else { $null }
                $resource.Identity = if ($item.identity) { $item.identity | ConvertTo-Json -Depth 5 -Compress } else { $null }
                $resource.ManagedBy = $item.managedBy
                $resource.Plan = if ($item.plan) { $item.plan | ConvertTo-Json -Depth 5 -Compress } else { $null }
                $resource.Zones = if ($item.zones) { $item.zones | ConvertTo-Json -Depth 5 -Compress } else { $null }
                $resource.Tags = if ($item.tags) { $item.tags | ConvertTo-Json -Depth 5 -Compress } else { $null }
                $resource.Properties = if ($item.properties) { $item.properties | ConvertTo-Json -Depth 10 -Compress } else { $null }
                $resource.CollectedAt = $now
                $resource
            }
        }
        return
    }

    $body = @{
        query = "$Query | project id, type, name, location, resourceGroup, subscriptionId, tenantId, kind, sku, identity, managedBy, plan, zones, tags, properties"
        options = @{ '$top' = 1000 }
        managementGroups = @($ManagementGroupId)
    }

    $results = @(Invoke-AzureApi -Api ARM -Uri $uri -Method POST -Body $body -ResourceName "ResourceGraph/$Query")
    foreach ($item in $results) {
        $resource = [CIEMAzureArmResource]::new()
        $resource.Id = $item.id
        $resource.Type = $item.type
        $resource.Name = $item.name
        $resource.Location = $item.location
        $resource.ResourceGroup = $item.resourceGroup
        $resource.SubscriptionId = $item.subscriptionId
        $resource.TenantId = $item.tenantId
        $resource.Kind = $item.kind
        $resource.Sku = if ($item.sku) { $item.sku | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Identity = if ($item.identity) { $item.identity | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.ManagedBy = $item.managedBy
        $resource.Plan = if ($item.plan) { $item.plan | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Zones = if ($item.zones) { $item.zones | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Tags = if ($item.tags) { $item.tags | ConvertTo-Json -Depth 5 -Compress } else { $null }
        $resource.Properties = if ($item.properties) { $item.properties | ConvertTo-Json -Depth 10 -Compress } else { $null }
        $resource.CollectedAt = $now
        $resource
    }
}
