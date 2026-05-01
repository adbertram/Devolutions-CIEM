function InvokeCIEMGraphEdgeBuild {
    <#
    .SYNOPSIS
        Transforms collected relationship objects into graph_edges rows.
    .DESCRIPTION
        Maps relationship names (member_of, owner_of, has_role_member, transitive_member_of) to
        PascalCase edge kinds and saves them as non-computed (computed=0) graph edges.
        Skips edges where source or target nodes do not exist in graph_nodes (FK constraint safety).
        Skips unknown relationship types with a warning log entry.
    .PARAMETER Relationships
        Array of relationship objects with SourceId, TargetId, Relationship, SourceType, TargetType.
    .PARAMETER Connection
        SQLite connection for transaction support. Pass $null for standalone operations.
    .PARAMETER CollectedAt
        ISO 8601 timestamp for the collection time.
    .OUTPUTS
        [int] Total number of edges created.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Relationships,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Connection,

        [Parameter(Mandatory)]
        [string]$CollectedAt
    )

    $ErrorActionPreference = 'Stop'

    # Map relationship names to edge kinds (PascalCase)
    $kindMap = @{
        'member_of'            = 'MemberOf'
        'owner_of'             = 'OwnerOf'
        'has_role_member'      = 'HasRoleMember'
        'transitive_member_of' = 'TransitiveMemberOf'
    }

    $edgeCount = 0

    # PowerShell hashtables are case-insensitive; SQLite text foreign keys are not.
    $nodeExistsCache = [System.Collections.Generic.Dictionary[string, bool]]::new([System.StringComparer]::Ordinal)

    # Helper: check if node exists in graph, with caching
    # Must use same $Connection to see uncommitted nodes within a transaction
    function NodeExists([string]$nodeId) {
        $ErrorActionPreference = 'Stop'
        if (-not $nodeId) { return $false }
        if ($nodeExistsCache.ContainsKey($nodeId)) { return $nodeExistsCache[$nodeId] }
        $fkParams = @{ Query = "SELECT 1 FROM graph_nodes WHERE id = @id"; Parameters = @{ id = $nodeId } }
        if ($Connection) { $fkParams.Connection = $Connection }
        $exists = (@(Invoke-CIEMQuery @fkParams).Count -gt 0)
        $nodeExistsCache[$nodeId] = $exists
        $exists
    }

    foreach ($rel in $Relationships) {
        $edgeKind = $kindMap[$rel.Relationship]
        if (-not $edgeKind) {
            Write-CIEMLog "Unknown relationship type '$($rel.Relationship)', skipping" -Severity WARNING -Component 'GraphBuilder'
            continue
        }

        # Only create edge if both source and target nodes exist (FK constraint)
        if (-not (NodeExists $rel.SourceId) -or -not (NodeExists $rel.TargetId)) { continue }

        $splat = @{
            SourceId    = $rel.SourceId
            TargetId    = $rel.TargetId
            Kind        = $edgeKind
            Computed    = 0
            CollectedAt = $CollectedAt
        }
        if ($Connection) { $splat.Connection = $Connection }

        Save-CIEMGraphEdge @splat
        $edgeCount++
    }

    Write-CIEMLog "Graph edge build: $edgeCount collected edges created" -Component 'GraphBuilder'
    $edgeCount
}
