function BuildCIEMEntraTransitiveMembership {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Relationships,

        [Parameter(Mandatory)]
        [string]$CollectedAt
    )

    $directMemberships = @($Relationships | Where-Object {
        $_.Relationship -eq 'member_of' -and $_.TargetType -eq 'group'
    })
    if ($directMemberships.Count -eq 0) {
        return @()
    }

    $groupParents = @{}
    foreach ($relationship in $directMemberships) {
        if ($relationship.SourceType -ne 'group') {
            continue
        }

        if (-not $groupParents.ContainsKey($relationship.SourceId)) {
            $groupParents[$relationship.SourceId] = [System.Collections.Generic.HashSet[string]]::new()
        }

        $null = $groupParents[$relationship.SourceId].Add($relationship.TargetId)
    }

    # Use [List[object]] instead of [List[CIEMAzureResourceRelationship]] — module
    # classes get a fresh assembly per Import-Module. PSU's multi-load runspace will
    # accumulate versions, causing [List[CIEMType v_X]] to reject items from [CIEMType v_Y].
    $results = [System.Collections.Generic.List[object]]::new()
    $seenPairs = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($relationship in $directMemberships) {
        $visitedGroups = [System.Collections.Generic.HashSet[string]]::new()
        $queue = [System.Collections.Generic.Queue[string]]::new()
        $queue.Enqueue($relationship.TargetId)

        while ($queue.Count -gt 0) {
            $groupId = $queue.Dequeue()
            if (-not $visitedGroups.Add($groupId)) {
                continue
            }

            $pairKey = "$($relationship.SourceId)|$groupId"
            if ($seenPairs.Add($pairKey)) {
                $transitiveRelationship = [CIEMAzureResourceRelationship]::new()
                $transitiveRelationship.SourceId = $relationship.SourceId
                $transitiveRelationship.SourceType = $relationship.SourceType
                $transitiveRelationship.TargetId = $groupId
                $transitiveRelationship.TargetType = 'group'
                $transitiveRelationship.Relationship = 'transitive_member_of'
                $transitiveRelationship.CollectedAt = $CollectedAt
                $results.Add($transitiveRelationship)
            }

            if ($groupParents.ContainsKey($groupId)) {
                foreach ($parentGroupId in $groupParents[$groupId]) {
                    $queue.Enqueue($parentGroupId)
                }
            }
        }
    }

    $results
}
