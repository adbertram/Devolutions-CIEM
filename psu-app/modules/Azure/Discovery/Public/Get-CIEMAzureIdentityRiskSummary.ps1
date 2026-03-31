function Get-CIEMAzureIdentityRiskSummary {
    <#
    .SYNOPSIS
        Returns identity risk summary data for all identities (users, SPs, managed identities, groups).
    .DESCRIPTION
        Queries azure_entra_resources joined with azure_effective_role_assignments to produce
        a summary row per identity with entitlement counts, privileged counts, and computed risk level.
        Uses TestCIEMAzurePrivilegedRole to determine privilege based on role name and permissions.
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

    # Build WHERE clause based on PrincipalType filter
    $whereClauses = @("e.type IN ('user', 'servicePrincipal', 'group')")
    $parameters = @{}

    if ($PrincipalType) {
        switch ($PrincipalType) {
            'User' {
                $whereClauses += "e.type = 'user'"
            }
            'ServicePrincipal' {
                $whereClauses += "e.type = 'servicePrincipal'"
                $whereClauses += "COALESCE(json_extract(e.properties, '$.servicePrincipalType'), '') <> 'ManagedIdentity'"
            }
            'ManagedIdentity' {
                $whereClauses += "e.type = 'servicePrincipal'"
                $whereClauses += "json_extract(e.properties, '$.servicePrincipalType') = 'ManagedIdentity'"
            }
            'Group' {
                $whereClauses += "e.type = 'group'"
            }
        }
    }

    # Build scope filter for SubscriptionId
    $scopeJoinCondition = 'era.principal_id = e.id'
    if ($SubscriptionId) {
        $scopeJoinCondition += " AND era.scope LIKE '/subscriptions/' || @subId || '%'"
        $parameters['subId'] = $SubscriptionId
    }

    $whereString = $whereClauses -join ' AND '

    # Fetch per-identity rows with per-assignment detail for privilege evaluation
    $sql = @"
SELECT
    e.id,
    e.type,
    e.display_name,
    e.properties,
    era.role_name,
    era.permissions_json,
    era.scope AS era_scope,
    era.original_principal_id,
    era.principal_id AS era_principal_id
FROM azure_entra_resources e
LEFT JOIN azure_effective_role_assignments era
    ON $scopeJoinCondition
WHERE $whereString
"@

    $rows = @(Invoke-CIEMQuery -Query $sql -Parameters $parameters)

    # Group by identity and compute counts using TestCIEMAzurePrivilegedRole
    $grouped = $rows | Group-Object -Property id

    $results = foreach ($group in $grouped) {
        $first = $group.Group[0]

        $parsed = ParseCIEMIdentityProperties -PropertiesJson $first.properties -EntraType $first.type
        $accountEnabled    = $parsed.AccountEnabled
        $daysSinceSignIn   = $parsed.DaysSinceSignIn
        $principalTypeValue = $parsed.PrincipalType

        # Count assignments using the helper for privilege detection
        $entitlementCount = 0
        $privilegedCount = 0
        $privilegedSubScopeCount = 0
        $inheritedCount = 0

        foreach ($assignment in $group.Group) {
            # Skip the LEFT JOIN null row (identity with no assignments)
            if (-not $assignment.role_name) { continue }

            $entitlementCount++

            $isPrivileged = TestCIEMAzurePrivilegedRole -RoleName $assignment.role_name -PermissionsJson $assignment.permissions_json
            if ($isPrivileged) {
                $privilegedCount++
                # Check subscription-level scope (not resource group)
                $scope = $assignment.era_scope
                if ($scope -match '^/subscriptions/[^/]+$') {
                    $privilegedSubScopeCount++
                }
            }

            if ($assignment.original_principal_id -ne $assignment.era_principal_id) {
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
            LastSignIn               = $parsed.LastSignIn
            DaysSinceSignIn          = $daysSinceSignIn
            LastInteractiveSignIn    = $parsed.LastInteractiveSignIn
            LastNonInteractiveSignIn = $parsed.LastNonInteractiveSignIn
            RiskLevel                = $computedRiskLevel
        }
    }

    # Post-filter: RiskLevel is computed in PowerShell, cannot be pushed to SQL
    # Full result set must be fetched first, then filtered here
    if ($RiskLevel) {
        $results = @($results | Where-Object { $_.RiskLevel -eq $RiskLevel })
    }

    @($results)
}
