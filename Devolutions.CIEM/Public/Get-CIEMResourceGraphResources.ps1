function Get-CIEMResourceGraphResources {
    <#
    .SYNOPSIS
        Queries Azure Resource Graph for ARM resources and returns deduplicated results including extracted subnets.
    .DESCRIPTION
        Queries Azure Resource Graph via REST API for the supported resource types used by the
        resource dependency graph. Also fetches VNets separately to extract subnet sub-resources.
        Returns a deduplicated array of ARM resource objects ready for New-ResourceDependencyGraph.
    .PARAMETER SubscriptionIds
        Array of Azure subscription IDs to query.
    .PARAMETER ResourceGroup
        Optional resource group name to filter results.
    .EXAMPLE
        $resources = Get-CIEMResourceGraphResources -SubscriptionIds @('sub-id-1')
        $graph = New-ResourceDependencyGraph -Resources $resources
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$SubscriptionIds,

        [Parameter()]
        [ValidatePattern('^[a-zA-Z0-9._-]+$')]
        [string]$ResourceGroup
    )

    $ErrorActionPreference = 'Stop'

    $types = @(
        'microsoft.compute/virtualmachines'
        'microsoft.compute/disks'
        'microsoft.compute/availabilitysets'
        'microsoft.compute/proximityplacementgroups'
        'microsoft.compute/hostgroups'
        'microsoft.compute/virtualmachinescalesets'
        'microsoft.compute/diskencryptionsets'
        'microsoft.network/networkinterfaces'
        'microsoft.network/publicipaddresses'
        'microsoft.network/networksecuritygroups'
        'microsoft.network/routetables'
        'microsoft.network/natgateways'
        'microsoft.network/loadbalancers'
        'microsoft.network/ddosprotectionplans'
    )
    $typeFilter = ($types | ForEach-Object { "'$_'" }) -join ','

    $rgFilter = if ($ResourceGroup) { "and resourceGroup =~ '$ResourceGroup'" } else { '' }
    $query = "Resources | where type in~ ($typeFilter) $rgFilter | project id, name, type, location, properties, identity, managedBy"

    Write-CIEMLog -Message "Resource Graph query: types=$($types.Count), resourceGroup=$ResourceGroup, subscriptions=$($SubscriptionIds.Count)" -Severity INFO -Component 'Get-CIEMResourceGraphResources'

    # Query Azure Resource Graph via REST API (with pagination)
    $rgUri = 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
    $resources = [System.Collections.Generic.List[object]]::new()
    $rgBody = @{
        query         = $query
        subscriptions = $SubscriptionIds
        options       = @{ '$top' = 500 }
    }
    do {
        $rgResult = Invoke-AzureApi -Uri $rgUri -Method POST -Body $rgBody -Api ARM -ResourceName 'Resource Graph Query' -ErrorAction Stop
        foreach ($item in @($rgResult.data)) { $resources.Add($item) }
        $skipToken = if ($rgResult.PSObject.Properties.Match('$skipToken').Count) { $rgResult.'$skipToken' } else { $null }
        if ($skipToken) { $rgBody.options.'$skipToken' = $skipToken }
    } while ($skipToken)

    Write-CIEMLog -Message "Resource Graph returned $($resources.Count) resources" -Severity INFO -Component 'Get-CIEMResourceGraphResources'

    # Fetch VNets to extract subnets (subnets are sub-resources, not returned as top-level resources)
    $vnetQuery = "Resources | where type =~ 'microsoft.network/virtualnetworks' $rgFilter | project id, name, type, location, properties"
    $vnets = [System.Collections.Generic.List[object]]::new()
    $vnetBody = @{
        query         = $vnetQuery
        subscriptions = $SubscriptionIds
        options       = @{ '$top' = 100 }
    }
    do {
        $vnetResult = Invoke-AzureApi -Uri $rgUri -Method POST -Body $vnetBody -Api ARM -ResourceName 'VNet Query' -ErrorAction Stop
        foreach ($item in @($vnetResult.data)) { $vnets.Add($item) }
        $skipToken = if ($vnetResult.PSObject.Properties.Match('$skipToken').Count) { $vnetResult.'$skipToken' } else { $null }
        if ($skipToken) { $vnetBody.options.'$skipToken' = $skipToken }
    } while ($skipToken)

    # Extract subnets as standalone ARM objects (subnets are nested inside VNet properties)
    $subnets = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($vnet in $vnets) {
        if ($vnet.properties.subnets) {
            foreach ($subnetData in $vnet.properties.subnets) {
                $subnets.Add([PSCustomObject]@{
                    id         = $subnetData.id
                    name       = $subnetData.name
                    type       = 'Microsoft.Network/virtualNetworks/subnets'
                    location   = $vnet.location
                    properties = $subnetData.properties
                })
            }
        }
    }

    # Combine and deduplicate by ID
    $allResources = @($resources) + @($vnets) + @($subnets)
    $seen = @{}
    $uniqueResources = @($allResources | Where-Object {
        if ($seen[$_.id]) { $false } else { $seen[$_.id] = $true; $true }
    })

    Write-CIEMLog -Message "Total unique resources: $($uniqueResources.Count) (includes $($subnets.Count) extracted subnets)" -Severity INFO -Component 'Get-CIEMResourceGraphResources'

    return $uniqueResources
}
