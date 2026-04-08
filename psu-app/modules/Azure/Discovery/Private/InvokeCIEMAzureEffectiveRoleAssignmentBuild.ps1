function InvokeCIEMAzureEffectiveRoleAssignmentBuild {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ArmResources,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$EntraResources,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Relationships,

        [Parameter(Mandatory)]
        [object]$Connection,

        [Parameter(Mandatory)]
        [string]$ComputedAt
    )

    $ErrorActionPreference = 'Stop'

    # 1. Build role definition lookup: roleDefId -> { RoleName, PermissionsJson }
    $roleDefLookup = @{}
    foreach ($r in $ArmResources) {
        if ($r.Type -eq 'microsoft.authorization/roledefinitions' -and $r.Properties) {
            try { $props = $r.Properties | ConvertFrom-Json -ErrorAction Stop }
            catch { $props = $null }
            if ($props) {
                $roleDefLookup[$r.Id] = @{
                    RoleName        = $props.roleName
                    PermissionsJson = if ($props.permissions) {
                        $props.permissions | ConvertTo-Json -Depth 10 -Compress
                    } else { $null }
                }
            }
        }
    }

    # 2. Build Entra display name lookup: principalId -> displayName
    $displayNameLookup = @{}
    foreach ($e in $EntraResources) {
        if ($e.Id -and $e.DisplayName) { $displayNameLookup[$e.Id] = $e.DisplayName }
    }

    # 3. Build transitive membership lookup: groupId -> list of { Id, Type }
    #    transitive_member_of: source=leaf member, target=group
    $groupMembersLookup = @{}
    foreach ($rel in $Relationships) {
        if ($rel.Relationship -eq 'transitive_member_of') {
            $groupId = $rel.TargetId
            if (-not $groupMembersLookup.ContainsKey($groupId)) {
                $groupMembersLookup[$groupId] = [System.Collections.Generic.List[object]]::new()
            }
            $groupMembersLookup[$groupId].Add(@{
                Id   = $rel.SourceId
                Type = $rel.SourceType
            })
        }
    }

    # 4. Process role assignments — build rows list, then save all at once
    $roleAssignments = @($ArmResources | Where-Object {
        $_.Type -eq 'microsoft.authorization/roleassignments' -and $_.Properties
    })

    $rows = [System.Collections.Generic.List[CIEMAzureEffectiveRoleAssignment]]::new()

    foreach ($ra in $roleAssignments) {
        try { $props = $ra.Properties | ConvertFrom-Json -ErrorAction Stop }
        catch { continue }
        if (-not $props) { continue }

        $principalId      = $props.principalId
        $principalType    = $props.principalType
        $roleDefinitionId = $props.roleDefinitionId
        $scope            = $props.scope
        if (-not $principalId -or -not $roleDefinitionId -or -not $scope) { continue }

        $roleDef         = $roleDefLookup[$roleDefinitionId]
        $roleName        = if ($roleDef) { $roleDef.RoleName }        else { $null }
        $permissionsJson = if ($roleDef) { $roleDef.PermissionsJson } else { $null }

        if ($principalType -eq 'Group') {
            # Expand to all transitive members
            $members = $groupMembersLookup[$principalId]
            if ($members) {
                foreach ($member in $members) {
                    $row = [CIEMAzureEffectiveRoleAssignment]::new()
                    $row.PrincipalId           = $member.Id
                    $row.PrincipalType         = $member.Type
                    $row.PrincipalDisplayName  = $displayNameLookup[$member.Id]
                    $row.OriginalPrincipalId   = $principalId
                    $row.OriginalPrincipalType = 'Group'
                    $row.RoleDefinitionId      = $roleDefinitionId
                    $row.RoleName              = $roleName
                    $row.Scope                 = $scope
                    $row.PermissionsJson       = $permissionsJson
                    $row.ComputedAt            = $ComputedAt
                    $rows.Add($row)
                }
            }
            # Group self-row (direct assignment record)
            $row = [CIEMAzureEffectiveRoleAssignment]::new()
            $row.PrincipalId           = $principalId
            $row.PrincipalType         = $principalType
            $row.PrincipalDisplayName  = $displayNameLookup[$principalId]
            $row.OriginalPrincipalId   = $principalId
            $row.OriginalPrincipalType = $principalType
            $row.RoleDefinitionId      = $roleDefinitionId
            $row.RoleName              = $roleName
            $row.Scope                 = $scope
            $row.PermissionsJson       = $permissionsJson
            $row.ComputedAt            = $ComputedAt
            $rows.Add($row)
        } else {
            # Direct assignment (user, SP, managed identity)
            $row = [CIEMAzureEffectiveRoleAssignment]::new()
            $row.PrincipalId           = $principalId
            $row.PrincipalType         = $principalType
            $row.PrincipalDisplayName  = $displayNameLookup[$principalId]
            $row.OriginalPrincipalId   = $principalId
            $row.OriginalPrincipalType = $principalType
            $row.RoleDefinitionId      = $roleDefinitionId
            $row.RoleName              = $roleName
            $row.Scope                 = $scope
            $row.PermissionsJson       = $permissionsJson
            $row.ComputedAt            = $ComputedAt
            $rows.Add($row)
        }
    }

    if ($rows.Count -gt 0) {
        Save-CIEMAzureEffectiveRoleAssignment -InputObject $rows -Connection $Connection
    }

    $rows.Count
}
