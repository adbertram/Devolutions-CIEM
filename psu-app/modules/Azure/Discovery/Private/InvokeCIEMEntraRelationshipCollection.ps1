function InvokeCIEMEntraRelationshipCollection {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSObject[]]$Groups,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSObject[]]$DirectoryRoles,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSObject[]]$Users
    )

    $ErrorActionPreference = 'Stop'

    $now = (Get-Date).ToString('o')

    function NewRelationship($sourceId, $sourceType, $targetId, $targetType, $rel) {
        $ErrorActionPreference = 'Stop'
        $relationship = [CIEMAzureResourceRelationship]::new()
        $relationship.SourceId = $sourceId
        $relationship.SourceType = $sourceType
        $relationship.TargetId = $targetId
        $relationship.TargetType = $targetType
        $relationship.Relationship = $rel
        $relationship.CollectedAt = $now
        $relationship
    }

    function Get-BatchItems {
        param(
            [Parameter(Mandatory)]
            [hashtable]$BatchResults,
            [Parameter(Mandatory)]
            [string]$RequestId,
            [Parameter(Mandatory)]
            [string]$RequestLabel
        )

        $ErrorActionPreference = 'Stop'

        if (-not $BatchResults.ContainsKey($RequestId)) {
            throw "InvokeCIEMEntraRelationshipCollection missing batch response for '$RequestLabel'."
        }

        $batchResult = $BatchResults[$RequestId]
        if (-not $batchResult.Success) {
            $errorDetail = if ($batchResult.Error) { $batchResult.Error } else { "Status $($batchResult.StatusCode)" }
            throw "InvokeCIEMEntraRelationshipCollection failed for '$RequestLabel': $errorDetail"
        }

        @($batchResult.Items)
    }

    function ResolveGraphObjectType {
        param([object]$GraphObject)

        $ErrorActionPreference = 'Stop'

        if ($GraphObject.PSObject.Properties.Name -contains '@odata.type' -and $GraphObject.'@odata.type') {
            return ($GraphObject.'@odata.type' -replace '#microsoft.graph.', '')
        }

        'unknown'
    }

    $relationships = [System.Collections.Generic.List[object]]::new()
    $uniqueGroups = @($Groups | Group-Object Id | ForEach-Object { $_.Group[0] })
    $uniqueDirectoryRoles = @($DirectoryRoles | Group-Object Id | ForEach-Object { $_.Group[0] })

    if ($uniqueGroups.Count -gt 0) {
        Write-Progress -Activity 'Azure Discovery' -Status "Collecting group memberships and owners ($($uniqueGroups.Count) groups)" -PercentComplete 82

        $groupRequests = @(
            foreach ($group in $uniqueGroups) {
                @{
                    Id = "members:$($group.Id)"
                    Method = 'GET'
                    Path = "/groups/$($group.Id)/members?`$select=id"
                }
                @{
                    Id = "owners:$($group.Id)"
                    Method = 'GET'
                    Path = "/groups/$($group.Id)/owners?`$select=id"
                }
            }
        )

        $groupBatchResults = Invoke-AzureApi -Api Graph -Requests $groupRequests -ResourceName 'GroupRelationshipBatch'
        foreach ($group in $uniqueGroups) {
            foreach ($member in @(Get-BatchItems -BatchResults $groupBatchResults -RequestId "members:$($group.Id)" -RequestLabel "GroupMembers/$($group.Id)")) {
                $relationships.Add((NewRelationship $member.id (ResolveGraphObjectType -GraphObject $member) $group.Id 'group' 'member_of'))
            }

            foreach ($owner in @(Get-BatchItems -BatchResults $groupBatchResults -RequestId "owners:$($group.Id)" -RequestLabel "GroupOwners/$($group.Id)")) {
                $relationships.Add((NewRelationship $owner.id (ResolveGraphObjectType -GraphObject $owner) $group.Id 'group' 'owner_of'))
            }
        }
    }

    if ($uniqueDirectoryRoles.Count -gt 0) {
        Write-Progress -Activity 'Azure Discovery' -Status "Collecting directory role members ($($uniqueDirectoryRoles.Count) roles)" -PercentComplete 86

        $directoryRoleRequests = @(
            foreach ($role in $uniqueDirectoryRoles) {
                @{
                    Id = "directory-role-members:$($role.Id)"
                    Method = 'GET'
                    Path = "/directoryRoles/$($role.Id)/members?`$select=id"
                }
            }
        )

        $directoryRoleBatchResults = Invoke-AzureApi -Api Graph -Requests $directoryRoleRequests -ResourceName 'DirectoryRoleRelationshipBatch'
        foreach ($role in $uniqueDirectoryRoles) {
            foreach ($member in @(Get-BatchItems -BatchResults $directoryRoleBatchResults -RequestId "directory-role-members:$($role.Id)" -RequestLabel "DirectoryRoleMembers/$($role.Id)")) {
                $relationships.Add((NewRelationship $member.id (ResolveGraphObjectType -GraphObject $member) $role.Id 'directoryRole' 'has_role_member'))
            }
        }
    }

    if ($Users.Count -gt 0) {
        Write-Progress -Activity 'Azure Discovery' -Status "Building transitive memberships ($($Users.Count) users)" -PercentComplete 89
    }

    $relationships.AddRange(@(BuildCIEMEntraTransitiveMembership -Relationships @($relationships) -CollectedAt $now))
    $relationships
}
