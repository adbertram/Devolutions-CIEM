class CIEMGraph {
    [hashtable]$Nodes
    [System.Collections.Generic.List[CIEMGraphEdge]]$Edges
    hidden [hashtable]$EdgesBySource
    hidden [hashtable]$EdgesByTarget
    [datetime]$BuildTime
    [string]$TenantId
    [string[]]$SubscriptionIds

    CIEMGraph() {
        $this.Nodes = @{}
        $this.Edges = [System.Collections.Generic.List[CIEMGraphEdge]]::new()
        $this.EdgesBySource = @{}
        $this.EdgesByTarget = @{}
        $this.BuildTime = [datetime]::UtcNow
        $this.SubscriptionIds = @()
    }

    [void] AddNode([CIEMGraphNode]$Node) {
        $this.Nodes[$Node.Id] = $Node
    }

    [void] AddEdge([CIEMGraphEdge]$Edge) {
        $this.Edges.Add($Edge)
        # Update source index
        if (-not $this.EdgesBySource.ContainsKey($Edge.SourceId)) {
            $this.EdgesBySource[$Edge.SourceId] = [System.Collections.Generic.List[CIEMGraphEdge]]::new()
        }
        $this.EdgesBySource[$Edge.SourceId].Add($Edge)
        # Update target index
        if (-not $this.EdgesByTarget.ContainsKey($Edge.TargetId)) {
            $this.EdgesByTarget[$Edge.TargetId] = [System.Collections.Generic.List[CIEMGraphEdge]]::new()
        }
        $this.EdgesByTarget[$Edge.TargetId].Add($Edge)
    }

    [void] AddEdge([string]$SourceId, [string]$TargetId, [CIEMGraphRelationship]$Relationship) {
        $edge = [CIEMGraphEdge]::new($SourceId, $TargetId, $Relationship)
        $this.AddEdge($edge)
    }

    [CIEMGraphNode] GetNode([string]$Id) {
        return $this.Nodes[$Id]
    }

    [CIEMGraphEdge[]] GetEdgesFrom([string]$NodeId) {
        if ($this.EdgesBySource.ContainsKey($NodeId)) {
            return @($this.EdgesBySource[$NodeId])
        }
        return @()
    }

    [CIEMGraphEdge[]] GetEdgesTo([string]$NodeId) {
        if ($this.EdgesByTarget.ContainsKey($NodeId)) {
            return @($this.EdgesByTarget[$NodeId])
        }
        return @()
    }

    [CIEMGraphEdge[]] GetEdgesByRelationship([CIEMGraphRelationship]$Relationship) {
        return @($this.Edges | Where-Object { $_.Relationship -eq $Relationship })
    }

    [CIEMGraphNode[]] GetNodesByType([CIEMGraphNodeType]$Type) {
        return @($this.Nodes.Values | Where-Object { $_.NodeType -eq $Type })
    }

    # String-based lookup for resource target types (e.g., "SqlServer", "KeyVault")
    # that may not have corresponding CIEMGraphNodeType enum values.
    [CIEMGraphNode[]] GetNodesByTypeString([string]$TypeName) {
        return @($this.Nodes.Values | Where-Object { $_.NodeType.ToString() -eq $TypeName })
    }

    # Traverse a chain of relationships from a start node
    # E.g., Traverse("user1", @("HAS_ROLE_ASSIGNMENT", "USES_ROLE", "HAS_PERMISSIONS"))
    # Returns the terminal nodes reached at the end of the chain
    [CIEMGraphNode[]] Traverse([string]$StartId, [CIEMGraphRelationship[]]$Chain) {
        $currentIds = @($StartId)

        foreach ($rel in $Chain) {
            $nextIds = @()
            foreach ($id in $currentIds) {
                $matchingEdges = $this.GetEdgesFrom($id) | Where-Object { $_.Relationship -eq $rel }
                $nextIds += @($matchingEdges | ForEach-Object { $_.TargetId })
            }
            $currentIds = @($nextIds | Select-Object -Unique)
            if ($currentIds.Count -eq 0) { break }
        }

        return @($currentIds | ForEach-Object { $this.GetNode($_) } | Where-Object { $_ })
    }

    # Serialize for PSU cache (class instances become PSCustomObjects)
    [PSCustomObject] ToPSCustomObject() {
        $serializedNodes = @{}
        foreach ($entry in $this.Nodes.GetEnumerator()) {
            $node = $entry.Value
            $nodeObj = [ordered]@{
                _type    = $node.GetType().Name
                Id       = $node.Id
                NodeType = $node.NodeType.ToString()
            }
            # Copy all properties except Id and NodeType (already included)
            foreach ($prop in $node.PSObject.Properties) {
                if ($prop.Name -notin @('Id', 'NodeType')) {
                    $nodeObj[$prop.Name] = $prop.Value
                }
            }
            $serializedNodes[$entry.Key] = [PSCustomObject]$nodeObj
        }

        $serializedEdges = @($this.Edges | ForEach-Object {
            [PSCustomObject]@{
                SourceId     = $_.SourceId
                TargetId     = $_.TargetId
                Relationship = $_.Relationship.ToString()
                Properties   = $_.Properties
            }
        })

        return [PSCustomObject]@{
            Nodes           = $serializedNodes
            Edges           = $serializedEdges
            BuildTime       = $this.BuildTime
            TenantId        = $this.TenantId
            SubscriptionIds = $this.SubscriptionIds
        }
    }

    # Deserialize from PSU cache
    static [CIEMGraph] FromPSCustomObject([PSCustomObject]$Data) {
        $graph = [CIEMGraph]::new()
        $graph.BuildTime = [datetime]$Data.BuildTime
        $graph.TenantId = $Data.TenantId
        $graph.SubscriptionIds = @($Data.SubscriptionIds)

        # Type map for deserialization
        $typeMap = @{
            'CIEMEntraUser'              = [CIEMEntraUser]
            'CIEMEntraGroup'             = [CIEMEntraGroup]
            'CIEMEntraServicePrincipal'  = [CIEMEntraServicePrincipal]
            'CIEMEntraApplication'       = [CIEMEntraApplication]
            'CIEMEntraAppRoleAssignment' = [CIEMEntraAppRoleAssignment]
            'CIEMAzureRoleAssignment'    = [CIEMAzureRoleAssignment]
            'CIEMAzureRoleDefinition'    = [CIEMAzureRoleDefinition]
            'CIEMAzurePermissions'       = [CIEMAzurePermissions]
        }

        # Reconstruct nodes (handles both hashtable and PSCustomObject from JSON round-trip)
        $nodeEntries = if ($Data.Nodes -is [hashtable]) {
            $Data.Nodes.GetEnumerator()
        }
        else {
            # After ConvertFrom-Json, Nodes is a PSCustomObject — iterate its properties
            $Data.Nodes.PSObject.Properties
        }

        foreach ($entry in $nodeEntries) {
            $nodeKey = $entry.Name
            $nodeData = $entry.Value
            $typeName = $nodeData._type
            if ($typeMap.ContainsKey($typeName)) {
                $node = $typeMap[$typeName]::new()
                foreach ($prop in $nodeData.PSObject.Properties) {
                    if ($prop.Name -eq '_type') { continue }
                    if ($node.PSObject.Properties.Name -contains $prop.Name) {
                        $node.$($prop.Name) = $prop.Value
                    }
                }
                $graph.Nodes[$nodeKey] = $node
            }
        }

        # Reconstruct edges
        foreach ($edgeData in $Data.Edges) {
            $edge = [CIEMGraphEdge]::new()
            $edge.SourceId = $edgeData.SourceId
            $edge.TargetId = $edgeData.TargetId
            $edge.Relationship = [CIEMGraphRelationship]$edgeData.Relationship
            if ($edgeData.Properties) {
                if ($edgeData.Properties -is [hashtable]) {
                    $edge.Properties = $edgeData.Properties
                }
                else {
                    # Convert PSCustomObject (from JSON round-trip) to hashtable
                    $ht = @{}
                    foreach ($prop in $edgeData.Properties.PSObject.Properties) {
                        $ht[$prop.Name] = $prop.Value
                    }
                    $edge.Properties = $ht
                }
            }
            $graph.AddEdge($edge)
        }

        return $graph
    }
}
