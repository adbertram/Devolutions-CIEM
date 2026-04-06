function Get-CIEMIdentityRiskSignals {
    <#
    .SYNOPSIS
        Returns detailed risk signals for a specific identity.
    .DESCRIPTION
        For a given principal ID, queries graph_nodes and graph_edges to return all role
        assignments, identifies inherited roles, computes risk signals (dormant permissions,
        public exposure, disabled accounts), and for managed identities resolves the hosting resource.
    .PARAMETER PrincipalId
        The identity node ID to analyze.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$PrincipalId
    )

    $ErrorActionPreference = 'Stop'

    # Get the identity from graph nodes
    $identity = @(Get-CIEMGraphNode -Id $PrincipalId)
    if ($identity.Count -eq 0) {
        throw "Identity not found: $PrincipalId"
    }
    $identity = $identity[0]

    # Parse pre-computed properties from the node's Properties JSON
    $props = $null
    if ($identity.Properties) {
        $props = $identity.Properties | ConvertFrom-Json
    }

    $accountEnabled = if ($null -ne $props -and $null -ne $props.accountEnabled) {
        [bool]$props.accountEnabled
    } else {
        $true
    }

    $daysSinceSignIn = if ($null -ne $props -and $null -ne $props.daysSinceSignIn) {
        [int]$props.daysSinceSignIn
    } else {
        $null
    }

    $lastSignIn = if ($null -ne $props -and $props.lastSignIn) {
        $props.lastSignIn
    } else {
        $null
    }

    $lastInteractiveSignIn = if ($null -ne $props -and $props.lastInteractiveSignIn) {
        $props.lastInteractiveSignIn
    } else {
        $null
    }

    $lastNonInteractiveSignIn = if ($null -ne $props -and $props.lastNonInteractiveSignIn) {
        $props.lastNonInteractiveSignIn
    } else {
        $null
    }

    $isManagedIdentity = $identity.Kind -eq 'EntraManagedIdentity'

    # Get all role assignment edges (HasRole = direct, InheritedRole = via group)
    $directRoleEdges = @(Get-CIEMGraphEdge -SourceId $PrincipalId -Kind 'HasRole')
    $inheritedRoleEdges = @(Get-CIEMGraphEdge -SourceId $PrincipalId -Kind 'InheritedRole')
    $allRoleEdges = @($directRoleEdges) + @($inheritedRoleEdges)

    # For inherited role annotation, look up group names via MemberOf edges
    $memberOfEdges = @(Get-CIEMGraphEdge -SourceId $PrincipalId -Kind 'MemberOf')
    $groupNameLookup = @{}
    foreach ($memberEdge in $memberOfEdges) {
        $groupNodes = @(Get-CIEMGraphNode -Id $memberEdge.TargetId)
        if ($groupNodes.Count -gt 0) {
            $groupNameLookup[$memberEdge.TargetId] = $groupNodes[0].DisplayName
        }
    }

    # Build role assignments from edges
    $roleAssignments = @(foreach ($edge in $allRoleEdges) {
        $edgeProps = $null
        if ($edge.Properties) {
            $edgeProps = $edge.Properties | ConvertFrom-Json
        }

        $roleName = if ($edgeProps -and $edgeProps.role_name) { $edgeProps.role_name } else { 'Unknown' }
        $isPrivileged = if ($edgeProps -and $null -ne $edgeProps.privileged) { [bool]$edgeProps.privileged } else { $false }
        $scope = if ($edgeProps -and $edgeProps.scope) { $edgeProps.scope } else { $edge.TargetId }
        $isInherited = $edge.Kind -eq 'InheritedRole'

        # For inherited roles, find the group name from the MemberOf lookup
        $inheritedFrom = $null
        if ($isInherited -and $groupNameLookup.Count -gt 0) {
            # Use the first group found (simplification: one group membership context)
            $inheritedFrom = $groupNameLookup.Values | Select-Object -First 1
        }

        [PSCustomObject]@{
            RoleName      = $roleName
            Scope         = $scope
            IsPrivileged  = $isPrivileged
            IsInherited   = $isInherited
            InheritedFrom = $inheritedFrom
        }
    })

    $inheritedRoles = @($roleAssignments | Where-Object { $_.IsInherited })

    # Compute risk signals
    $riskSignals = @()

    # 1. Dormant privileged permissions
    $hasPrivilegedRole = ($roleAssignments | Where-Object { $_.IsPrivileged }) -as [bool]
    if ($hasPrivilegedRole -and ($null -eq $daysSinceSignIn -or $daysSinceSignIn -gt $script:DormantPermissionThresholdDays)) {
        if ($null -eq $daysSinceSignIn) {
            $riskSignals += [PSCustomObject]@{
                Signal          = 'dormant-privileged-permissions'
                Severity        = 'Critical'
                Description     = 'Holds privileged role with no recorded sign-in activity'
                DaysSinceSignIn = $null
            }
        } else {
            $riskSignals += [PSCustomObject]@{
                Signal          = 'dormant-privileged-permissions'
                Severity        = 'Critical'
                Description     = "Holds privileged role with no sign-in activity for $daysSinceSignIn days"
                DaysSinceSignIn = $daysSinceSignIn
            }
        }
    }

    # 2. Group-inherited privileged role
    $inheritedPrivileged = @($inheritedRoles | Where-Object { $_.IsPrivileged })
    foreach ($ip in $inheritedPrivileged) {
        $riskSignals += [PSCustomObject]@{
            Signal      = 'group-inherited-privileged-role'
            Severity    = 'High'
            Description = "Holds $($ip.RoleName) via group '$($ip.InheritedFrom)'"
        }
    }

    # 3. Disabled account with active assignments
    if (-not $accountEnabled -and $allRoleEdges.Count -gt 0) {
        $riskSignals += [PSCustomObject]@{
            Signal      = 'disabled-with-permissions'
            Severity    = 'High'
            Description = "Account is disabled but still holds $($allRoleEdges.Count) active role assignments"
        }
    }

    # 4. Managed identity public exposure
    $hostingResource = $null
    if ($isManagedIdentity) {
        # HasManagedIdentity: source=VM, target=MI principal
        $hostEdges = @(Get-CIEMGraphEdge -TargetId $PrincipalId -Kind 'HasManagedIdentity')
        if ($hostEdges.Count -gt 0) {
            $hostNodes = @(Get-CIEMGraphNode -Id $hostEdges[0].SourceId)
            if ($hostNodes.Count -gt 0) {
                $hostNode = $hostNodes[0]

                # Check for public IP via NIC -> VM (AttachedTo) and NIC -> PublicIP (HasPublicIP)
                $nicEdges = @(Get-CIEMGraphEdge -TargetId $hostNode.Id -Kind 'AttachedTo')
                $hasPublicIP = $false
                foreach ($nicEdge in $nicEdges) {
                    if (@(Get-CIEMGraphEdge -SourceId $nicEdge.SourceId -Kind 'HasPublicIP').Count -gt 0) {
                        $hasPublicIP = $true
                        break
                    }
                }

                $hostingResource = [PSCustomObject]@{
                    Id            = $hostNode.Id
                    Name          = $hostNode.DisplayName
                    Type          = $hostNode.Kind
                    ResourceGroup = $hostNode.ResourceGroup
                    HasPublicIP   = $hasPublicIP
                }

                if ($hasPublicIP) {
                    $riskSignals += [PSCustomObject]@{
                        Signal      = 'managed-identity-public-exposure'
                        Severity    = 'Critical'
                        Description = "Managed identity on $($hostNode.DisplayName) with public IP address"
                    }
                }
            }
        }
    }

    [PSCustomObject]@{
        Identity        = [PSCustomObject]@{
            Id                       = $identity.Id
            DisplayName              = $identity.DisplayName
            Type                     = $identity.Kind
            AccountEnabled           = $accountEnabled
            LastSignIn               = $lastSignIn
            LastInteractiveSignIn    = $lastInteractiveSignIn
            LastNonInteractiveSignIn = $lastNonInteractiveSignIn
        }
        RoleAssignments = $roleAssignments
        RiskSignals     = $riskSignals
        InheritedRoles  = $inheritedRoles
        HostingResource = $hostingResource
    }
}
