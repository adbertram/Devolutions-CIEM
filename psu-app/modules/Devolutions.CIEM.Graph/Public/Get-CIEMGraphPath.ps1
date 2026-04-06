function Get-CIEMGraphPath {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [string]$FromKind,

        [Parameter(Mandatory)]
        [string]$ToKind,

        [Parameter()]
        [int]$MaxDepth = 5,

        [Parameter()]
        [string]$EdgeKind
    )

    $ErrorActionPreference = 'Stop'

    # Find start nodes
    $startNodes = @(Get-CIEMGraphNode -Kind $FromKind)
    if ($startNodes.Count -eq 0) { return @() }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($start in $startNodes) {
        $startObj = [PSCustomObject]@{ Id = $start.Id; Kind = $start.Kind; DisplayName = $start.DisplayName; Properties = $start.Properties }

        # BFS queue: each entry is a hashtable with NodeId, PathNodes, PathEdges, Depth
        $queue = [System.Collections.Generic.Queue[hashtable]]::new()
        $queue.Enqueue(@{
            NodeId    = $start.Id
            PathNodes = @($startObj)
            PathEdges = @()
            Depth     = 0
        })
        $visited = @{ $start.Id = $true }

        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            if ($current.Depth -ge $MaxDepth) { continue }

            # Build SQL for outbound edges
            $edgeCondition = "e.source_id = @nodeId"
            $params = @{ nodeId = $current.NodeId }
            if ($EdgeKind) {
                $edgeCondition += " AND e.kind = @edgeKind"
                $params['edgeKind'] = $EdgeKind
            }

            $sql = @"
SELECT e.target_id, e.kind AS edge_kind, e.properties AS edge_properties,
       n.id, n.kind, n.display_name, n.properties
FROM graph_edges e
JOIN graph_nodes n ON n.id = e.target_id
WHERE $edgeCondition
"@
            $neighbors = @(Invoke-CIEMQuery -Query $sql -Parameters $params)

            foreach ($neighbor in $neighbors) {
                if ($visited.ContainsKey($neighbor.id)) { continue }

                $neighborNode = [PSCustomObject]@{
                    Id          = $neighbor.id
                    Kind        = $neighbor.kind
                    DisplayName = $neighbor.display_name
                    Properties  = $neighbor.properties
                }
                $edge = [PSCustomObject]@{
                    Kind       = $neighbor.edge_kind
                    Properties = $neighbor.edge_properties
                }

                $newPathNodes = @($current.PathNodes) + @($neighborNode)
                $newPathEdges = @($current.PathEdges) + @($edge)

                if ($neighbor.kind -eq $ToKind) {
                    $results.Add([PSCustomObject]@{
                        FromNode = $startObj
                        ToNode   = $neighborNode
                        Path     = $newPathNodes
                        Edges    = $newPathEdges
                        Depth    = $current.Depth + 1
                    })
                    # Don't mark destination nodes as visited so multiple paths can reach them
                } else {
                    # Mark intermediate nodes as visited to prevent cycles
                    $visited[$neighbor.id] = $true
                }

                $queue.Enqueue(@{
                    NodeId    = $neighbor.id
                    PathNodes = $newPathNodes
                    PathEdges = $newPathEdges
                    Depth     = $current.Depth + 1
                })
            }
        }
    }

    @($results)
}
