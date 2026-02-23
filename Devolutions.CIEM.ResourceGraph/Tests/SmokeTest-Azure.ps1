#Requires -Version 7.4
<#
.SYNOPSIS
    Smoke test: builds a full VM dependency graph from live Azure resources.
.DESCRIPTION
    Queries Azure Resource Graph for all resource types in the VM dependency tree
    (VMs, NICs, disks, NSGs, public IPs, VNets, subnets, route tables, load balancers,
    availability sets, managed identities) and feeds them into New-ResourceDependencyGraph.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup
)

$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../Devolutions.CIEM.ResourceGraph.psd1" -Force

# Resource types in the VM dependency tree
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

# Build query
$rgFilter = if ($ResourceGroup) { "and resourceGroup =~ '$ResourceGroup'" } else { '' }
$query = @"
Resources
| where type in~ ($typeFilter) $rgFilter
| project id, name, type, location, properties, identity, managedBy
"@

Write-Host "Querying Azure Resource Graph..."
Write-Host "  Types: $($types.Count)"
if ($ResourceGroup) { Write-Host "  Resource Group: $ResourceGroup" }

$rgJson = az graph query -q $query --first 200 -o json 2>$null
$rgResult = $rgJson | ConvertFrom-Json
Write-Host "  Found $($rgResult.count) resources"

# Also fetch VNets to extract subnets (subnets are sub-resources)
$vnetQuery = @"
Resources
| where type =~ 'microsoft.network/virtualnetworks' $rgFilter
| project id, name, type, location, properties
"@
Write-Host "Querying VNets for subnet extraction..."
$vnetJson = az graph query -q $vnetQuery --first 50 -o json 2>$null
$vnetResult = $vnetJson | ConvertFrom-Json
Write-Host "  Found $($vnetResult.count) VNets"

# Extract subnets from VNets as standalone ARM objects
$subnets = @()
foreach ($vnet in $vnetResult.data) {
    foreach ($subnetData in $vnet.properties.subnets) {
        $subnets += [PSCustomObject]@{
            id         = $subnetData.id
            name       = $subnetData.name
            type       = 'Microsoft.Network/virtualNetworks/subnets'
            location   = $vnet.location
            properties = $subnetData.properties
        }
    }
}
Write-Host "  Extracted $($subnets.Count) subnets"

# Combine all resources
$resources = @($rgResult.data) + @($vnetResult.data) + $subnets
Write-Host "`n=== Input Resources ($($resources.Count) total) ==="
$resources | Group-Object -Property type | Sort-Object Count -Descending | ForEach-Object {
    Write-Host ("  {0,-55} {1}" -f $_.Name, $_.Count)
}

Write-Host "`n=== Building Graph ==="
$graph = New-ResourceDependencyGraph -Resources $resources -Verbose

Write-Host "`n=== Results ==="
Write-Host "Nodes: $($graph.Nodes.Count)"
Write-Host "Edges: $($graph.Edges.Count)"

if ($graph.Edges.Count -gt 0) {
    Write-Host "`n=== Edges by Cardinality ==="
    $graph.Edges | Group-Object -Property Cardinality | Sort-Object Count -Descending | ForEach-Object {
        Write-Host ("  {0,-20} {1}" -f $_.Name, $_.Count)
    }

    Write-Host "`n=== All Edges ==="
    $graph.Edges | ForEach-Object {
        $srcNode = $graph.Nodes[$_.SourceId]
        $tgtNode = $graph.Nodes[$_.TargetId]
        $srcLabel = if ($srcNode) { $srcNode.Name } else { '???' }
        $tgtLabel = if ($tgtNode) { $tgtNode.Name } else { '???' }
        $cardLabel = if ($_.Cardinality -eq 'OneToMany') { '1:N' } else { '1:1' }
        Write-Host ("  {0,-20} -[{1,-5}]-> {2,-20} (via {3})" -f $srcLabel, $cardLabel, $tgtLabel, $_.DiscoveredVia)
    }
}

Write-Host "`n=== JSON Output ==="
$graph.ToPSCustomObject() | ConvertTo-Json -Depth 10
