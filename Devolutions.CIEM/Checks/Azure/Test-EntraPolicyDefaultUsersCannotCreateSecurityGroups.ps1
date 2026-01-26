function Test-EntraPolicyDefaultUsersCannotCreateSecurityGroups {
    <#
    .SYNOPSIS
        Tests if default users are restricted from creating security groups.

    .DESCRIPTION
        This check verifies that the authorization policy setting
        'defaultUserRolePermissions.allowedToCreateSecurityGroups' is set to false,
        restricting security group creation to administrators only.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraPolicyDefaultUsersCannotCreateSecurityGroups -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $params = @{
        CheckMetadata = $CheckMetadata
        PropertyName  = 'allowedToCreateSecurityGroups'
        PassMessage   = 'Users are restricted from creating security groups in Azure portals, API or PowerShell'
        FailMessage   = 'Users can create security groups in Azure portals, API or PowerShell. This should be restricted to administrators only.'
    }
    Test-EntraAuthorizationPolicyBooleanSetting @params
}
