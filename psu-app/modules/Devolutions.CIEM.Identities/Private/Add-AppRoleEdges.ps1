function Add-AppRoleEdges {
    <#
    .SYNOPSIS
        Builds app role relationship edges: HAS_APP_ROLE, ASSIGNED_TO.

    .DESCRIPTION
        Creates edges for Entra app role assignments:
        - ServicePrincipal (resource) → HAS_APP_ROLE → AppRoleAssignment
        - AppRoleAssignment → ASSIGNED_TO → Principal (user/group/SP)

    .PARAMETER Graph
        The CIEMGraph to add edges to.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph
    )
    $ErrorActionPreference = 'Stop'

    foreach ($assignment in $Graph.GetNodesByType([CIEMGraphNodeType]::EntraAppRoleAssignment)) {
        # HAS_APP_ROLE: Resource SP → AppRoleAssignment
        if ($assignment.ResourceId -and $Graph.GetNode($assignment.ResourceId)) {
            $Graph.AddEdge($assignment.ResourceId, $assignment.Id, [CIEMGraphRelationship]::HAS_APP_ROLE)
        }

        # ASSIGNED_TO: AppRoleAssignment → Principal (user/group/SP that received the role)
        if ($assignment.PrincipalId -and $Graph.GetNode($assignment.PrincipalId)) {
            $Graph.AddEdge($assignment.Id, $assignment.PrincipalId, [CIEMGraphRelationship]::ASSIGNED_TO)
        }
    }
}
