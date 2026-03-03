function Test-EntraPrivilegedUserHasMfa {
    <#
    .SYNOPSIS
        Tests if all privileged users have MFA enabled.

    .DESCRIPTION
        This check verifies that users who are assigned to directory roles
        (privileged users) have MFA registered. This includes users in roles such as
        Global Administrator, User Access Administrator, Subscription Owner, etc.

        MFA provides additional security by requiring a second form of authentication,
        which is especially critical for users with elevated privileges.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraPrivilegedUserHasMfa -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData

    # Check if required data is available
    if (-not $svc.DirectoryRoles) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve directory roles - missing permissions',
            'N/A',
            'Directory Roles'
        )
    }
    elseif (-not $svc.UserMFAStatus) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve user MFA registration details - Azure AD Premium P1/P2 license required',
            'N/A',
            'User MFA Status'
        )
    }
    else {
        # Build a set of privileged users (users in any directory role)
        $privilegedUsers = @{}
        $userRoles = @{}

        if ($svc.DirectoryRoleMembers) {
            foreach ($role in $svc.DirectoryRoles) {
                $roleId = $role.id
                $roleName = $role.displayName
                $members = $svc.DirectoryRoleMembers[$roleId]

                if ($members) {
                    foreach ($member in $members) {
                        if ($member.id -and -not $privilegedUsers.ContainsKey($member.id)) {
                            $privilegedUsers[$member.id] = $member
                            $userRoles[$member.id] = @()
                        }
                        if ($member.id) {
                            $userRoles[$member.id] += $roleName
                        }
                    }
                }
            }
        }

        if ($privilegedUsers.Count -eq 0) {
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                'No privileged users found in directory roles',
                'privileged-users',
                'Privileged Users'
            )
        }
        else {
            # Build MFA status lookup
            $mfaStatusLookup = @{}
            foreach ($mfaStatus in $svc.UserMFAStatus) {
                $mfaStatusLookup[$mfaStatus.id] = $mfaStatus
            }

            # Check each privileged user for MFA
            $usersWithoutMfa = @()
            $usersWithMfa = @()

            foreach ($userId in $privilegedUsers.Keys) {
                $user = $privilegedUsers[$userId]
                $mfaStatus = $mfaStatusLookup[$userId]

                # Check if user has MFA methods registered
                $hasMfa = $false
                if ($mfaStatus) {
                    # Check isMfaRegistered property or methodsRegistered array
                    if ($mfaStatus.isMfaRegistered -eq $true) {
                        $hasMfa = $true
                    }
                    elseif ($mfaStatus.methodsRegistered -and $mfaStatus.methodsRegistered.Count -gt 0) {
                        # Check for actual MFA methods (not just password)
                        $mfaMethods = $mfaStatus.methodsRegistered | Where-Object { $_ -ne 'password' }
                        if ($mfaMethods.Count -gt 0) {
                            $hasMfa = $true
                        }
                    }
                }

                if ($hasMfa) {
                    $usersWithMfa += @{
                        User  = $user
                        Roles = $userRoles[$userId]
                    }
                }
                else {
                    $usersWithoutMfa += @{
                        User  = $user
                        Roles = $userRoles[$userId]
                    }
                }
            }

            $totalPrivileged = $privilegedUsers.Count
            $withoutMfaCount = $usersWithoutMfa.Count

            if ($withoutMfaCount -eq 0) {
                [CIEMScanResult]::Create(
                    $Check,
                    'PASS',
                    "All $totalPrivileged privileged users have MFA enabled",
                    'privileged-users',
                    'Privileged Users'
                )
            }
            else {
                # Report individual users without MFA
                foreach ($item in $usersWithoutMfa) {
                    $user = $item.User
                    $roles = $item.Roles -join ', '
                    [CIEMScanResult]::Create(
                        $Check,
                        'FAIL',
                        "Privileged user '$($user.displayName)' ($($user.userPrincipalName)) does not have MFA enabled. Assigned roles: $roles",
                        $user.id,
                        $user.displayName
                    )
                }
            }
        }
    }
}
