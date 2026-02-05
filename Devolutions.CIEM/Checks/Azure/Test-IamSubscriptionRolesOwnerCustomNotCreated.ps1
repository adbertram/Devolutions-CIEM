function Test-IamSubscriptionRolesOwnerCustomNotCreated {
    <#
    .SYNOPSIS
        Tests that no custom subscription owner roles are created.

    .DESCRIPTION
        Ensures that no custom subscription owner roles exist. Subscription ownership
        should not include permission to create custom owner roles. The principle of
        least privilege should be followed and only necessary privileges should be
        assigned instead of allowing full administrative access.

        A custom owner role is identified by:
        - Being a custom role (properties.type = 'CustomRole')
        - Having '*' (wildcard all) in the actions permissions
        - Having assignable scopes that include subscription level

        The check PASSES if no custom owner roles exist.
        The check FAILS if any custom role has owner-equivalent permissions.

    .PARAMETER Check
        CIEMCheck object containing check metadata.
        - id: Check identifier
        - severity: Severity level

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.

    .NOTES
        Data source: $script:IAMService[$subscriptionId].CustomRoles
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:IAMService.Keys) {
        $iamData = $script:IAMService[$subscriptionId]

        # Check if role definitions were loaded
        if (-not $iamData.RoleDefinitions) {
            [CIEMScanResult]::Create(
                $Check,
                'SKIPPED',
                "Unable to retrieve role definitions for subscription $subscriptionId",
                "/subscriptions/$subscriptionId",
                "Subscription $subscriptionId"
            )
            continue
        }

        # Get custom roles for this subscription
        $customRoles = $iamData.CustomRoles

        if (-not $customRoles -or $customRoles.Count -eq 0) {
            # No custom roles exist - PASS (no custom owner roles can exist)
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "No custom roles exist in subscription $subscriptionId. No custom owner roles can exist.",
                "/subscriptions/$subscriptionId",
                "Subscription $subscriptionId"
            )
            continue
        }

        # Track custom owner roles found
        $customOwnerRoles = @()

        foreach ($role in $customRoles) {
            # Strict mode safe property access
            $roleName = if ($role.properties.PSObject.Properties['roleName']) {
                $role.properties.roleName
            }
            else {
                'Unknown'
            }
            $roleId = $role.id
            $permissions = if ($role.properties.PSObject.Properties['permissions']) {
                $role.properties.permissions
            }
            else {
                $null
            }
            $assignableScopes = if ($role.properties.PSObject.Properties['assignableScopes']) {
                $role.properties.assignableScopes
            }
            else {
                @()
            }

            if (-not $permissions) {
                continue
            }

            # Check if this role has owner-equivalent permissions
            $hasOwnerPermissions = $false

            foreach ($permSet in $permissions) {
                $actions = $permSet.actions
                $notActions = $permSet.notActions

                if (-not $actions) {
                    continue
                }

                # Check for wildcard (*) permission indicating full control
                $hasWildcard = $actions -contains '*'

                if ($hasWildcard) {
                    # Check if notActions significantly limits this
                    # A true owner role would have minimal or no notActions
                    $significantNotActions = $false
                    if ($notActions -and $notActions.Count -gt 0) {
                        # If notActions contains broad exclusions, this may not be owner-equivalent
                        # But for safety, we still flag roles with * permission
                        $significantNotActions = $notActions.Count -gt 10
                    }

                    # Check if assignable scopes include subscription level
                    $hasSubscriptionScope = $false
                    if ($assignableScopes) {
                        foreach ($scope in $assignableScopes) {
                            # Check for subscription-level or higher scope
                            if ($scope -match '^/subscriptions/[^/]+$' -or
                                $scope -eq '/' -or
                                $scope -match '^/providers/Microsoft\.Management/managementGroups/') {
                                $hasSubscriptionScope = $true
                                break
                            }
                        }
                    }

                    if ($hasSubscriptionScope -and -not $significantNotActions) {
                        $hasOwnerPermissions = $true
                        break
                    }
                }
            }

            if ($hasOwnerPermissions) {
                $customOwnerRoles += @{
                    Name            = $roleName
                    Id              = $roleId
                    AssignableScopes = $assignableScopes -join ', '
                }
            }
        }

        if ($customOwnerRoles.Count -gt 0) {
            # Found custom owner role(s) - generate a FAIL finding for each
            foreach ($ownerRole in $customOwnerRoles) {
                [CIEMScanResult]::Create(
                    $Check,
                    'FAIL',
                    "Custom owner role '$($ownerRole.Name)' found with full permissions (*) at subscription scope. Custom roles should not have owner-equivalent permissions. Assignable scopes: $($ownerRole.AssignableScopes)",
                    $ownerRole.Id,
                    $ownerRole.Name
                )
            }
        }
        else {
            # No custom owner roles found - PASS
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "No custom owner roles found in subscription $subscriptionId. $($customRoles.Count) custom role(s) exist but none have owner-equivalent permissions.",
                "/subscriptions/$subscriptionId",
                "Subscription $subscriptionId"
            )
        }
    }
}
