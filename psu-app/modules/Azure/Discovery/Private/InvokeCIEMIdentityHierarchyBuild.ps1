function InvokeCIEMIdentityHierarchyBuild {
    <#
    .SYNOPSIS
        Builds a flat ordered node list representing the identity-centric hierarchy tree.
        Returns [PSCustomObject[]] with NodeId, NodeType, Depth, ParentNodeId,
        Relationship, Label properties.
    .NOTES
        Private helper for Get-CIEMAzureIdentityHierarchy.
        The identity hierarchy is a fixed 5-level tree:
        Tenant -> IdentityType -> Identity -> Role -> Scope.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Assignments,

        [Parameter(Mandatory)]
        [ValidateSet('Effective', 'Direct')]
        [string]$Mode,

        [Parameter()]
        [hashtable]$ScopeLabelLookup = @{},

        [Parameter()]
        [hashtable]$GroupNameLookup = @{}
    )

    $ErrorActionPreference = 'Stop'

    $nodes = [System.Collections.Generic.List[PSObject]]::new()

    # Root tenant node
    $tenantNodeId = 'tenant:identity'
    $nodes.Add([PSCustomObject]@{
        NodeId       = $tenantNodeId
        NodeType     = 'Tenant'
        Depth        = 0
        ParentNodeId = $null
        Relationship = $null
        Label        = 'Tenant'
    })

    # Canonical principal type ordering and mapping
    $principalTypeOrder = @('User', 'ServicePrincipal', 'Group', 'ManagedIdentity')
    $principalTypeMap = @{
        'User'             = 'User'
        'ServicePrincipal' = 'ServicePrincipal'
        'Group'            = 'Group'
        'ManagedIdentity'  = 'ManagedIdentity'
        'ForeignGroup'     = 'Group'
        'Unknown'          = 'Unknown'
    }

    # Normalize and group assignments by principal type
    $grouped = @{}
    foreach ($a in $Assignments) {
        $rawType = $a.PrincipalType
        $canonicalType = $principalTypeMap[$rawType]
        if (-not $canonicalType) { $canonicalType = $rawType }

        if (-not $grouped.ContainsKey($canonicalType)) {
            $grouped[$canonicalType] = [System.Collections.Generic.List[object]]::new()
        }
        $grouped[$canonicalType].Add($a)
    }

    # Level 1: IdentityType nodes (in canonical order, then any extras)
    $orderedTypes = @($principalTypeOrder | Where-Object { $grouped.ContainsKey($_) })
    $extraTypes = @($grouped.Keys | Where-Object { $_ -notin $principalTypeOrder } | Sort-Object)
    $allTypes = $orderedTypes + $extraTypes

    foreach ($typeName in $allTypes) {
        $typeAssignments = $grouped[$typeName]
        $typeNodeId = "identitytype:$typeName"
        $typeCount = @($typeAssignments | Select-Object -Property PrincipalId -Unique).Count
        $nodes.Add([PSCustomObject]@{
            NodeId       = $typeNodeId
            NodeType     = 'IdentityType'
            Depth        = 1
            ParentNodeId = $tenantNodeId
            Relationship = 'HAS_ACCESS'
            Label        = "$typeName ($typeCount)"
        })

        # Level 2: Identity nodes — group by PrincipalId within this type
        $byPrincipal = $typeAssignments | Group-Object -Property PrincipalId
        foreach ($principalGroup in $byPrincipal) {
            $principalId = $principalGroup.Name
            $displayName = ($principalGroup.Group[0]).PrincipalDisplayName
            if (-not $displayName) { $displayName = $principalId }
            $identityNodeId = "identity:$principalId"
            $nodes.Add([PSCustomObject]@{
                NodeId       = $identityNodeId
                NodeType     = 'Identity'
                Depth        = 2
                ParentNodeId = $typeNodeId
                Relationship = 'HAS_ACCESS'
                Label        = $displayName
            })

            # Level 3: Role nodes — group by RoleName within this identity
            $byRole = $principalGroup.Group | Group-Object -Property RoleName
            foreach ($roleGroup in $byRole) {
                $roleName = $roleGroup.Name
                if (-not $roleName) { $roleName = 'Unknown Role' }
                $roleNodeId = "role:$principalId|$roleName"
                $nodes.Add([PSCustomObject]@{
                    NodeId       = $roleNodeId
                    NodeType     = 'Role'
                    Depth        = 3
                    ParentNodeId = $identityNodeId
                    Relationship = 'HAS_ACCESS'
                    Label        = $roleName
                })

                # Level 4: Scope nodes — one per unique scope
                $byScope = $roleGroup.Group | Group-Object -Property Scope
                foreach ($scopeGroup in $byScope) {
                    $scopeValue = $scopeGroup.Name
                    $assignment = $scopeGroup.Group[0]

                    # Resolve friendly scope label
                    $scopeLabel = ResolveCIEMScopeLabel -Scope $scopeValue -SubscriptionNameLookup $ScopeLabelLookup

                    # In Effective mode, annotate inherited assignments
                    if ($Mode -eq 'Effective' -and $assignment.OriginalPrincipalId -and $assignment.PrincipalId -ne $assignment.OriginalPrincipalId) {
                        $groupName = $GroupNameLookup[$assignment.OriginalPrincipalId]
                        if ($groupName) {
                            $scopeLabel = "$scopeLabel (via $groupName)"
                        } else {
                            $shortId = if ($assignment.OriginalPrincipalId.Length -gt 8) {
                                $assignment.OriginalPrincipalId.Substring(0, 8)
                            } else { $assignment.OriginalPrincipalId }
                            $scopeLabel = "$scopeLabel (via $shortId)"
                        }
                    }

                    $scopeNodeId = "scope:$principalId|$roleName|$scopeValue"
                    $nodes.Add([PSCustomObject]@{
                        NodeId       = $scopeNodeId
                        NodeType     = 'Scope'
                        Depth        = 4
                        ParentNodeId = $roleNodeId
                        Relationship = 'HAS_ACCESS'
                        Label        = $scopeLabel
                    })
                }
            }
        }
    }

    $nodes
}
