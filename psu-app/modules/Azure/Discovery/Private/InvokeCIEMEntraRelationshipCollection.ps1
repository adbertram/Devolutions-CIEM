function InvokeCIEMEntraRelationshipCollection {
    param(
        [Parameter(Mandatory)]
        [PSObject[]]$Groups,
        [Parameter(Mandatory)]
        [PSObject[]]$DirectoryRoles,
        [Parameter(Mandatory)]
        [PSObject[]]$Users
    )

    $now = (Get-Date).ToString('o')

    function NewRelationship($sourceId, $sourceType, $targetId, $targetType, $rel) {
        $r = [CIEMAzureResourceRelationship]::new()
        $r.SourceId     = $sourceId
        $r.SourceType   = $sourceType
        $r.TargetId     = $targetId
        $r.TargetType   = $targetType
        $r.Relationship = $rel
        $r.CollectedAt  = $now
        $r
    }

    # Group members + owners
    $totalGroups = $Groups.Count
    $groupIndex = 0
    foreach ($group in $Groups) {
        $groupIndex++
        Write-Progress -Activity 'Azure Discovery' -Status "Collecting group memberships ($groupIndex/$totalGroups)" -PercentComplete (80 + [math]::Floor(4 * $groupIndex / [math]::Max($totalGroups, 1))) -CurrentOperation $group.DisplayName
        $members = @(Invoke-AzureApi -Api Graph -Path "/groups/$($group.Id)/members?`$select=id" -ResourceName "GroupMembers/$($group.Id)")
        foreach ($m in $members) {
            $mType = if ($m.'@odata.type') { ($m.'@odata.type' -replace '#microsoft.graph.', '') } else { 'unknown' }
            NewRelationship $m.id $mType $group.Id 'group' 'member_of'
        }

        $owners = @(Invoke-AzureApi -Api Graph -Path "/groups/$($group.Id)/owners?`$select=id" -ResourceName "GroupOwners/$($group.Id)")
        foreach ($o in $owners) {
            $oType = if ($o.'@odata.type') { ($o.'@odata.type' -replace '#microsoft.graph.', '') } else { 'unknown' }
            NewRelationship $o.id $oType $group.Id 'group' 'owner_of'
        }
    }

    # Directory role members
    $totalRoles = $DirectoryRoles.Count
    $roleIndex = 0
    foreach ($role in $DirectoryRoles) {
        $roleIndex++
        Write-Progress -Activity 'Azure Discovery' -Status "Collecting directory role members ($roleIndex/$totalRoles)" -PercentComplete (84 + [math]::Floor(3 * $roleIndex / [math]::Max($totalRoles, 1))) -CurrentOperation $role.DisplayName
        $members = @(Invoke-AzureApi -Api Graph -Path "/directoryRoles/$($role.Id)/members?`$select=id" -ResourceName "DirectoryRoleMembers/$($role.Id)")
        foreach ($m in $members) {
            $mType = if ($m.'@odata.type') { ($m.'@odata.type' -replace '#microsoft.graph.', '') } else { 'unknown' }
            NewRelationship $m.id $mType $role.Id 'directoryRole' 'has_role_member'
        }
    }

    # User transitive group membership
    $totalUsers = $Users.Count
    $userIndex = 0
    foreach ($user in $Users) {
        $userIndex++
        Write-Progress -Activity 'Azure Discovery' -Status "Collecting user transitive memberships ($userIndex/$totalUsers)" -PercentComplete (87 + [math]::Floor(3 * $userIndex / [math]::Max($totalUsers, 1))) -CurrentOperation $user.DisplayName
        $transitiveGroups = @(Invoke-AzureApi -Api Graph -Path "/users/$($user.Id)/transitiveMemberOf?`$select=id" -ResourceName "TransitiveMemberOf/$($user.Id)")
        foreach ($g in $transitiveGroups) {
            $gType = if ($g.'@odata.type') { ($g.'@odata.type' -replace '#microsoft.graph.', '') } else { 'group' }
            NewRelationship $user.Id 'user' $g.id $gType 'transitive_member_of'
        }
    }
}
