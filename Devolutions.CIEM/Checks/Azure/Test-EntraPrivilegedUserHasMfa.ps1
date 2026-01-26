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

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPrivilegedUserHasMfa -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # Check if required data is available
    if (-not $script:EntraService.DirectoryRoles) {
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve directory roles - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'Directory Roles'
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
    }
    elseif (-not $script:EntraService.UserMFAStatus) {
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve user MFA registration details - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'User MFA Status'
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
    }
    else {
        # Build a set of privileged users (users in any directory role)
        $privilegedUsers = @{}
        $userRoles = @{}

        if ($script:EntraService.DirectoryRoleMembers) {
            foreach ($role in $script:EntraService.DirectoryRoles) {
                $roleId = $role.id
                $roleName = $role.displayName
                $members = $script:EntraService.DirectoryRoleMembers[$roleId]

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
            [PSCustomObject]@{
                CheckId        = $CheckMetadata.id
                Status         = 'PASS'
                StatusExtended = 'No privileged users found in directory roles'
                ResourceId     = 'privileged-users'
                ResourceName   = 'Privileged Users'
                Location       = 'Global'
                Severity       = $CheckMetadata.severity
            }
        }
        else {
            # Build MFA status lookup
            $mfaStatusLookup = @{}
            foreach ($mfaStatus in $script:EntraService.UserMFAStatus) {
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
                [PSCustomObject]@{
                    CheckId        = $CheckMetadata.id
                    Status         = 'PASS'
                    StatusExtended = "All $totalPrivileged privileged users have MFA enabled"
                    ResourceId     = 'privileged-users'
                    ResourceName   = 'Privileged Users'
                    Location       = 'Global'
                    Severity       = $CheckMetadata.severity
                }
            }
            else {
                # Report individual users without MFA
                foreach ($item in $usersWithoutMfa) {
                    $user = $item.User
                    $roles = $item.Roles -join ', '
                    [PSCustomObject]@{
                        CheckId        = $CheckMetadata.id
                        Status         = 'FAIL'
                        StatusExtended = "Privileged user '$($user.displayName)' ($($user.userPrincipalName)) does not have MFA enabled. Assigned roles: $roles"
                        ResourceId     = $user.id
                        ResourceName   = $user.displayName
                        Location       = 'Global'
                        Severity       = $CheckMetadata.severity
                    }
                }
            }
        }
    }
}
