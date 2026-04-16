function InvokeCIEMAttackPathEvaluation {
    [CmdletBinding()]
    [OutputType('CIEMAttackPath')]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Pattern,

        [Parameter()]
        [string]$SeedNodeId
    )

    $ErrorActionPreference = 'Stop'

    $steps = $Pattern.steps
    if (-not $steps -or @($steps).Count -lt 2) { return @() }

    # Step 0: Find seed nodes matching the first step (always a node step)
    $firstStep = $steps[0]
    [string[]]$kinds = @($firstStep.kind)

    $kindPlaceholders = @()
    $parameters = @{}
    for ($k = 0; $k -lt $kinds.Count; $k++) {
        $kindPlaceholders += "@kind$k"
        $parameters["kind$k"] = $kinds[$k]
    }
    $seedSql = "SELECT id, kind, display_name, properties FROM graph_nodes WHERE kind IN ($($kindPlaceholders -join ', '))"
    if ($SeedNodeId) {
        $seedSql += " AND id = @seedNodeId"
        $parameters["seedNodeId"] = $SeedNodeId
    }
    $seedNodes = @(Invoke-CIEMQuery -Query $seedSql -Parameters $parameters)

    # Apply node_filter if present on first step
    if ($firstStep.node_filter) {
        $nodeFilter = [PSCustomObject]$firstStep.node_filter
        $seedNodes = @($seedNodes | Where-Object {
            if (-not $_.properties) { return $false }
            ResolveCIEMAttackPathFilter -PropertiesJson $_.properties -Filter $nodeFilter
        })
    }

    if ($seedNodes.Count -eq 0) { return @() }

    # Initialize paths: each path is an array of interleaved node/edge objects
    $currentPaths = [System.Collections.Generic.List[object]]::new()
    foreach ($node in $seedNodes) {
        $nodeObj = [PSCustomObject]@{ id = $node.id; kind = $node.kind; display_name = $node.display_name; properties = $node.properties; _type = 'node' }
        $currentPaths.Add(@(, $nodeObj))
    }

    # Process remaining steps in pairs: (edge step, optional node step)
    for ($i = 1; $i -lt @($steps).Count; $i += 2) {
        $edgeStep = $steps[$i]
        $nodeStep = if ($i + 1 -lt @($steps).Count) { $steps[$i + 1] } else { $null }

        $edgeKind = $edgeStep.edge
        $direction = if ($edgeStep.direction) { $edgeStep.direction } else { 'outbound' }

        $newPaths = [System.Collections.Generic.List[object]]::new()

        foreach ($path in $currentPaths) {
            $currentNode = $path[$path.Count - 1]
            $currentNodeId = $currentNode.id

            # Build edge query based on direction
            if ($direction -eq 'reverse') {
                $edgeSql = @"
SELECT e.id AS edge_id, e.source_id, e.target_id, e.kind AS edge_kind, e.properties AS edge_properties,
       n.id AS node_id, n.kind AS node_kind, n.display_name AS node_display_name, n.properties AS node_properties
FROM graph_edges e
JOIN graph_nodes n ON n.id = e.source_id
WHERE e.target_id = @nodeId AND e.kind = @edgeKind
"@
            } else {
                $edgeSql = @"
SELECT e.id AS edge_id, e.source_id, e.target_id, e.kind AS edge_kind, e.properties AS edge_properties,
       n.id AS node_id, n.kind AS node_kind, n.display_name AS node_display_name, n.properties AS node_properties
FROM graph_edges e
JOIN graph_nodes n ON n.id = e.target_id
WHERE e.source_id = @nodeId AND e.kind = @edgeKind
"@
            }
            $edgeParams = @{ nodeId = $currentNodeId; edgeKind = $edgeKind }
            $matches = @(Invoke-CIEMQuery -Query $edgeSql -Parameters $edgeParams)

            foreach ($match in $matches) {
                # Apply edge filter if present
                if ($edgeStep.filter) {
                    if (-not $match.edge_properties) { continue }
                    $edgeFilter = [PSCustomObject]$edgeStep.filter
                    $passes = ResolveCIEMAttackPathFilter -PropertiesJson $match.edge_properties -Filter $edgeFilter
                    if (-not $passes) { continue }
                }

                # Apply node kind filter if there is a subsequent node step
                if ($nodeStep) {
                    [string[]]$expectedKinds = @($nodeStep.kind)
                    if ($match.node_kind -notin $expectedKinds) { continue }

                    # Apply node_filter if present on the node step
                    if ($nodeStep.node_filter) {
                        if (-not $match.node_properties) { continue }
                        $nFilter = [PSCustomObject]$nodeStep.node_filter
                        $nodeFilterPasses = ResolveCIEMAttackPathFilter -PropertiesJson $match.node_properties -Filter $nFilter
                        if (-not $nodeFilterPasses) { continue }
                    }
                }

                # Build edge object
                $edgeObj = [PSCustomObject]@{
                    id        = $match.edge_id
                    source_id = $match.source_id
                    target_id = $match.target_id
                    kind      = $match.edge_kind
                    properties = $match.edge_properties
                    _type     = 'edge'
                }

                # Build next node object
                $nextNodeObj = [PSCustomObject]@{
                    id           = $match.node_id
                    kind         = $match.node_kind
                    display_name = $match.node_display_name
                    properties   = $match.node_properties
                    _type        = 'node'
                }

                # Extend path
                $newPath = [object[]]::new($path.Count + 2)
                for ($p = 0; $p -lt $path.Count; $p++) {
                    $newPath[$p] = $path[$p]
                }
                $newPath[$path.Count] = $edgeObj
                $newPath[$path.Count + 1] = $nextNodeObj

                $newPaths.Add($newPath)
            }
        }

        $currentPaths = $newPaths
        if ($currentPaths.Count -eq 0) { return @() }
    }

    # Convert paths to output format
    @(foreach ($path in $currentPaths) {
        $pathNodes = @($path | Where-Object { $_._type -eq 'node' })
        $pathEdges = @($path | Where-Object { $_._type -eq 'edge' })

        $attackPath = [CIEMAttackPath]::new()
        $attackPath.PatternId   = $Pattern.id
        $attackPath.PatternName = $Pattern.name
        $attackPath.Severity    = $Pattern.severity
        $attackPath.Category    = $Pattern.category
        $attackPath.Remediation = $Pattern.remediation
        $attackPath.Path        = $pathNodes
        $attackPath.Edges       = $pathEdges
        if ($Pattern.PSObject.Properties['remediation_script'] -and $Pattern.remediation_script) {
            $script = ResolveCIEMAttackPathRemediationScript -Pattern $Pattern -AttackPath $attackPath
            $attackPath.RemediationScript = $script.Content
            $attackPath.RemediationScriptPath = $script.RelativePath
        }
        $attackPath
    })
}
