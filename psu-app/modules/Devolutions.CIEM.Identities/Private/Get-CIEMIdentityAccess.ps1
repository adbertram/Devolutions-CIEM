function Get-CIEMIdentityAccess {
    <#
    .SYNOPSIS
        Answers "What can this identity access?" by traversing the graph.

    .DESCRIPTION
        Returns all resources and permission levels reachable from an identity
        through RBAC role assignments and computed permission edges. Optionally
        expands group memberships to include inherited access.

    .PARAMETER Graph
        The CIEMGraph to query.

    .PARAMETER IdentityId
        The ID of the identity (user, group, or service principal).

    .PARAMETER ExpandGroups
        When specified, also includes access inherited through group memberships.

    .OUTPUTS
        [PSCustomObject[]] Objects with IdentityId, IdentityName, Relationship, TargetType, Scopes.

    .EXAMPLE
        Get-CIEMIdentityAccess -Graph $graph -IdentityId "user-guid-here"

    .EXAMPLE
        Get-CIEMIdentityAccess -Graph $graph -IdentityId "user-guid-here" -ExpandGroups
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph,

        [Parameter(Mandatory)]
        [string]$IdentityId,

        [Parameter()]
        [switch]$ExpandGroups
    )

    $ErrorActionPreference = 'Stop'

    $identity = $Graph.GetNode($IdentityId)
    if (-not $identity) {
        Write-Warning "Identity not found: $IdentityId"
        return @()
    }

    # Resolve the queried identity's display name for use in inherited access labels
    $originalIdentityName = if ($identity.PSObject.Properties.Name -contains 'DisplayName') { $identity.DisplayName } else { $IdentityId }

    # Collect all effective identity IDs (direct + group memberships)
    $effectiveIds = [System.Collections.Generic.List[string]]::new()
    $effectiveIds.Add($IdentityId)

    if ($ExpandGroups) {
        # BFS traversal with cycle detection for arbitrarily nested groups (Azure supports 7+ levels)
        $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $queue = [System.Collections.Generic.Queue[string]]::new()
        [void]$visited.Add($IdentityId)
        # Seed with direct group memberships
        $Graph.GetEdgesFrom($IdentityId) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::MEMBER_OF } | ForEach-Object {
            $queue.Enqueue($_.TargetId)
        }
        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            if (-not $visited.Add($current)) { continue }
            $effectiveIds.Add($current)
            $Graph.GetEdgesFrom($current) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::MEMBER_OF } | ForEach-Object {
                $queue.Enqueue($_.TargetId)
            }
        }
    }

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()

    foreach ($id in $effectiveIds) {
        $node = $Graph.GetNode($id)
        $groupName = if ($node.PSObject.Properties.Name -contains 'DisplayName') { $node.DisplayName } else { $id }
        $isDirect = ($id -eq $IdentityId)

        # Get computed permission edges
        $permEdges = $Graph.GetEdgesFrom($id) | Where-Object {
            $_.Relationship -in @(
                [CIEMGraphRelationship]::CAN_READ
                [CIEMGraphRelationship]::CAN_WRITE
                [CIEMGraphRelationship]::CAN_MANAGE
            )
        }

        foreach ($edge in $permEdges) {
            $results.Add([PSCustomObject]@{
                IdentityId   = $IdentityId
                IdentityName = if ($isDirect) { $originalIdentityName } else { "$originalIdentityName (via $groupName)" }
                EffectiveId  = $id
                Relationship = $edge.Relationship.ToString()
                TargetType   = $edge.Properties['targetType']
                Scopes       = $edge.Properties['scopes']
                IsDirect     = $isDirect
            })
        }

        # Get direct RBAC role assignments
        $roleEdges = $Graph.GetEdgesFrom($id) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT }
        foreach ($roleEdge in $roleEdges) {
            $roleAssignment = $Graph.GetNode($roleEdge.TargetId)
            if (-not $roleAssignment) { continue }

            # Follow to role definition
            $roleDefEdges = $Graph.GetEdgesFrom($roleEdge.TargetId) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::USES_ROLE }
            foreach ($defEdge in $roleDefEdges) {
                $roleDef = $Graph.GetNode($defEdge.TargetId)
                if (-not $roleDef) { continue }

                $results.Add([PSCustomObject]@{
                    IdentityId   = $IdentityId
                    IdentityName = if ($isDirect) { $originalIdentityName } else { "$originalIdentityName (via $groupName)" }
                    EffectiveId  = $id
                    Relationship = 'HAS_ROLE'
                    TargetType   = "Role: $($roleDef.RoleName)"
                    Scopes       = @($roleAssignment.Scope)
                    IsDirect     = $isDirect
                })
            }
        }
    }

    return $results
}
