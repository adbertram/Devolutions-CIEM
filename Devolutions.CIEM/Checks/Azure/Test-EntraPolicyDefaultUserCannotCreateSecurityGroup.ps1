function Test-EntraPolicyDefaultUserCannotCreateSecurityGroup {
    <#
    .SYNOPSIS
        Tests if default users are restricted from creating security groups.

    .DESCRIPTION
        This check verifies that the authorization policy setting
        'defaultUserRolePermissions.allowedToCreateSecurityGroups' is set to false,
        restricting security group creation to administrators only.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraPolicyDefaultUsersCannotCreateSecurityGroups -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMCheck]$Check
    )

    $params = @{
        Check = $Check
        PropertyName  = 'allowedToCreateSecurityGroups'
        PassMessage   = 'Users are restricted from creating security groups in Azure portals, API or PowerShell'
        FailMessage   = 'Users can create security groups in Azure portals, API or PowerShell. This should be restricted to administrators only.'
    }
    Test-EntraAuthorizationPolicyBooleanSetting @params
}
