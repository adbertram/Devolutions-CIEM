function Test-EntraUserWithVmAccessHasMfa {
    <#
    .SYNOPSIS
        Tests if users with VM access have MFA enabled.

    .DESCRIPTION
        This check verifies that users with role assignments that grant access to
        virtual machines have MFA registered. This includes roles such as:
        - Virtual Machine Administrator Login
        - Virtual Machine User Login
        - Virtual Machine Contributor
        - Owner (at VM or resource group scope)
        - Contributor (at VM or resource group scope)

        This check requires IAM service data to identify users with VM-related role assignments.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraUserWithVmAccessHasMfa -Check $metadata
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

    $entra = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData
    $iam = ($ServiceCache | Where-Object { $_.ServiceName -eq 'IAM' }).CacheData

    # VM-related role definition IDs used by this entitlement check.
    $vmRoleDefinitionIds = @(
        'b24988ac-6180-42a0-ab88-20f7382dd24c'  # Contributor
        '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'  # Owner
        '9980e02c-c2be-4d73-94e8-173b1dc7cf3c'  # Virtual Machine Contributor
        '1c0163c0-47e6-4577-8991-ea5c82e286e4'  # Virtual Machine Administrator Login
        'fb879df8-f326-4884-b1cf-06f3ad86be52'  # Virtual Machine User Login
        '602da2ba-a5c2-41da-b01d-5360126ab525'  # Virtual Machine Local User Login
        'a6333a3e-0164-44c3-b281-7a577aff287f'  # Windows Admin Center Administrator Login
    )

    # Check if required data is available
    if (-not $entra.UserMFAStatus) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve user MFA registration details - Azure AD Premium P1/P2 license required',
            'N/A',
            'User MFA Status'
        )
    }
    elseif (-not $iam -or -not $iam.RoleAssignments) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve IAM role assignments - IAM service not initialized or missing permissions. This check requires cross-reference with Azure Resource Manager role assignments.',
            'N/A',
            'IAM Role Assignments'
        )
    }
    else {
        # Build MFA status lookup
        $mfaStatusLookup = @{}
        foreach ($mfaStatus in $entra.UserMFAStatus) {
            $mfaStatusLookup[$mfaStatus.id] = $mfaStatus
        }

        # Find users with VM-related role assignments
        $usersWithVmAccess = @{}

        foreach ($assignment in $iam.RoleAssignments) {
            # Check if this is a VM-related role
            $roleDefinitionId = $assignment.roleDefinitionId
            if ($roleDefinitionId) {
                # Extract the role GUID from the full resource ID
                $roleGuid = ($roleDefinitionId -split '/')[-1]

                # Check if it's a VM-related role or if the scope includes VMs
                $isVmRole = $vmRoleDefinitionIds -contains $roleGuid
                $isVmScope = $assignment.scope -match '/Microsoft.Compute/virtualMachines/'

                if ($isVmRole -or $isVmScope) {
                    $principalId = $assignment.principalId
                    $principalType = $assignment.principalType

                    # Only check user principals (not groups or service principals)
                    if ($principalType -eq 'User' -and $principalId) {
                        if (-not $usersWithVmAccess.ContainsKey($principalId)) {
                            $usersWithVmAccess[$principalId] = @{
                                PrincipalId = $principalId
                                Roles       = @()
                                Scopes      = @()
                            }
                        }
                        $usersWithVmAccess[$principalId].Roles += $roleGuid
                        $usersWithVmAccess[$principalId].Scopes += $assignment.scope
                    }
                }
            }
        }

        if ($usersWithVmAccess.Count -eq 0) {
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                'No users found with direct VM access role assignments',
                'vm-access-users',
                'VM Access Users'
            )
        }
        else {
            # Check MFA status for each user with VM access
            $usersWithoutMfa = @()
            $usersWithMfa = @()

            foreach ($principalId in $usersWithVmAccess.Keys) {
                $userInfo = $usersWithVmAccess[$principalId]
                $mfaStatus = $mfaStatusLookup[$principalId]

                # Check if user has MFA methods registered
                $hasMfa = $false
                if ($mfaStatus) {
                    if ($mfaStatus.isMfaRegistered -eq $true) {
                        $hasMfa = $true
                    }
                    elseif ($mfaStatus.methodsRegistered -and $mfaStatus.methodsRegistered.Count -gt 0) {
                        $mfaMethods = $mfaStatus.methodsRegistered | Where-Object { $_ -ne 'password' }
                        if ($mfaMethods.Count -gt 0) {
                            $hasMfa = $true
                        }
                    }
                }

                if ($hasMfa) {
                    $usersWithMfa += $userInfo
                }
                else {
                    # Try to get user details from MFA status or users list
                    $userName = if ($mfaStatus) { $mfaStatus.userPrincipalName } else { $principalId }
                    $userInfo.UserName = $userName
                    $usersWithoutMfa += $userInfo
                }
            }

            $totalVmUsers = $usersWithVmAccess.Count
            $withoutMfaCount = $usersWithoutMfa.Count

            if ($withoutMfaCount -eq 0) {
                [CIEMScanResult]::Create(
                    $Check,
                    'PASS',
                    "All $totalVmUsers users with VM access have MFA enabled",
                    'vm-access-users',
                    'VM Access Users'
                )
            }
            else {
                foreach ($userInfo in $usersWithoutMfa) {
                    [CIEMScanResult]::Create(
                        $Check,
                        'FAIL',
                        "User '$($userInfo.UserName)' has VM access but does not have MFA enabled",
                        $userInfo.PrincipalId,
                        $userInfo.UserName
                    )
                }
            }
        }
    }
}
