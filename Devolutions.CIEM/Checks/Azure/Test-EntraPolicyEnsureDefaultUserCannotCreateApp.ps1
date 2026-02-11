function Test-EntraPolicyEnsureDefaultUserCannotCreateApp {
    <#
    .SYNOPSIS
        Tests if default users are restricted from registering applications.

    .DESCRIPTION
        This check verifies that the authorization policy setting
        'defaultUserRolePermissions.allowedToCreateApps' is set to false,
        requiring administrators to register custom-developed applications.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraPolicyEnsureDefaultUserCannotCreateApps -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $params = @{
        Check = $Check
        PropertyName  = 'allowedToCreateApps'
        PassMessage   = 'Users cannot register applications. Application registration is restricted to administrators.'
        FailMessage   = 'Users can register applications. This setting should be disabled to require administrator approval for application registration.'
    }
    Test-EntraAuthorizationPolicyBooleanSetting @params
}
