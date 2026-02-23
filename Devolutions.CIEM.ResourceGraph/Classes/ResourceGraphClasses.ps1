enum ResourceCardinality {
    OneToOne
    OneToMany
}

class DependencyPath {
    [string]$Path

    DependencyPath([string]$path) {
        $this.Path = $path
    }
}

class ResourceType {
    [string]$ArmType
    [string]$Category
    [string]$DisplayName
    [hashtable]$DependencyPaths = @{}

    ResourceType() {}

    static [ResourceType] FromSchemaEntry([string]$armType, [PSCustomObject]$jsonObject) {
        $rt = [ResourceType]::new()
        $rt.ArmType = $armType
        $rt.Category = $jsonObject.category
        $rt.DisplayName = $jsonObject.displayName

        foreach ($dep in $jsonObject.dependencyPaths.PSObject.Properties) {
            $rt.DependencyPaths[$dep.Name] = [DependencyPath]::new($dep.Value.path)
        }

        return $rt
    }

    [PSCustomObject] ToSchemaEntry() {
        $paths = [ordered]@{}
        foreach ($entry in $this.DependencyPaths.GetEnumerator()) {
            $paths[$entry.Key] = [ordered]@{
                path = $entry.Value.Path
            }
        }
        return [PSCustomObject][ordered]@{
            category        = $this.Category
            displayName     = $this.DisplayName
            dependencyPaths = [PSCustomObject]$paths
        }
    }
}

class ResourceGraphNode {
    [string]$Id
    [string]$Name
    [string]$Type
    [string]$ResourceGroup
    [string]$SubscriptionId
    [string]$Location
    [PSCustomObject]$RawResource

    ResourceGraphNode() {}

    static [ResourceGraphNode] FromArmResource([PSCustomObject]$resource) {
        $node = [ResourceGraphNode]::new()
        $node.Id = $resource.id
        $node.Name = $resource.name
        $node.Type = $resource.type
        $node.Location = $resource.location
        $node.RawResource = $resource

        # Parse ARM ID: /subscriptions/{sub}/resourceGroups/{rg}/...
        if ($resource.id -match '/subscriptions/([^/]+)/resourceGroups/([^/]+)') {
            $node.SubscriptionId = $Matches[1]
            $node.ResourceGroup = $Matches[2]
        }

        return $node
    }
}

class ResourceGraphEdge {
    [string]$SourceId
    [string]$TargetId
    [ResourceCardinality]$Cardinality
    [string]$DiscoveredVia

    ResourceGraphEdge([string]$sourceId, [string]$targetId, [ResourceCardinality]$cardinality, [string]$discoveredVia) {
        $this.SourceId = $sourceId
        $this.TargetId = $targetId
        $this.Cardinality = $cardinality
        $this.DiscoveredVia = $discoveredVia
    }
}

class ResourceDependencyGraph {
    [hashtable]$Nodes = @{}
    [System.Collections.Generic.List[ResourceGraphEdge]]$Edges = [System.Collections.Generic.List[ResourceGraphEdge]]::new()
    hidden [hashtable]$EdgesBySource = @{}

    [void] AddNode([ResourceGraphNode]$node) {
        $this.Nodes[$node.Id] = $node
    }

    [void] AddEdge([ResourceGraphEdge]$edge) {
        $this.Edges.Add($edge)
        if (-not $this.EdgesBySource.ContainsKey($edge.SourceId)) {
            $this.EdgesBySource[$edge.SourceId] = [System.Collections.Generic.List[ResourceGraphEdge]]::new()
        }
        $this.EdgesBySource[$edge.SourceId].Add($edge)
    }

    [ResourceGraphEdge[]] GetOutgoingEdges([string]$nodeId) {
        if ($this.EdgesBySource.ContainsKey($nodeId)) {
            return $this.EdgesBySource[$nodeId]
        }
        return @()
    }

    [PSCustomObject] ToPSCustomObject() {
        $nodeList = $this.Nodes.Values | ForEach-Object {
            [PSCustomObject]@{
                id             = $_.Id
                name           = $_.Name
                type           = $_.Type
                resourceGroup  = $_.ResourceGroup
                subscriptionId = $_.SubscriptionId
                location       = $_.Location
            }
        }
        $edgeList = $this.Edges | ForEach-Object {
            [PSCustomObject]@{
                sourceId      = $_.SourceId
                targetId      = $_.TargetId
                cardinality   = $_.Cardinality.ToString()
                discoveredVia = $_.DiscoveredVia
            }
        }
        return [PSCustomObject]@{
            nodes = @($nodeList)
            edges = @($edgeList)
        }
    }
}
