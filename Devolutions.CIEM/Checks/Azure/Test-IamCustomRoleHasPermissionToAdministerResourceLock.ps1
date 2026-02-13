function Test-IamCustomRoleHasPermissionToAdministerResourceLock {
    <#
    .SYNOPSIS
        Tests if a custom role has permissions to administer resource locks.

    .DESCRIPTION
        Ensures a Custom Role is Assigned Permissions for Administering Resource Locks.
        Resource locks administration is a critical task that should be performed from
        a custom role with the appropriate permissions.

        This check examines custom roles for permissions like:
        - Microsoft.Authorization/locks/*
        - Microsoft.Authorization/locks/delete
        - Microsoft.Authorization/locks/write

        The check PASSES if a custom role exists with lock administration permissions
        (ensuring proper delegation exists).
        The check FAILS if no custom role has these permissions (indicating resource
        lock administration is not properly delegated).

    .PARAMETER Check
        CIEMCheck object containing check metadata.
        - id: Check identifier
        - severity: Severity level

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.

    .NOTES
        Data source: $svc[$subscriptionId].CustomRoles
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'IAM' }).CacheData

    # Lock-related permissions to check for
    $lockPermissions = @(
        'Microsoft.Authorization/locks/*',
        'Microsoft.Authorization/locks/delete',
        'Microsoft.Authorization/locks/write',
        '*/locks/*',
        '*/locks/delete',
        '*/locks/write'
    )

    foreach ($subscriptionId in $svc.Keys) {
        $iamData = $svc[$subscriptionId]

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
            # No custom roles exist - this is a FAIL condition
            # The recommendation is to have a dedicated custom role for lock administration
            [CIEMScanResult]::Create(
                $Check,
                'FAIL',
                "No custom roles exist in subscription $subscriptionId. A dedicated custom role should be created for resource lock administration.",
                "/subscriptions/$subscriptionId",
                "Subscription $subscriptionId"
            )
            continue
        }

        # Track if we found any custom role with lock permissions
        $foundLockAdminRole = $false
        $lockAdminRoles = @()

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

            if (-not $permissions) {
                continue
            }

            # Check each permission set for lock-related actions
            foreach ($permSet in $permissions) {
                $actions = $permSet.actions
                if (-not $actions) {
                    continue
                }

                # Check if any lock permission is present
                $hasLockPermission = $false
                foreach ($action in $actions) {
                    # Check for exact matches or wildcard patterns
                    foreach ($lockPerm in $lockPermissions) {
                        if ($action -eq $lockPerm) {
                            $hasLockPermission = $true
                            break
                        }
                        # Check for wildcard match (e.g., * matches everything)
                        if ($action -eq '*') {
                            $hasLockPermission = $true
                            break
                        }
                        # Check for partial wildcard match
                        if ($lockPerm -like "$action*" -or $action -like "$lockPerm*") {
                            $hasLockPermission = $true
                            break
                        }
                    }
                    if ($hasLockPermission) {
                        break
                    }
                }

                if ($hasLockPermission) {
                    $foundLockAdminRole = $true
                    $lockAdminRoles += @{
                        Name = $roleName
                        Id   = $roleId
                    }
                    break
                }
            }
        }

        if ($foundLockAdminRole) {
            # Found custom role(s) with lock permissions - PASS
            $roleNames = ($lockAdminRoles | ForEach-Object { $_.Name }) -join ', '
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "Custom role(s) with resource lock administration permissions found in subscription $subscriptionId`: $roleNames",
                "/subscriptions/$subscriptionId",
                "Subscription $subscriptionId"
            )
        }
        else {
            # No custom role has lock permissions - FAIL
            [CIEMScanResult]::Create(
                $Check,
                'FAIL',
                "No custom role with resource lock administration permissions found in subscription $subscriptionId. Custom roles exist ($($customRoles.Count)) but none have Microsoft.Authorization/locks/* permissions.",
                "/subscriptions/$subscriptionId",
                "Subscription $subscriptionId"
            )
        }
    }
}
