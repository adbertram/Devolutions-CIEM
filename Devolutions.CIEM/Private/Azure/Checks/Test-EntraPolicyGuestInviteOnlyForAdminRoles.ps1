function Test-EntraPolicyGuestInviteOnlyForAdminRoles {
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

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPolicyGuestInviteOnlyForAdminRoles -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # Check if Authorization Policy data is available
    if (-not $script:EntraService.AuthorizationPolicy) {
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve authorization policy - missing permissions'
            ResourceId     = 'N/A'
            ResourceName   = 'Authorization Policy'
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
    }
    else {
        # Authorization policy can be returned as an array, get the first item
        $authPolicy = if ($script:EntraService.AuthorizationPolicy -is [array]) {
            $script:EntraService.AuthorizationPolicy | Select-Object -First 1
        }
        else {
            $script:EntraService.AuthorizationPolicy
        }

        # Check the allowInvitesFrom setting
        $allowInvitesFrom = $authPolicy.allowInvitesFrom

        # Acceptable values are 'none' or 'adminsAndGuestInviters'
        $acceptableValues = @('none', 'adminsAndGuestInviters')

        if ($allowInvitesFrom -in $acceptableValues) {
            [PSCustomObject]@{
                CheckId        = $CheckMetadata.id
                Status         = 'PASS'
                StatusExtended = "Guest invite restrictions are properly configured. Current setting: '$allowInvitesFrom' - only users with admin roles can invite guest users."
                ResourceId     = $authPolicy.id
                ResourceName   = 'Authorization Policy'
                Location       = 'Global'
                Severity       = $CheckMetadata.severity
            }
        }
        else {
            [PSCustomObject]@{
                CheckId        = $CheckMetadata.id
                Status         = 'FAIL'
                StatusExtended = "Guest invite restrictions are too permissive. Current setting: '$allowInvitesFrom'. Should be 'adminsAndGuestInviters' or 'none' to restrict guest invitations to admin roles only."
                ResourceId     = $authPolicy.id
                ResourceName   = 'Authorization Policy'
                Location       = 'Global'
                Severity       = $CheckMetadata.severity
            }
        }
    }
}
