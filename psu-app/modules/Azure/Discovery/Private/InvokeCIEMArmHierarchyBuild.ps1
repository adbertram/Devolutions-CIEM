function ResolveArmResourceLabel($resource, $roleDefLookup, $principalLookup, $parsedProps) {
    $ErrorActionPreference = 'Stop'

    $props = $parsedProps[$resource.Id]
    if ($props) {
        if ($resource.Type -eq 'microsoft.authorization/roledefinitions' -and $props.roleName) {
            return $props.roleName
        }
        if ($resource.Type -eq 'microsoft.authorization/roleassignments') {
            $pid = $props.principalId
            $principalName = if ($pid) { $principalLookup[$pid] } else { $null }
            if (-not $principalName) {
                $principalName = if ($pid -and $pid.Length -gt 8) { $pid.Substring(0, 8) } else { $pid ?? 'Unknown' }
            }
            return $principalName
        }
    }
    return $resource.Name
}

function InvokeCIEMArmHierarchyBuild {
    <#
    .SYNOPSIS
        Builds a flat ordered node list representing the ARM hierarchy tree.
        Returns [PSCustomObject[]] with NodeId, NodeType, Depth, ParentNodeId,
        Relationship, Label, Resource properties.
    .NOTES
        Private helper for Get-CIEMAzureArmHierarchy.
        The ARM hierarchy is a fixed 4-level tree: Tenant -> Subscription ->
        ResourceGroup -> Resource. No BFS needed — three Group-Object passes
        derive all levels from the flat resource array.
    #>
    param(
        [Parameter(Mandatory)]
        [object[]]$Resources
    )

    $ErrorActionPreference = 'Stop'

    $nodes = [System.Collections.Generic.List[PSObject]]::new()

    # Build subscription ID → friendly name lookup from ResourceContainers data
    $subNameLookup = @{}
    foreach ($r in $Resources) {
        if ($r.Type -eq 'microsoft.resources/subscriptions' -and $r.SubscriptionId -and $r.Name) {
            $subNameLookup[$r.SubscriptionId] = $r.Name
        }
    }

    # Build role definition ID → roleName lookup from ALL role definitions in DB
    # (role defs are tenant-scoped with no subscription_id, so they're not in $Resources)
    $roleDefLookup = @{}
    try {
        $roleDefRows = @(Invoke-CIEMQuery -Query "SELECT id, json_extract(properties, '$.roleName') as role_name FROM azure_arm_resources WHERE type = 'microsoft.authorization/roledefinitions' AND properties IS NOT NULL")
        foreach ($row in $roleDefRows) {
            if ($row.id -and $row.role_name) { $roleDefLookup[$row.id] = $row.role_name }
        }
    } catch {
        Write-CIEMLog -Message "HIERARCHY: Failed to build role definition lookup: $_" -Severity WARNING -Component 'Discovery'
    }

    # Build principal ID → displayName lookup from Entra resources
    $principalLookup = @{}
    try {
        $entraResources = @(Get-CIEMAzureEntraResource)
        foreach ($e in $entraResources) {
            if ($e.Id -and $e.DisplayName) { $principalLookup[$e.Id] = $e.DisplayName }
        }
    } catch {
        Write-CIEMLog -Message "HIERARCHY: Failed to build principal lookup: $_" -Severity WARNING -Component 'Discovery'
    }

    $textInfo = (Get-Culture).TextInfo

    # Pre-parse all Properties JSON once (avoids repeated ConvertFrom-Json in grouping + label resolution)
    $parsedProps = @{}
    foreach ($r in $Resources) {
        if ($r.Properties) {
            $parsedProps[$r.Id] = $r.Properties | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
    }

    # Derive unique tenant IDs (fall back to 'unknown' if column is empty)
    $tenantIds = @($Resources | Where-Object { $_.TenantId } |
                   Select-Object -ExpandProperty TenantId -Unique)
    if (-not $tenantIds) { $tenantIds = @('unknown') }

    foreach ($tenantId in $tenantIds) {
        $tenantNodeId = "tenant:$tenantId"
        $nodes.Add([PSCustomObject]@{
            NodeId       = $tenantNodeId
            NodeType     = 'Tenant'
            Depth        = 0
            ParentNodeId = $null
            Relationship = $null
            Label        = 'Tenant'
            Resource     = $null
        })

        # Level 1: Subscriptions within this tenant
        $tenantResources = @($Resources | Where-Object {
            -not $_.TenantId -or $_.TenantId -eq $tenantId
        })

        $bySubscription = $tenantResources | Group-Object -Property SubscriptionId

        foreach ($subGroup in $bySubscription) {
            $subId     = $subGroup.Name
            $subNodeId = "subscription:$subId"
            $nodes.Add([PSCustomObject]@{
                NodeId       = $subNodeId
                NodeType     = 'Subscription'
                Depth        = 1
                ParentNodeId = $tenantNodeId
                Relationship = 'CONTAINS'
                Label        = if ($subNameLookup[$subId]) { $subNameLookup[$subId] } else { $subId }
                Resource     = $null
            })

            # Split resources into those with a resource group and subscription-level resources
            $rgResources  = @($subGroup.Group | Where-Object { $_.ResourceGroup })
            $subResources = @($subGroup.Group | Where-Object { -not $_.ResourceGroup })

            # Branch 1: Resource Groups (category container → individual RGs → resources)
            if ($rgResources) {
                $byResourceGroup = $rgResources | Group-Object -Property ResourceGroup
                $rgCategoryNodeId = "category:$subId|ResourceGroups"
                $nodes.Add([PSCustomObject]@{
                    NodeId       = $rgCategoryNodeId
                    NodeType     = 'Category'
                    Depth        = 2
                    ParentNodeId = $subNodeId
                    Relationship = 'CONTAINS'
                    Label        = "Resource Groups ($($byResourceGroup.Count))"
                    Resource     = $null
                })

                foreach ($rgGroup in $byResourceGroup) {
                    $rgName    = $rgGroup.Name
                    $rgNodeId  = "resourcegroup:$subId|$rgName"
                    $nodes.Add([PSCustomObject]@{
                        NodeId       = $rgNodeId
                        NodeType     = 'ResourceGroup'
                        Depth        = 3
                        ParentNodeId = $rgCategoryNodeId
                        Relationship = 'CONTAINS'
                        Label        = $rgName
                        Resource     = $null
                    })

                    # Group resources within RG by type
                    $byType = $rgGroup.Group | Group-Object -Property Type

                    foreach ($typeGroup in $byType) {
                        # Extract short type name (e.g., "microsoft.keyvault/vaults" → "Vaults")
                        $shortType = ($typeGroup.Name -split '/')[-1]
                        $shortType = [regex]::Replace($shortType, '([a-z])([A-Z])', '$1 $2')
                        $shortType = $textInfo.ToTitleCase($shortType)

                        $typeNodeId = "category:$subId|$rgName|$($typeGroup.Name)"
                        $nodes.Add([PSCustomObject]@{
                            NodeId       = $typeNodeId
                            NodeType     = 'Category'
                            Depth        = 4
                            ParentNodeId = $rgNodeId
                            Relationship = 'CONTAINS'
                            Label        = "$shortType ($($typeGroup.Count))"
                            Resource     = $null
                            ResourceType = $typeGroup.Name
                        })

                        foreach ($resource in $typeGroup.Group) {
                            $resLabel = ResolveArmResourceLabel $resource $roleDefLookup $principalLookup $parsedProps
                            $nodes.Add([PSCustomObject]@{
                                NodeId       = "resource:$($resource.Id)"
                                NodeType     = 'Resource'
                                Depth        = 5
                                ParentNodeId = $typeNodeId
                                Relationship = 'CONTAINS'
                                Label        = $resLabel
                                Resource     = $resource
                            })
                        }
                    }
                }
            }

            # Branch 2: Role Definitions
            $roleDefResources = @($subResources | Where-Object { $_.Type -eq 'Microsoft.Authorization/roleDefinitions' })
            if ($roleDefResources) {
                $roleDefNodeId = "category:$subId|roleDefinitions"
                $nodes.Add([PSCustomObject]@{
                    NodeId       = $roleDefNodeId
                    NodeType     = 'Category'
                    Depth        = 2
                    ParentNodeId = $subNodeId
                    Relationship = 'CONTAINS'
                    Label        = "Role Definitions ($($roleDefResources.Count))"
                    Resource     = $null
                })
                foreach ($resource in $roleDefResources) {
                    $resLabel = ResolveArmResourceLabel $resource $roleDefLookup $principalLookup $parsedProps
                    $nodes.Add([PSCustomObject]@{
                        NodeId       = "resource:$($resource.Id)"
                        NodeType     = 'Resource'
                        Depth        = 3
                        ParentNodeId = $roleDefNodeId
                        Relationship = 'CONTAINS'
                        Label        = $resLabel
                        Resource     = $resource
                    })
                }
            }

            # Branch 3: Role Assignments — grouped by principalType
            $roleAssignResources = @($subResources | Where-Object { $_.Type -eq 'Microsoft.Authorization/roleAssignments' })
            if ($roleAssignResources) {
                $roleAssignNodeId = "category:$subId|roleAssignments"
                $nodes.Add([PSCustomObject]@{
                    NodeId       = $roleAssignNodeId
                    NodeType     = 'Category'
                    Depth        = 2
                    ParentNodeId = $subNodeId
                    Relationship = 'CONTAINS'
                    Label        = "Role Assignments ($($roleAssignResources.Count))"
                    Resource     = $null
                })

                # Group by principalType from properties
                $byPrincipalType = $roleAssignResources | Group-Object -Property {
                    $p = $parsedProps[$_.Id]
                    if ($p) { $p.principalType ?? 'Unknown' } else { 'Unknown' }
                }

                foreach ($ptGroup in $byPrincipalType) {
                    $ptName = $ptGroup.Name
                    $ptNodeId = "category:$subId|roleAssignments|$ptName"
                    $nodes.Add([PSCustomObject]@{
                        NodeId       = $ptNodeId
                        NodeType     = 'Category'
                        Depth        = 3
                        ParentNodeId = $roleAssignNodeId
                        Relationship = 'CONTAINS'
                        Label        = "$ptName ($($ptGroup.Count))"
                        Resource     = $null
                    })

                    # Sub-group by role name
                    $byRole = $ptGroup.Group | Group-Object -Property {
                        $p = $parsedProps[$_.Id]
                        if ($p) { $roleDefLookup[$p.roleDefinitionId] ?? 'Unknown Role' } else { 'Unknown Role' }
                    }

                    foreach ($roleGroup in $byRole) {
                        $roleName = $roleGroup.Name
                        $roleNodeId = "category:$subId|roleAssignments|$ptName|$roleName"
                        $nodes.Add([PSCustomObject]@{
                            NodeId       = $roleNodeId
                            NodeType     = 'Category'
                            Depth        = 4
                            ParentNodeId = $ptNodeId
                            Relationship = 'CONTAINS'
                            Label        = "$roleName ($($roleGroup.Count))"
                            Resource     = $null
                        })

                        foreach ($resource in $roleGroup.Group) {
                            $resLabel = ResolveArmResourceLabel $resource $roleDefLookup $principalLookup $parsedProps
                            $nodes.Add([PSCustomObject]@{
                                NodeId       = "resource:$($resource.Id)"
                                NodeType     = 'Resource'
                                Depth        = 5
                                ParentNodeId = $roleNodeId
                                Relationship = 'CONTAINS'
                                Label        = $resLabel
                                Resource     = $resource
                            })
                        }
                    }
                }
            }
        }
    }

    $nodes
}
