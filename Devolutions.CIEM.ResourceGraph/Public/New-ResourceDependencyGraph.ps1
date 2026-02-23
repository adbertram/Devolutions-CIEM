function New-ResourceDependencyGraph {
    <#
    .SYNOPSIS
        Builds a resource dependency graph from raw ARM resource objects using schema-driven path resolution.
    .DESCRIPTION
        Takes an array of ARM resource objects (as returned by Azure Resource Graph or Get-AzResource),
        looks up each resource type in the schema, resolves dependency paths to extract target ARM IDs,
        and builds a graph of nodes and edges.
    .EXAMPLE
        $graph = New-ResourceDependencyGraph -Resources $armResources
        $graph.ToPSCustomObject() | ConvertTo-Json -Depth 10
    #>
    [CmdletBinding()]
    [OutputType([ResourceDependencyGraph])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Resources
    )
    $ErrorActionPreference = 'Stop'

    $schema = Read-ResourceTypeSchema
    $graph = [ResourceDependencyGraph]::new()

    # Step 1: Create nodes for all input resources
    foreach ($resource in $Resources) {
        $node = [ResourceGraphNode]::FromArmResource($resource)
        $graph.AddNode($node)
        Write-Verbose "Added node: $($node.Type) - $($node.Name)"
    }

    # Step 2: Resolve dependencies and create edges
    foreach ($resource in $Resources) {
        $typeEntry = $schema[$resource.type]
        if (-not $typeEntry) {
            Write-Verbose "No schema entry for type: $($resource.type)"
            continue
        }

        foreach ($pathEntry in $typeEntry.DependencyPaths.GetEnumerator()) {
            $pathKey = $pathEntry.Key
            $depPath = $pathEntry.Value  # [DependencyPath] object

            $targetIds = Resolve-DependencyPath -Resource $resource -Path $depPath.Path
            foreach ($targetId in $targetIds) {
                if (-not $targetId) { continue }

                # Normalize to lowercase for case-insensitive matching
                $normalizedTargetId = $targetId.ToLowerInvariant()
                $matchingNodeId = $graph.Nodes.Keys | Where-Object { $_.ToLowerInvariant() -eq $normalizedTargetId } | Select-Object -First 1

                if (-not $matchingNodeId) {
                    Write-Verbose "Dangling reference from $($resource.name)::$pathKey -> $targetId"
                    continue
                }

                $cardinality = if ($depPath.Path -match '\[\]') { [ResourceCardinality]::OneToMany } else { [ResourceCardinality]::OneToOne }
                $edge = [ResourceGraphEdge]::new($resource.id, $matchingNodeId, $cardinality, $pathKey)
                $graph.AddEdge($edge)
                Write-Verbose "Added edge: $($resource.name) -[$cardinality]-> $matchingNodeId (via $pathKey)"
            }
        }
    }

    return $graph
}
