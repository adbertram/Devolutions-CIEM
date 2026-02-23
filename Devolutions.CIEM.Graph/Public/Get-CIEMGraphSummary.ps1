function Get-CIEMGraphSummary {
    <#
    .SYNOPSIS
        Returns summary statistics for a CIEMGraph as plain PSCustomObjects.

    .DESCRIPTION
        Computes node counts by type, edge counts by relationship, group membership
        stats, and user group membership stats. Returns everything as PSCustomObjects
        so callers don't need access to the Graph module's classes.

    .PARAMETER Data
        The PSCustomObject from Get-PSUCache (serialized graph).

    .OUTPUTS
        [PSCustomObject] Summary with TenantId, BuildTime, NodeCounts, EdgeCounts,
        LargestGroups, and UsersInMostGroups.

    .EXAMPLE
        $graphData = Get-PSUCache -Key 'CIEM:Graph:Latest'
        $summary = Get-CIEMGraphSummary -Data $graphData
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Data
    )
    $ErrorActionPreference = 'Stop'

    # Work directly from the serialized PSCustomObject to avoid costly full deserialization
    # $Data has: TenantId, BuildTime, SubscriptionIds, Nodes (hashtable/PSCustomObject), Edges (array)

    # Get nodes as an iterable collection
    $nodeValues = if ($Data.Nodes -is [hashtable]) {
        $Data.Nodes.Values
    } else {
        $Data.Nodes.PSObject.Properties | ForEach-Object { $_.Value }
    }

    # Node counts by type
    $nodeCounts = [ordered]@{
        Users             = 0
        Groups            = 0
        ServicePrincipals = 0
        Applications      = 0
        RoleAssignments   = 0
        RoleDefinitions   = 0
    }
    # Build quick lookup structures while iterating nodes once
    $groupNodes = [System.Collections.Generic.List[object]]::new()
    $userNodes = [System.Collections.Generic.List[object]]::new()

    foreach ($node in $nodeValues) {
        $nt = [string]$node.NodeType
        switch ($nt) {
            'EntraUser'             { $nodeCounts.Users++; $userNodes.Add($node) }
            'EntraGroup'            { $nodeCounts.Groups++; $groupNodes.Add($node) }
            'EntraServicePrincipal' { $nodeCounts.ServicePrincipals++ }
            'EntraApplication'      { $nodeCounts.Applications++ }
            'AzureRoleAssignment'   { $nodeCounts.RoleAssignments++ }
            'AzureRoleDefinition'   { $nodeCounts.RoleDefinitions++ }
        }
    }

    # Edge counts by relationship type + index for group/user stats
    $edgeCounts = @{}
    $memberOfByTarget = @{}  # groupId -> count
    $memberOfBySource = @{}  # userId -> count

    foreach ($edge in $Data.Edges) {
        $rel = [string]$edge.Relationship
        if (-not $edgeCounts.ContainsKey($rel)) { $edgeCounts[$rel] = 0 }
        $edgeCounts[$rel]++

        if ($rel -eq 'MEMBER_OF') {
            $tid = [string]$edge.TargetId
            $sid = [string]$edge.SourceId
            if (-not $memberOfByTarget.ContainsKey($tid)) { $memberOfByTarget[$tid] = 0 }
            $memberOfByTarget[$tid]++
            if (-not $memberOfBySource.ContainsKey($sid)) { $memberOfBySource[$sid] = 0 }
            $memberOfBySource[$sid]++
        }
    }

    # Largest groups by member count
    $largestGroups = @($groupNodes | ForEach-Object {
        $mc = if ($memberOfByTarget.ContainsKey([string]$_.Id)) { $memberOfByTarget[[string]$_.Id] } else { 0 }
        [PSCustomObject]@{ GroupName = $_.DisplayName; MemberCount = $mc }
    } | Sort-Object -Property MemberCount -Descending | Select-Object -First 10 | Where-Object { $_.MemberCount -gt 0 })

    # Users in most groups
    $usersInMostGroups = @($userNodes | ForEach-Object {
        $gc = if ($memberOfBySource.ContainsKey([string]$_.Id)) { $memberOfBySource[[string]$_.Id] } else { 0 }
        [PSCustomObject]@{ UserName = $_.DisplayName; GroupCount = $gc }
    } | Sort-Object -Property GroupCount -Descending | Select-Object -First 10 | Where-Object { $_.GroupCount -gt 0 })

    return [PSCustomObject]@{
        TenantId          = $Data.TenantId
        BuildTime         = $Data.BuildTime
        SubscriptionIds   = $Data.SubscriptionIds
        TotalNodes        = if ($Data.Nodes -is [hashtable]) { $Data.Nodes.Count } else { @($Data.Nodes.PSObject.Properties).Count }
        TotalEdges        = @($Data.Edges).Count
        NodeCounts        = [PSCustomObject]$nodeCounts
        EdgeCounts        = $edgeCounts
        LargestGroups     = $largestGroups
        UsersInMostGroups = $usersInMostGroups
    }
}
