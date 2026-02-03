function Initialize-EntraService {
    <#
    .SYNOPSIS
        Initializes the Entra ID service by pre-loading all required resources.

    .DESCRIPTION
        Loads Entra ID (Azure AD) resources from Microsoft Graph API and caches them
        in $script:EntraService for use by check scripts. This follows the singleton
        service pattern to avoid redundant API calls.

        Resources loaded:
        - Users and their MFA registration status
        - Directory roles and role members
        - Security defaults policy
        - Authorization policy settings
        - Conditional access policies
        - Named locations
        - Group settings

    .EXAMPLE
        Initialize-EntraService
        $script:EntraService.Users  # Access cached users
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $ErrorActionPreference = 'Stop'

    $graphApiBase = $script:Config.azure.endpoints.graphApi

    # Initialize service hashtable
    $script:EntraService = @{
        Users                     = $null
        UserMFAStatus             = $null
        DirectoryRoles            = $null
        DirectoryRoleMembers      = @{}
        SecurityDefaults          = $null
        AuthorizationPolicy       = $null
        ConditionalAccessPolicies = $null
        NamedLocations            = $null
        GroupSettings             = $null
    }

    # Load paginated resources
    Write-CIEMLog -Severity DEBUG -Message "Loading users..."
    $usersUri = "$graphApiBase/users?`$select=id,displayName,userPrincipalName,accountEnabled,userType"
    $script:EntraService.Users = @(Get-AllGraphPage -Uri $usersUri -ResourceName "Users")

    Write-CIEMLog -Severity DEBUG -Message "Loading user MFA status..."
    $mfaUri = "$graphApiBase/reports/authenticationMethods/userRegistrationDetails"
    $script:EntraService.UserMFAStatus = @(Get-AllGraphPage -Uri $mfaUri -ResourceName "UserMFAStatus")

    # Define non-paginated API endpoints to load - data-driven pattern
    $apiEndpoints = @{
        DirectoryRoles            = 'directoryRoles'
        SecurityDefaults          = 'policies/identitySecurityDefaultsEnforcementPolicy'
        AuthorizationPolicy       = 'policies/authorizationPolicy'
        ConditionalAccessPolicies = 'identity/conditionalAccess/policies'
        NamedLocations            = 'identity/conditionalAccess/namedLocations'
        GroupSettings             = 'groupSettings'
    }

    foreach ($endpoint in $apiEndpoints.GetEnumerator()) {
        $params = @{
            Uri          = "$graphApiBase/$($endpoint.Value)"
            ResourceName = $endpoint.Key
        }
        $script:EntraService[$endpoint.Key] = Invoke-AzureApi @params
    }

    # Load members for each directory role
    if ($script:EntraService.DirectoryRoles) {
        foreach ($role in $script:EntraService.DirectoryRoles) {
            $params = @{
                Uri          = "$graphApiBase/directoryRoles/$($role.id)/members"
                ResourceName = "DirectoryRole Members ($($role.displayName))"
            }
            $script:EntraService.DirectoryRoleMembers[$role.id] = Invoke-AzureApi @params
        }
    }

    # Log summary
    $counts = @{
        Users    = if ($script:EntraService.Users) { $script:EntraService.Users.Count } else { 0 }
        Roles    = if ($script:EntraService.DirectoryRoles) { $script:EntraService.DirectoryRoles.Count } else { 0 }
        Policies = if ($script:EntraService.ConditionalAccessPolicies) { $script:EntraService.ConditionalAccessPolicies.Count } else { 0 }
    }

    Write-CIEMLog -Severity DEBUG -Message "Entra service initialized: $($counts.Users) users, $($counts.Roles) roles, $($counts.Policies) conditional access policies"
}
