function Test-EntraNonPrivilegedUserHasMfa {
    <#
    .SYNOPSIS
        Tests if all non-privileged users have MFA enabled.

    .DESCRIPTION
        This check verifies that users who are not assigned to any directory roles
        (non-privileged users) have MFA registered. MFA provides additional security
        by requiring a second form of authentication.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraNonPrivilegedUserHasMfa -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [object[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData

    # Check if required data is available
    if (-not $svc.Users) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve users - missing permissions',
            'N/A',
            'Users'
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
        # Build a set of privileged user IDs (users in any directory role)
        $privilegedUserIds = @{}
        if ($svc.DirectoryRoleMembers) {
            foreach ($roleId in $svc.DirectoryRoleMembers.Keys) {
                $members = $svc.DirectoryRoleMembers[$roleId]
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
        foreach ($mfaStatus in $svc.UserMFAStatus) {
            $mfaStatusLookup[$mfaStatus.id] = $mfaStatus
        }

        # Check non-privileged users for MFA
        $nonPrivilegedUsers = $svc.Users | Where-Object {
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
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "All $totalNonPrivileged non-privileged users have MFA enabled",
                'non-privileged-users',
                'Non-Privileged Users'
            )
        }
        elseif ($totalNonPrivileged -eq 0) {
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                'No non-privileged users found to check',
                'non-privileged-users',
                'Non-Privileged Users'
            )
        }
        else {
            # Report individual users without MFA (limit to first 10 for readability)
            $displayLimit = 10
            $usersToDisplay = $usersWithoutMfa | Select-Object -First $displayLimit

            foreach ($user in $usersToDisplay) {
                [CIEMScanResult]::Create(
                    $Check,
                    'FAIL',
                    "Non-privileged user '$($user.displayName)' ($($user.userPrincipalName)) does not have MFA enabled",
                    $user.id,
                    $user.displayName
                )
            }

            if ($withoutMfaCount -gt $displayLimit) {
                [CIEMScanResult]::Create(
                    $Check,
                    'FAIL',
                    "... and $($withoutMfaCount - $displayLimit) additional non-privileged users without MFA (total: $withoutMfaCount out of $totalNonPrivileged)",
                    'non-privileged-users-summary',
                    'Non-Privileged Users Summary'
                )
            }
        }
    }
}
