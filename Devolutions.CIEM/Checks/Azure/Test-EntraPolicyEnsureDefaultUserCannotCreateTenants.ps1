function Test-EntraPolicyEnsureDefaultUserCannotCreateTenants {
    <#
    .SYNOPSIS
        Tests if non-admin users are restricted from creating new tenants.

    .DESCRIPTION
        This check verifies that the authorization policy setting
        'defaultUserRolePermissions.allowedToCreateTenants' is set to false,
        preventing non-admin users from creating new Azure AD or Azure AD B2C tenants.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPolicyEnsureDefaultUserCannotCreateTenants -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $params = @{
        CheckMetadata = $CheckMetadata
        PropertyName  = 'allowedToCreateTenants'
        PassMessage   = 'Non-admin users are restricted from creating new tenants'
        FailMessage   = 'Non-admin users can create new tenants. This should be restricted to administrators only.'
    }
    Test-EntraAuthorizationPolicyBooleanSetting @params
}
