function Test-EntraPolicyGuestInviteOnlyForAdminRole {
    <#
    .SYNOPSIS
        Tests if guest invitations are restricted to admin roles.

    .DESCRIPTION
        This check verifies that the authorization policy setting 'allowInvitesFrom'
        is set to 'adminsAndGuestInviters' or 'none', restricting who can invite
        guest users to the organization.

        Valid values for allowInvitesFrom:
        - none: No one can invite guests
        - adminsAndGuestInviters: Only admins and users with Guest Inviter role
        - adminsGuestInvitersAndAllMembers: All members and above
        - everyone: Anyone including guests

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraPolicyGuestInviteOnlyForAdminRoles -Check $metadata
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

    # Check if Authorization Policy data is available
    if (-not $svc.AuthorizationPolicy) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve authorization policy - missing permissions',
            'N/A',
            'Authorization Policy'
        )
    }
    else {
        # Authorization policy can be returned as an array, get the first item
        $authPolicy = if ($svc.AuthorizationPolicy -is [array]) {
            $svc.AuthorizationPolicy | Select-Object -First 1
        }
        else {
            $svc.AuthorizationPolicy
        }

        # Check the allowInvitesFrom setting
        $allowInvitesFrom = $authPolicy.allowInvitesFrom

        # Acceptable values are 'none' or 'adminsAndGuestInviters'
        $acceptableValues = @('none', 'adminsAndGuestInviters')

        if ($allowInvitesFrom -in $acceptableValues) {
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "Guest invite restrictions are properly configured. Current setting: '$allowInvitesFrom' - only users with admin roles can invite guest users.",
                $authPolicy.id,
                'Authorization Policy'
            )
        }
        else {
            [CIEMScanResult]::Create(
                $Check,
                'FAIL',
                "Guest invite restrictions are too permissive. Current setting: '$allowInvitesFrom'. Should be 'adminsAndGuestInviters' or 'none' to restrict guest invitations to admin roles only.",
                $authPolicy.id,
                'Authorization Policy'
            )
        }
    }
}
