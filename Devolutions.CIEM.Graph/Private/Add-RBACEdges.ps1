function Add-RBACEdges {
    <#
    .SYNOPSIS
        Builds RBAC relationship edges: HAS_ROLE_ASSIGNMENT, USES_ROLE, HAS_PERMISSIONS.

    .DESCRIPTION
        Creates the RBAC chain: Identity → HAS_ROLE_ASSIGNMENT → RoleAssignment → USES_ROLE → RoleDefinition → HAS_PERMISSIONS → Permissions

    .PARAMETER Graph
        The CIEMGraph to add edges to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph
    )
    $ErrorActionPreference = 'Stop'

    # Build lookup of role definitions by ID
    $roleDefById = @{}
    foreach ($roleDef in $Graph.GetNodesByType([CIEMGraphNodeType]::AzureRoleDefinition)) {
        $roleDefById[$roleDef.Id] = $roleDef
    }

    # Process each role assignment
    foreach ($assignment in $Graph.GetNodesByType([CIEMGraphNodeType]::AzureRoleAssignment)) {
        # HAS_ROLE_ASSIGNMENT: Identity (User/Group/SP) → RoleAssignment
        if ($assignment.PrincipalId -and $Graph.GetNode($assignment.PrincipalId)) {
            $Graph.AddEdge($assignment.PrincipalId, $assignment.Id, [CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT)
        }

        # USES_ROLE: RoleAssignment → RoleDefinition
        if ($assignment.RoleDefinitionId -and $roleDefById.ContainsKey($assignment.RoleDefinitionId)) {
            $Graph.AddEdge($assignment.Id, $assignment.RoleDefinitionId, [CIEMGraphRelationship]::USES_ROLE)
        }
    }

    # HAS_PERMISSIONS: RoleDefinition → Permissions
    # Permission nodes have synthetic IDs based on role definition ID
    foreach ($permNode in $Graph.GetNodesByType([CIEMGraphNodeType]::AzurePermissions)) {
        # Permission node IDs are formatted as "{roleDefId}:perm:{index}"
        $roleDefId = ($permNode.Id -split ':perm:')[0]
        if ($roleDefById.ContainsKey($roleDefId)) {
            $Graph.AddEdge($roleDefId, $permNode.Id, [CIEMGraphRelationship]::HAS_PERMISSIONS)
        }
    }
}
