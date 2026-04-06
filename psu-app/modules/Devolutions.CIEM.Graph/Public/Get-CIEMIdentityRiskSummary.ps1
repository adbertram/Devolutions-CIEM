function Get-CIEMIdentityRiskSummary {
    <#
    .SYNOPSIS
        Returns identity risk summary data for all identities (users, SPs, managed identities, groups).
    .DESCRIPTION
        Queries graph_nodes joined with graph_edges (HasRole/InheritedRole) to produce a summary row
        per identity with entitlement counts, privileged counts, and computed risk level.
        Identity metadata (accountEnabled, daysSinceSignIn, sign-in dates) is read from node properties JSON.
        Privilege flag is read from edge properties JSON.
    .PARAMETER PrincipalType
        Filter by identity type: User, ServicePrincipal, ManagedIdentity, or Group.
    .PARAMETER RiskLevel
        Filter by computed risk level: Critical, High, Medium, or Low.
    .PARAMETER SubscriptionId
        Limit to role assignments scoped to a specific subscription.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateSet('User', 'ServicePrincipal', 'ManagedIdentity', 'Group')]
        [string]$PrincipalType,

        [Parameter()]
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [string]$RiskLevel,

        [Parameter()]
        [string]$SubscriptionId
    )

    $ErrorActionPreference = 'Stop'

    if ($null -eq $script:DormantPermissionThresholdDays) {
        throw 'Module variable $script:DormantPermissionThresholdDays is not initialized. The module may not have loaded correctly.'
    }
    if ($null -eq $script:MediumEntitlementThreshold) {
        throw 'Module variable $script:MediumEntitlementThreshold is not initialized. The module may not have loaded correctly.'
    }

    # Map PrincipalType parameter values to graph node kinds
    $principalTypeToKind = @{
        User             = 'EntraUser'
        ServicePrincipal = 'EntraServicePrincipal'
        ManagedIdentity  = 'EntraManagedIdentity'
        Group            = 'EntraGroup'
    }

    # Map node kinds back to PrincipalType output values
    $kindToPrincipalType = @{
        EntraUser             = 'User'
        EntraServicePrincipal = 'ServicePrincipal'
        EntraManagedIdentity  = 'ManagedIdentity'
        EntraGroup            = 'Group'
    }

    # Build WHERE clause for identity node kinds
    $whereClauses = @("n.kind IN ('EntraUser', 'EntraServicePrincipal', 'EntraManagedIdentity', 'EntraGroup')")
    $parameters = @{}

    if ($PrincipalType) {
        $nodeKind = $principalTypeToKind[$PrincipalType]
        $whereClauses += "n.kind = @nodeKind"
        $parameters['nodeKind'] = $nodeKind
    }

    # Build edge JOIN condition for scope filter
    $edgeJoinCondition = "e.source_id = n.id AND e.kind IN ('HasRole', 'InheritedRole')"
    if ($SubscriptionId) {
        $edgeJoinCondition += " AND json_extract(e.properties, '$.scope') LIKE '/subscriptions/' || @subId || '%'"
        $parameters['subId'] = $SubscriptionId
    }

    $whereString = $whereClauses -join ' AND '

    # Fetch per-identity rows with per-edge detail
    $sql = @"
SELECT
    n.id,
    n.kind,
    n.display_name,
    n.properties AS node_properties,
    n.collected_at,
    e.kind AS edge_kind,
    e.properties AS edge_properties
FROM graph_nodes n
LEFT JOIN graph_edges e
    ON $edgeJoinCondition
WHERE $whereString
"@

    $rows = @(Invoke-CIEMQuery -Query $sql -Parameters $parameters)

    # Group by identity and compute counts
    $grouped = $rows | Group-Object -Property id

    $results = foreach ($group in $grouped) {
        $first = $group.Group[0]

        # Read identity metadata from node properties JSON
        $nodeProps = if ($first.node_properties) {
            $first.node_properties | ConvertFrom-Json
        } else {
            [PSCustomObject]@{}
        }

        $accountEnabled = if ($null -ne $nodeProps.accountEnabled) { [bool]$nodeProps.accountEnabled } else { $true }
        $daysSinceSignIn = $nodeProps.daysSinceSignIn
        $lastSignIn = $nodeProps.lastSignIn
        $lastInteractiveSignIn = $nodeProps.lastInteractiveSignIn
        $lastNonInteractiveSignIn = $nodeProps.lastNonInteractiveSignIn
        $principalTypeValue = $kindToPrincipalType[$first.kind]

        # Count assignments using edge properties for privilege detection
        $entitlementCount = 0
        $privilegedCount = 0
        $privilegedSubScopeCount = 0
        $inheritedCount = 0

        foreach ($row in $group.Group) {
            # Skip the LEFT JOIN null row (identity with no role edges)
            if (-not $row.edge_kind) { continue }

            $entitlementCount++

            $edgeProps = if ($row.edge_properties) {
                $row.edge_properties | ConvertFrom-Json
            } else {
                [PSCustomObject]@{}
            }

            $isPrivileged = if ($null -ne $edgeProps.privileged) { [bool]$edgeProps.privileged } else { $false }
            if ($isPrivileged) {
                $privilegedCount++
                # Check subscription-level scope (not resource group)
                $scope = $edgeProps.scope
                if ($scope -match '^/subscriptions/[^/]+$') {
                    $privilegedSubScopeCount++
                }
            }

            if ($row.edge_kind -eq 'InheritedRole') {
                $inheritedCount++
            }
        }

        # Compute risk level
        $computedRiskLevel = if (($privilegedSubScopeCount -gt 0) -and ($null -eq $daysSinceSignIn -or $daysSinceSignIn -gt $script:DormantPermissionThresholdDays -or -not $accountEnabled)) {
            'Critical'
        } elseif ($privilegedSubScopeCount -gt 0 -or ($inheritedCount -gt 0 -and $privilegedCount -gt 0)) {
            'High'
        } elseif ($privilegedCount -gt 0 -or $entitlementCount -gt $script:MediumEntitlementThreshold) {
            'Medium'
        } else {
            'Low'
        }

        [PSCustomObject]@{
            Id                       = $first.id
            DisplayName              = $first.display_name
            PrincipalType            = $principalTypeValue
            AccountEnabled           = $accountEnabled
            EntitlementCount         = $entitlementCount
            PrivilegedCount          = $privilegedCount
            InheritedCount           = $inheritedCount
            LastSignIn               = $lastSignIn
            DaysSinceSignIn          = $daysSinceSignIn
            LastInteractiveSignIn    = $lastInteractiveSignIn
            LastNonInteractiveSignIn = $lastNonInteractiveSignIn
            RiskLevel                = $computedRiskLevel
        }
    }

    # Post-filter: RiskLevel is computed in PowerShell, cannot be pushed to SQL
    if ($RiskLevel) {
        $results = @($results | Where-Object { $_.RiskLevel -eq $RiskLevel })
    }

    @($results)
}
