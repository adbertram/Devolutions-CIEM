function Save-ComputedResourceAccess {
    <#
    .SYNOPSIS
        Resolves identity graph edges to specific resource instances and persists the mappings.
    .DESCRIPTION
        After the identity graph is built, this function takes the computed CAN_READ/CAN_WRITE/CAN_MANAGE
        edges (which target resource TYPE categories like "type:VirtualMachine") and resolves them to
        specific resource instances by matching RBAC scopes against resource ARM IDs.

        For each identity node (users, groups, service principals):
        1. BFS-expand group memberships to find all effective identities
        2. For each effective identity, get computed permission edges (CAN_X)
        3. For each edge, look up resources of that target type
        4. Check if the edge's RBAC scopes cover each resource's ARM ID via Resolve-AzureScope
        5. If match, create a CIEMIdentityResourceAccess row

        Also resolves the role name by traversing HAS_ROLE_ASSIGNMENT → USES_ROLE edges.
    .PARAMETER Graph
        The built CIEMGraph instance.
    .PARAMETER ProviderId
        The provider ID (e.g., 'azure').
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMGraph]$Graph,

        [Parameter(Mandatory)]
        [string]$ProviderId
    )

    $ErrorActionPreference = 'Stop'

    # Clear existing computed access for this provider
    Remove-CIEMIdentityResourceAccess -ProviderId $ProviderId -Confirm:$false

    # Get distinct target types from permission_relationships
    $permRels = @(Get-CIEMPermissionRelationship)
    $targetTypes = @($permRels | ForEach-Object { $_.targetType } | Select-Object -Unique)

    if ($targetTypes.Count -eq 0) {
        Write-CIEMLog -Message "No permission relationships defined — skipping resource access computation" -Severity WARN -Component 'IdentityGraph'
        return
    }

    # Load resource instances from azure_service_data grouped by resource type
    # Map permission_relationships targetType → azure_service_data ResourceType + ServiceName
    $resourceLookup = @{}
    foreach ($targetType in $targetTypes) {
        # Look up the resource_types table for ARM provider prefix and service name
        $rtRows = @(Invoke-CIEMQuery -Query "SELECT name, service_name, arm_provider_prefix FROM resource_types WHERE name = @name AND provider = 'Azure'" -Parameters @{ name = $targetType })
        if ($rtRows.Count -eq 0) { continue }

        $rt = $rtRows[0]
        $serviceName = $rt.service_name

        # Special cases: Subscription and ResourceGroup are not stored in azure_service_data
        # They are scope-level constructs, not collected resources
        if ($targetType -in @('Subscription', 'ResourceGroup')) {
            # For subscriptions, create synthetic resources from the graph's SubscriptionIds
            if ($targetType -eq 'Subscription') {
                $resources = @($Graph.SubscriptionIds | ForEach-Object {
                    [PSCustomObject]@{
                        ResourceId   = "/subscriptions/$_"
                        ResourceName = $_
                    }
                })
            }
            elseif ($targetType -eq 'ResourceGroup') {
                # Resource groups can be extracted from collected resource ARM IDs
                $rgSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
                $allResources = @(Get-CIEMAzureServiceData -ProviderId $ProviderId)
                foreach ($r in $allResources) {
                    if ($r.ResourceId -match '^(/subscriptions/[^/]+/resourceGroups/[^/]+)') {
                        [void]$rgSet.Add($Matches[1])
                    }
                }
                $resources = @($rgSet | ForEach-Object {
                    $rgName = ($_ -split '/')[-1]
                    [PSCustomObject]@{
                        ResourceId   = $_
                        ResourceName = $rgName
                    }
                })
            }
            $resourceLookup[$targetType] = $resources
            continue
        }

        if (-not $serviceName) { continue }

        # Load resources from azure_service_data for this service
        $serviceRows = @(Get-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName $serviceName -ResourceType $targetType)
        if ($serviceRows.Count -eq 0) { continue }

        $resourceLookup[$targetType] = @($serviceRows | ForEach-Object {
            [PSCustomObject]@{
                ResourceId   = $_.ResourceId
                ResourceName = $_.ResourceName
            }
        })
    }

    if ($resourceLookup.Count -eq 0) {
        Write-CIEMLog -Message "No resource instances found for target types: $($targetTypes -join ', ')" -Severity WARN -Component 'IdentityGraph'
        return
    }

    # Collect identity node IDs
    $identityTypes = @(Get-CIEMIdentity | Where-Object { $_.PrincipalType } | ForEach-Object {
        [CIEMGraphNodeType]($_.GraphNodeType)
    } | Select-Object -Unique)

    $identityNodes = [System.Collections.Generic.List[CIEMGraphNode]]::new()
    foreach ($type in $identityTypes) {
        foreach ($node in $Graph.GetNodesByType($type)) { $identityNodes.Add($node) }
    }

    $now = (Get-Date).ToString('o')
    $rowCount = 0

    foreach ($identityNode in $identityNodes) {
        $identityId = $identityNode.Id
        $identityName = if ($identityNode.PSObject.Properties.Name -contains 'DisplayName') { $identityNode.DisplayName } else { $identityId }
        $identityType = $identityNode.NodeType.ToString() -replace '^Entra', ''

        # BFS expand group memberships
        $effectiveIdentities = [System.Collections.Generic.List[PSCustomObject]]::new()
        $effectiveIdentities.Add([PSCustomObject]@{
            Id          = $identityId
            Name        = $identityName
            IsDirect    = $true
        })

        $visited = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $queue = [System.Collections.Generic.Queue[string]]::new()
        [void]$visited.Add($identityId)

        $Graph.GetEdgesFrom($identityId) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::MEMBER_OF } | ForEach-Object {
            $queue.Enqueue($_.TargetId)
        }

        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            if (-not $visited.Add($current)) { continue }

            $groupNode = $Graph.GetNode($current)
            $groupName = if ($groupNode -and $groupNode.PSObject.Properties.Name -contains 'DisplayName') { $groupNode.DisplayName } else { $current }

            $effectiveIdentities.Add([PSCustomObject]@{
                Id          = $current
                Name        = $groupName
                IsDirect    = $false
            })

            $Graph.GetEdgesFrom($current) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::MEMBER_OF } | ForEach-Object {
                $queue.Enqueue($_.TargetId)
            }
        }

        foreach ($effective in $effectiveIdentities) {
            $effectiveId = $effective.Id
            $isDirect = $effective.IsDirect

            # Get computed permission edges from this effective identity
            $permEdges = @($Graph.GetEdgesFrom($effectiveId) | Where-Object {
                $_.Relationship -in @(
                    [CIEMGraphRelationship]::CAN_READ
                    [CIEMGraphRelationship]::CAN_WRITE
                    [CIEMGraphRelationship]::CAN_MANAGE
                )
            })

            if ($permEdges.Count -eq 0) { continue }

            # Resolve role names for this effective identity
            $roleNames = [System.Collections.Generic.List[string]]::new()
            $roleAssignmentEdges = @($Graph.GetEdgesFrom($effectiveId) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::HAS_ROLE_ASSIGNMENT })
            foreach ($raEdge in $roleAssignmentEdges) {
                $roleDefEdges = @($Graph.GetEdgesFrom($raEdge.TargetId) | Where-Object { $_.Relationship -eq [CIEMGraphRelationship]::USES_ROLE })
                foreach ($rdEdge in $roleDefEdges) {
                    $roleDef = $Graph.GetNode($rdEdge.TargetId)
                    if ($roleDef -and $roleDef.PSObject.Properties.Name -contains 'RoleName') {
                        $roleNames.Add($roleDef.RoleName)
                    }
                }
            }
            $roleNameStr = if ($roleNames.Count -gt 0) { ($roleNames | Select-Object -Unique) -join ', ' } else { $null }

            foreach ($edge in $permEdges) {
                $targetType = $edge.Properties['targetType']
                $scopes = @($edge.Properties['scopes'])

                if (-not $resourceLookup.ContainsKey($targetType)) { continue }

                $resources = $resourceLookup[$targetType]

                foreach ($resource in $resources) {
                    # Check if any scope covers this resource
                    $scopeMatch = $null
                    foreach ($scope in $scopes) {
                        if (Resolve-AzureScope -AssignmentScope $scope -TargetScope $resource.ResourceId) {
                            $scopeMatch = $scope
                            break
                        }
                    }

                    if (-not $scopeMatch) { continue }

                    $row = [CIEMIdentityResourceAccess]::new()
                    $row.ProviderId            = $ProviderId
                    $row.IdentityId            = $identityId
                    $row.IdentityName          = $identityName
                    $row.IdentityType          = $identityType
                    $row.ResourceId            = $resource.ResourceId
                    $row.ResourceName          = $resource.ResourceName
                    $row.ResourceType          = $targetType
                    $row.Relationship          = $edge.Relationship.ToString()
                    $row.Scope                 = $scopeMatch
                    $row.IsInherited           = -not $isDirect
                    $row.EffectiveIdentityId   = if (-not $isDirect) { $effectiveId } else { $null }
                    $row.EffectiveIdentityName = if (-not $isDirect) { $effective.Name } else { $null }
                    $row.RoleName              = $roleNameStr
                    $row.ComputedAt            = $now
                    $row | Save-CIEMIdentityResourceAccess
                    $rowCount++
                }
            }
        }
    }

    Write-CIEMLog -Message "Computed $rowCount identity-resource access rows for provider '$ProviderId'" -Severity INFO -Component 'IdentityGraph'
}
