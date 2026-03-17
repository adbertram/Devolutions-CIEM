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

    $nodes = [System.Collections.Generic.List[PSObject]]::new()

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
            Label        = $tenantId
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
                Label        = $subId
                Resource     = $null
            })

            # Level 2: Resource groups within this subscription
            $byResourceGroup = $subGroup.Group | Group-Object -Property ResourceGroup

            foreach ($rgGroup in $byResourceGroup) {
                $rgName    = $rgGroup.Name
                $rgNodeId  = "resourcegroup:$subId|$rgName"
                $nodes.Add([PSCustomObject]@{
                    NodeId       = $rgNodeId
                    NodeType     = 'ResourceGroup'
                    Depth        = 2
                    ParentNodeId = $subNodeId
                    Relationship = 'CONTAINS'
                    Label        = $rgName
                    Resource     = $null
                })

                # Level 3: Actual resources within this resource group
                foreach ($resource in $rgGroup.Group) {
                    $nodes.Add([PSCustomObject]@{
                        NodeId       = "resource:$($resource.Id)"
                        NodeType     = 'Resource'
                        Depth        = 3
                        ParentNodeId = $rgNodeId
                        Relationship = 'CONTAINS'
                        Label        = $resource.Name
                        Resource     = $resource
                    })
                }
            }
        }
    }

    $nodes
}
