function Add-IdentityEdges {
    <#
    .SYNOPSIS
        Builds identity relationship edges: REPORTS_TO, MEMBER_OF, OWNER_OF, HAS_SERVICE_PRINCIPAL.

    .PARAMETER Graph
        The CIEMGraph to add edges to.

    .PARAMETER EntraData
        Raw Entra service cache data hashtable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph,

        [Parameter(Mandatory)]
        [hashtable]$EntraData
    )
    $ErrorActionPreference = 'Stop'

    # REPORTS_TO: User → Manager (user reports to manager)
    $users = $Graph.GetNodesByType([CIEMGraphNodeType]::EntraUser)
    foreach ($user in $users) {
        if ($user.ManagerId -and $Graph.GetNode($user.ManagerId)) {
            $Graph.AddEdge($user.Id, $user.ManagerId, [CIEMGraphRelationship]::REPORTS_TO)
        }
    }

    # MEMBER_OF: Member → Group
    if ($EntraData.ContainsKey('GroupMembers') -and $EntraData.GroupMembers -is [hashtable]) {
        foreach ($entry in $EntraData.GroupMembers.GetEnumerator()) {
            $groupId = $entry.Key
            $members = $entry.Value
            if (-not $members -or -not $Graph.GetNode($groupId)) { continue }

            foreach ($member in $members) {
                if ($member.id -and $Graph.GetNode($member.id)) {
                    $Graph.AddEdge($member.id, $groupId, [CIEMGraphRelationship]::MEMBER_OF)
                }
            }
        }
    }

    # OWNER_OF: Owner → Group
    if ($EntraData.ContainsKey('GroupOwners') -and $EntraData.GroupOwners -is [hashtable]) {
        foreach ($entry in $EntraData.GroupOwners.GetEnumerator()) {
            $groupId = $entry.Key
            $owners = $entry.Value
            if (-not $owners -or -not $Graph.GetNode($groupId)) { continue }

            foreach ($owner in $owners) {
                if ($owner.id -and $Graph.GetNode($owner.id)) {
                    $Graph.AddEdge($owner.id, $groupId, [CIEMGraphRelationship]::OWNER_OF)
                }
            }
        }
    }

    # HAS_SERVICE_PRINCIPAL: Application → ServicePrincipal
    $apps = $Graph.GetNodesByType([CIEMGraphNodeType]::EntraApplication)
    $spByAppId = @{}
    foreach ($sp in $Graph.GetNodesByType([CIEMGraphNodeType]::EntraServicePrincipal)) {
        if ($sp.AppId) { $spByAppId[$sp.AppId] = $sp }
    }

    foreach ($app in $apps) {
        if ($app.AppId -and $spByAppId.ContainsKey($app.AppId)) {
            $Graph.AddEdge($app.Id, $spByAppId[$app.AppId].Id, [CIEMGraphRelationship]::HAS_SERVICE_PRINCIPAL)
        }
    }
}
