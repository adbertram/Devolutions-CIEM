function Test-EntraPolicyGuestUserAccessRestriction {
    <#
    .SYNOPSIS
        Tests if guest user access is restricted to their own directory objects.

    .DESCRIPTION
        This check verifies that the authorization policy setting 'guestUserRoleId'
        is set to the most restrictive option, limiting guest access to only their
        own directory objects.

        Guest user role IDs:
        - 10dae51f-b6af-4016-8d66-8c2a99b929b3: Guest users have limited access to properties and memberships (default)
        - 2af84b1e-32c8-42b7-82bc-daa82404023b: Guest users have the same access as members (most permissive)
        - a0b1b346-4d3e-4e8b-98f8-753987be4970: Guest user access is restricted to their own directory objects (most restrictive)

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPolicyGuestUsersAccessRestrictions -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # Guest user role IDs
    $restrictedRoleId = 'a0b1b346-4d3e-4e8b-98f8-753987be4970'  # Most restrictive
    $limitedRoleId = '10dae51f-b6af-4016-8d66-8c2a99b929b3'     # Limited (default)
    $memberRoleId = '2af84b1e-32c8-42b7-82bc-daa82404023b'      # Same as members (most permissive)

    # Check if Authorization Policy data is available
    if (-not $script:EntraService.AuthorizationPolicy) {
        [CIEMScanResult]::Create(
            $CheckMetadata,
            'SKIPPED',
            'Unable to retrieve authorization policy - missing permissions',
            'N/A',
            'Authorization Policy'
        )
    }
    else {
        # Authorization policy can be returned as an array, get the first item
        $authPolicy = if ($script:EntraService.AuthorizationPolicy -is [array]) {
            $script:EntraService.AuthorizationPolicy | Select-Object -First 1
        }
        else {
            $script:EntraService.AuthorizationPolicy
        }

        # Check the guestUserRoleId setting
        $guestUserRoleId = $authPolicy.guestUserRoleId

        switch ($guestUserRoleId) {
            $restrictedRoleId {
                [CIEMScanResult]::Create(
                    $CheckMetadata,
                    'PASS',
                    'Guest user access is properly restricted to properties and memberships of their own directory objects only (most restrictive setting).',
                    $authPolicy.id,
                    'Authorization Policy'
                )
            }
            $limitedRoleId {
                [CIEMScanResult]::Create(
                    $CheckMetadata,
                    'FAIL',
                    'Guest users have limited access to properties and memberships of directory objects (default setting). Consider using the most restrictive option to limit guest access to their own directory objects only.',
                    $authPolicy.id,
                    'Authorization Policy'
                )
            }
            $memberRoleId {
                [CIEMScanResult]::Create(
                    $CheckMetadata,
                    'FAIL',
                    'Guest users have the same access as members (most permissive setting). This should be changed to restrict guest access to their own directory objects only.',
                    $authPolicy.id,
                    'Authorization Policy'
                )
            }
            default {
                [CIEMScanResult]::Create(
                    $CheckMetadata,
                    'FAIL',
                    "Unknown guest user role ID: $guestUserRoleId. Unable to determine guest access restrictions.",
                    $authPolicy.id,
                    'Authorization Policy'
                )
            }
        }
    }
}
