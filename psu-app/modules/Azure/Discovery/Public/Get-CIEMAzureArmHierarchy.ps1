function Get-CIEMAzureArmHierarchy {
    <#
    .SYNOPSIS
        Returns the full ARM infrastructure hierarchy as an ordered node list.
    .DESCRIPTION
        Derives the Tenant -> Subscription -> ResourceGroup -> Resource tree
        on-the-fly from azure_arm_resources rows. No new DB rows are written.
        Each node is a [PSCustomObject] with properties:
          NodeId, NodeType, Depth, ParentNodeId, Relationship, Label, Resource.
        Leaf nodes (NodeType = 'Resource') always have .Resource populated with
        the full [CIEMAzureArmResource] object. Non-leaf nodes have .Resource = $null.
        Throws a terminating error if no ARM resources exist in the database
        (typically means discovery has not been run yet).
    .PARAMETER SubscriptionId
        When specified, scopes the tree to a single subscription. Only resources
        belonging to that subscription are included.
    .EXAMPLE
        Get-CIEMAzureArmHierarchy
    .EXAMPLE
        Get-CIEMAzureArmHierarchy -SubscriptionId 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$SubscriptionId
    )

    $getParams = @{}
    if ($PSBoundParameters.ContainsKey('SubscriptionId')) {
        $getParams['SubscriptionId'] = $SubscriptionId
    }

    Write-CIEMLog -Message "HIERARCHY: querying ARM resources (SubscriptionId=$(if ($SubscriptionId) { $SubscriptionId } else { 'all' }), DB=$script:DatabasePath)" -Severity INFO -Component 'Discovery'

    $allResources = @(Get-CIEMAzureArmResource @getParams)
    Write-CIEMLog -Message "HIERARCHY: total ARM resources from DB: $($allResources.Count)" -Severity INFO -Component 'Discovery'

    # Filter to resources that can be placed in the ARM hierarchy (must have SubscriptionId).
    # Tenant-scoped resources like built-in role definitions have no subscription and can't
    # form a meaningful tree — they're still useful for CIEM checks but not for visualization.
    $resources = @($allResources | Where-Object { $_.SubscriptionId })
    Write-CIEMLog -Message "HIERARCHY: after SubscriptionId filter: $($resources.Count) (excluded $($allResources.Count - $resources.Count) tenant-scoped)" -Severity INFO -Component 'Discovery'

    if (-not $resources -or $resources.Count -eq 0) {
        throw "No ARM resources found in the database. Run Azure discovery first."
    }

    $nodes = InvokeCIEMArmHierarchyBuild -Resources $resources
    Write-CIEMLog -Message "HIERARCHY: built $($nodes.Count) tree nodes" -Severity INFO -Component 'Discovery'
    $nodes
}
