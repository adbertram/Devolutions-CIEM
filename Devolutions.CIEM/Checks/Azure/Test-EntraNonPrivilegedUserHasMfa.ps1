function Test-EntraNonPrivilegedUserHasMfa {
    <#
    .SYNOPSIS
        Tests if all non-privileged users have MFA enabled.

    .DESCRIPTION
        This check verifies that users who are not assigned to any directory roles
        (non-privileged users) have MFA registered. MFA provides additional security
        by requiring a second form of authentication.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraNonPrivilegedUserHasMfa -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # Check if required data is available
    if (-not $script:EntraService.Users) {
        $findingParams = @{
            CheckMetadata  = $CheckMetadata
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve users - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'Users'
        }
        New-CIEMFinding @findingParams
    }
    elseif (-not $script:EntraService.UserMFAStatus) {
        $findingParams = @{
            CheckMetadata  = $CheckMetadata
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve user MFA registration details - Azure AD Premium P1/P2 license required'
            ResourceId     = 'N/A'
            ResourceName   = 'User MFA Status'
        }
        New-CIEMFinding @findingParams
    }
    else {
        # Build a set of privileged user IDs (users in any directory role)
        $privilegedUserIds = @{}
        if ($script:EntraService.DirectoryRoleMembers) {
            foreach ($roleId in $script:EntraService.DirectoryRoleMembers.Keys) {
                $members = $script:EntraService.DirectoryRoleMembers[$roleId]
                if ($members) {
                    foreach ($member in $members) {
                        if ($member.id) {
                            $privilegedUserIds[$member.id] = $true
                        }
                    }
                }
            }
        }

        # Build MFA status lookup
        $mfaStatusLookup = @{}
        foreach ($mfaStatus in $script:EntraService.UserMFAStatus) {
            $mfaStatusLookup[$mfaStatus.id] = $mfaStatus
        }

        # Check non-privileged users for MFA
        $nonPrivilegedUsers = $script:EntraService.Users | Where-Object {
            -not $privilegedUserIds.ContainsKey($_.id) -and $_.accountEnabled -eq $true -and $_.userType -eq 'Member'
        }

        $usersWithoutMfa = @()
        $usersWithMfa = @()

        foreach ($user in $nonPrivilegedUsers) {
            $mfaStatus = $mfaStatusLookup[$user.id]

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
                $usersWithMfa += $user
            }
            else {
                $usersWithoutMfa += $user
            }
        }

        $totalNonPrivileged = $nonPrivilegedUsers.Count
        $withoutMfaCount = $usersWithoutMfa.Count

        if ($withoutMfaCount -eq 0 -and $totalNonPrivileged -gt 0) {
            $findingParams = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'PASS'
                StatusExtended = "All $totalNonPrivileged non-privileged users have MFA enabled"
                ResourceId     = 'non-privileged-users'
                ResourceName   = 'Non-Privileged Users'
            }
            New-CIEMFinding @findingParams
        }
        elseif ($totalNonPrivileged -eq 0) {
            $findingParams = @{
                CheckMetadata  = $CheckMetadata
                Status         = 'PASS'
                StatusExtended = 'No non-privileged users found to check'
                ResourceId     = 'non-privileged-users'
                ResourceName   = 'Non-Privileged Users'
            }
            New-CIEMFinding @findingParams
        }
        else {
            # Report individual users without MFA (limit to first 10 for readability)
            $displayLimit = 10
            $usersToDisplay = $usersWithoutMfa | Select-Object -First $displayLimit

            foreach ($user in $usersToDisplay) {
                $findingParams = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'FAIL'
                    StatusExtended = "Non-privileged user '$($user.displayName)' ($($user.userPrincipalName)) does not have MFA enabled"
                    ResourceId     = $user.id
                    ResourceName   = $user.displayName
                }
                New-CIEMFinding @findingParams
            }

            if ($withoutMfaCount -gt $displayLimit) {
                $findingParams = @{
                    CheckMetadata  = $CheckMetadata
                    Status         = 'FAIL'
                    StatusExtended = "... and $($withoutMfaCount - $displayLimit) additional non-privileged users without MFA (total: $withoutMfaCount out of $totalNonPrivileged)"
                    ResourceId     = 'non-privileged-users-summary'
                    ResourceName   = 'Non-Privileged Users Summary'
                }
                New-CIEMFinding @findingParams
            }
        }
    }
}
