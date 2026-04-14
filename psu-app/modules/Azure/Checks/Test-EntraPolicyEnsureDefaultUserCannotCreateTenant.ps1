function Test-EntraPolicyEnsureDefaultUserCannotCreateTenant {
    <#
    .SYNOPSIS
        Tests if non-admin users are restricted from creating new tenants.

    .DESCRIPTION
        This check verifies that the authorization policy setting
        'defaultUserRolePermissions.allowedToCreateTenants' is set to false,
        preventing non-admin users from creating new Azure AD or Azure AD B2C tenants.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraPolicyEnsureDefaultUserCannotCreateTenants -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $params = @{
        Check = $Check
        PropertyName  = 'allowedToCreateTenants'
        PassMessage   = 'Non-admin users are restricted from creating new tenants'
        FailMessage   = 'Non-admin users can create new tenants. This should be restricted to administrators only.'
        ServiceCache  = $ServiceCache
    }
    TestEntraAuthorizationPolicyBooleanSetting @params
}
