function Test-EntraPolicyEnsureDefaultUserCannotCreateApp {
    <#
    .SYNOPSIS
        Tests if default users are restricted from registering applications.

    .DESCRIPTION
        This check verifies that the authorization policy setting
        'defaultUserRolePermissions.allowedToCreateApps' is set to false,
        requiring administrators to register custom-developed applications.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPolicyEnsureDefaultUserCannotCreateApps -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $params = @{
        CheckMetadata = $CheckMetadata
        PropertyName  = 'allowedToCreateApps'
        PassMessage   = 'Users cannot register applications. Application registration is restricted to administrators.'
        FailMessage   = 'Users can register applications. This setting should be disabled to require administrator approval for application registration.'
    }
    Test-EntraAuthorizationPolicyBooleanSetting @params
}
