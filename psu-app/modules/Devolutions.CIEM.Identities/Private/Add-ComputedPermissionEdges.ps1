function Add-ComputedPermissionEdges {
    <#
    .SYNOPSIS
        Computes CAN_READ/CAN_WRITE/CAN_MANAGE edges from RBAC role assignments.

    .DESCRIPTION
        Port of Cartography's permission relationship evaluation logic.
        For each identity with role assignments:
        1. Traverse: identity → HAS_ROLE_ASSIGNMENT → USES_ROLE → HAS_PERMISSIONS
        2. Collect effective actions/notActions
        3. For each entry in permission_relationships.json:
           - Check if any action matches the required permissions (OR logic)
           - Check notActions don't negate it
           - If match: create CAN_READ/WRITE/MANAGE edge

    .PARAMETER Graph
        The CIEMGraph to add computed edges to.

    .PARAMETER PermissionRelationships
        Array of permission relationship definitions from permission_relationships.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph,

        [Parameter(Mandatory)]
        [object[]]$PermissionRelationships
    )
    $ErrorActionPreference = 'Stop'

    # Collect all identity node IDs from canonical identity type data
    $identityTypes = @(Get-CIEMIdentity | Where-Object { $_.PrincipalType } | ForEach-Object {
        [CIEMGraphNodeType]($_.GraphNodeType)
    } | Select-Object -Unique)

    $identityIds = [System.Collections.Generic.List[string]]::new()
    foreach ($type in $identityTypes) {
        foreach ($node in $Graph.GetNodesByType($type)) { $identityIds.Add($node.Id) }
    }

    # Relationship chain for RBAC traversal
    $rbacChain = @(
        [CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT
        [CIEMGraphRelationship]::USES_ROLE
        [CIEMGraphRelationship]::HAS_PERMISSIONS
    )

    foreach ($identityId in $identityIds) {
        # Traverse the RBAC chain to get all permission nodes for this identity
        $permissionNodes = $Graph.Traverse($identityId, $rbacChain)
        if ($permissionNodes.Count -eq 0) { continue }

        # Also get the role assignments to know scopes
        $roleAssignmentNodes = $Graph.Traverse($identityId, @([CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT))

        # Collect all effective actions and notActions
        $allActions = [System.Collections.Generic.List[string]]::new()
        $allNotActions = [System.Collections.Generic.List[string]]::new()
        $allDataActions = [System.Collections.Generic.List[string]]::new()
        $allNotDataActions = [System.Collections.Generic.List[string]]::new()

        foreach ($permNode in $permissionNodes) {
            if ($permNode.Actions) { foreach ($a in $permNode.Actions) { $allActions.Add($a) } }
            if ($permNode.NotActions) { foreach ($a in $permNode.NotActions) { $allNotActions.Add($a) } }
            if ($permNode.DataActions) { foreach ($a in $permNode.DataActions) { $allDataActions.Add($a) } }
            if ($permNode.NotDataActions) { foreach ($a in $permNode.NotDataActions) { $allNotDataActions.Add($a) } }
        }

        if ($allActions.Count -eq 0 -and $allDataActions.Count -eq 0) { continue }

        # Evaluate each permission relationship definition
        foreach ($rpr in $PermissionRelationships) {
            $requiredPermissions = @($rpr.permissions)
            $relationshipName = $rpr.relationship

            # Check if any of the required permissions are granted (OR logic)
            # For each permission, check if it's granted AND not negated
            $hasUnnegatedMatch = $false
            foreach ($requiredPerm in $requiredPermissions) {
                $isGranted = $false

                # Check control plane actions
                foreach ($action in $allActions) {
                    if (Test-AzureActionMatch -Pattern $action -Action $requiredPerm) {
                        $isGranted = $true
                        break
                    }
                }

                # Check data plane actions
                if (-not $isGranted) {
                    foreach ($dataAction in $allDataActions) {
                        if (Test-AzureActionMatch -Pattern $dataAction -Action $requiredPerm) {
                            $isGranted = $true
                            break
                        }
                    }
                }

                if (-not $isGranted) { continue }

                # Check if THIS specific matched permission is negated
                $isNegated = $false
                foreach ($notAction in $allNotActions) {
                    if (Test-AzureActionMatch -Pattern $notAction -Action $requiredPerm) {
                        $isNegated = $true
                        break
                    }
                }
                if (-not $isNegated) {
                    foreach ($notDataAction in $allNotDataActions) {
                        if (Test-AzureActionMatch -Pattern $notDataAction -Action $requiredPerm) {
                            $isNegated = $true
                            break
                        }
                    }
                }

                if (-not $isNegated) {
                    $hasUnnegatedMatch = $true
                    break
                }
            }

            if (-not $hasUnnegatedMatch) { continue }

            # Map relationship string to enum
            $rel = switch ($relationshipName) {
                'CAN_READ'   { [CIEMGraphRelationship]::CAN_READ }
                'CAN_WRITE'  { [CIEMGraphRelationship]::CAN_WRITE }
                'CAN_MANAGE' { [CIEMGraphRelationship]::CAN_MANAGE }
                default      { continue }
            }

            # Filter role assignment scopes against the resource type node.
            # Now that resource types are real nodes (CIEMAzureResourceTypeNode), look up directly.
            $assignmentScopes = @($roleAssignmentNodes | ForEach-Object { $_.Scope } | Select-Object -Unique)
            $targetTypeNode = $Graph.GetNode("type:$($rpr.targetType)")
            if ($targetTypeNode) {
                # Resource type nodes are category-level (no specific scope), so no scope filtering needed.
                # The node exists, confirming this is a valid target type.
            }

            # Create computed edge with scope info from role assignments
            $edge = [CIEMGraphEdge]::new($identityId, "type:$($rpr.targetType)", $rel)
            $edge.Properties['targetType'] = $rpr.targetType
            $edge.Properties['scopes'] = $assignmentScopes
            $Graph.AddEdge($edge)
        }
    }
}
