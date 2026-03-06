function ConvertTo-CIEMGraphMermaid {
    <#
    .SYNOPSIS
        Renders a Mermaid diagram showing identities with access to a resource type.
    .DESCRIPTION
        Takes serialized graph cache data and a target resource type, then produces a
        Mermaid flowchart string showing all identities (users, groups, service principals)
        with CAN_READ/CAN_WRITE/CAN_MANAGE access. Group nodes are expanded to show
        MEMBER_OF relationships with dashed edges.

        Nodes are color-coded by identity type. Edges are labeled with permission level.
        If a user appears both directly and via group membership, both paths are shown
        but the user node is rendered only once (deduplication).
    .PARAMETER Data
        The PSCustomObject from Get-PSUCache (serialized CIEMGraph).
    .PARAMETER TargetType
        The resource type to visualize (e.g., "KeyVault", "SqlServer").
    .PARAMETER Direction
        Mermaid layout direction. Defaults to TD (top-down).
    .EXAMPLE
        $data = Get-PSUCache -Key $script:GraphAzureCacheKey
        ConvertTo-CIEMGraphMermaid -Data $data -TargetType 'KeyVault'
    .EXAMPLE
        ConvertTo-CIEMGraphMermaid -Data $data -TargetType 'SqlServer' -Direction LR
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Data,

        [Parameter(Mandatory)]
        [string]$TargetType,

        [Parameter()]
        [ValidateSet('TD', 'LR', 'BT', 'RL')]
        [string]$Direction = 'TD'
    )
    $ErrorActionPreference = 'Stop'

    $graph = [CIEMGraph]::FromPSCustomObject($Data)

    # Get all computed permission edges targeting this resource type
    $targetNodeId = "type:$TargetType"
    $permissionEdges = @($graph.GetEdgesTo($targetNodeId) | Where-Object {
        $_.Relationship -in @(
            [CIEMGraphRelationship]::CAN_READ
            [CIEMGraphRelationship]::CAN_WRITE
            [CIEMGraphRelationship]::CAN_MANAGE
        )
    })

    $lines = [System.Collections.ArrayList]::new()
    [void]$lines.Add("graph $Direction")

    if ($permissionEdges.Count -eq 0) {
        # Empty diagram — just the resource type node
        $safeType = $TargetType -replace '["<>#;&`/\\|\[\]{}()]', '_'
        [void]$lines.Add("    R[`"$safeType`"]")
        [void]$lines.Add("    classDef resource fill:#DE3618,stroke:#A02010,color:#fff")
        [void]$lines.Add("    class R resource")
        return ($lines -join "`n")
    }

    # Build identity label/category lookup from canonical data
    $identityMeta = @{}
    foreach ($ident in (Get-CIEMIdentity | Where-Object { $_.Name -eq $_.GraphNodeType })) {
        $identityMeta[$ident.GraphNodeType] = @{
            Label    = $ident.DisplayName
            Category = $ident.GraphNodeType.ToLower()
        }
    }

    # Collect identity nodes and build Mermaid-safe ID map
    $nodeMap = @{}       # nodeId -> mermaidId
    $nodeCategories = @{ resource = [System.Collections.ArrayList]::new() }
    foreach ($key in $identityMeta.Keys) { $nodeCategories[$identityMeta[$key].Category] = [System.Collections.ArrayList]::new() }
    $nodeIndex = 0

    # Root resource type node
    $safeType = $TargetType -replace '["<>#;&`/\\|\[\]{}()]', '_'
    [void]$lines.Add("    R[`"$safeType`"]")
    [void]$nodeCategories['resource'].Add('R')

    # Track group IDs for membership expansion
    $groupIds = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($edge in $permissionEdges) {
        $identity = $graph.GetNode($edge.SourceId)
        if (-not $identity) { continue }

        # Get or create Mermaid ID for this identity
        if (-not $nodeMap.ContainsKey($identity.Id)) {
            $mermaidId = "n$nodeIndex"
            $nodeMap[$identity.Id] = $mermaidId
            $nodeIndex++

            # Determine label and category
            $displayName = if ($identity.PSObject.Properties.Name -contains 'DisplayName' -and $identity.DisplayName) {
                $identity.DisplayName
            } elseif ($identity.PSObject.Properties.Name -contains 'UserPrincipalName' -and $identity.UserPrincipalName) {
                $identity.UserPrincipalName
            } else {
                $identity.Id
            }
            $safeName = $displayName -replace '["<>#;&`/\\|\[\]{}()]', '_'

            $nodeTypeStr = $identity.NodeType.ToString()
            $meta = $identityMeta[$nodeTypeStr]
            if ($meta) {
                $label = "$($meta.Label): $safeName"
                $category = $meta.Category
            } else {
                $label = $safeName
                $category = ($identityMeta.Values | Select-Object -First 1).Category
            }
            if ($nodeTypeStr -eq 'EntraGroup') { [void]$groupIds.Add($identity.Id) }

            [void]$lines.Add("    ${mermaidId}[`"$label`"]")
            [void]$nodeCategories[$category].Add($mermaidId)
        }

        # Edge from resource to identity with permission label
        $rel = $edge.Relationship.ToString()
        $mId = $nodeMap[$identity.Id]
        [void]$lines.Add("    R -->|${rel}| ${mId}")
    }

    # Expand group memberships: find MEMBER_OF edges pointing to each group
    foreach ($groupId in $groupIds) {
        $memberEdges = @($graph.GetEdgesTo($groupId) | Where-Object {
            $_.Relationship -eq [CIEMGraphRelationship]::MEMBER_OF
        })

        foreach ($memberEdge in $memberEdges) {
            $member = $graph.GetNode($memberEdge.SourceId)
            if (-not $member) { continue }

            # Get or create Mermaid ID for this member (deduplication)
            if (-not $nodeMap.ContainsKey($member.Id)) {
                $mermaidId = "n$nodeIndex"
                $nodeMap[$member.Id] = $mermaidId
                $nodeIndex++

                $displayName = if ($member.PSObject.Properties.Name -contains 'DisplayName' -and $member.DisplayName) {
                    $member.DisplayName
                } elseif ($member.PSObject.Properties.Name -contains 'UserPrincipalName' -and $member.UserPrincipalName) {
                    $member.UserPrincipalName
                } else {
                    $member.Id
                }
                $safeName = $displayName -replace '["<>#;&`/\\|\[\]{}()]', '_'

                $nodeTypeStr = $member.NodeType.ToString()
                $meta = $identityMeta[$nodeTypeStr]
                if ($meta) {
                    $label = "$($meta.Label): $safeName"
                    $category = $meta.Category
                } else {
                    $label = $safeName
                    $category = ($identityMeta.Values | Select-Object -First 1).Category
                }

                [void]$lines.Add("    ${mermaidId}[`"$label`"]")
                [void]$nodeCategories[$category].Add($mermaidId)
            }

            # Dashed edge from group to member (MEMBER_OF)
            $groupMermaidId = $nodeMap[$groupId]
            $memberMermaidId = $nodeMap[$member.Id]
            [void]$lines.Add("    ${groupMermaidId} -.->|MEMBER_OF| ${memberMermaidId}")
        }
    }

    # Category color styles — identity categories from Get-CIEMIdentity, resource fixed
    $typeColors = @{
        'Human'      = 'fill:#4A90D9,stroke:#2C5F8A,color:#fff'
        'Collection' = 'fill:#50B83C,stroke:#2E7D20,color:#fff'
        'Workload'   = 'fill:#F49342,stroke:#C26D1A,color:#fff'
    }
    $categoryStyles = @{ resource = 'fill:#DE3618,stroke:#A02010,color:#fff' }
    foreach ($ident in (Get-CIEMIdentity | Where-Object { $_.Name -eq $_.GraphNodeType })) {
        $cat = $ident.GraphNodeType.ToLower()
        if (-not $categoryStyles.ContainsKey($cat) -and $typeColors.ContainsKey($ident.Type)) {
            $categoryStyles[$cat] = $typeColors[$ident.Type]
        }
    }

    foreach ($entry in $categoryStyles.GetEnumerator()) {
        [void]$lines.Add("    classDef $($entry.Key) $($entry.Value)")
    }

    # Apply styles to nodes by category
    foreach ($entry in $nodeCategories.GetEnumerator()) {
        if ($entry.Value.Count -gt 0) {
            $nodeList = $entry.Value -join ','
            [void]$lines.Add("    class ${nodeList} $($entry.Key)")
        }
    }

    return ($lines -join "`n")
}
