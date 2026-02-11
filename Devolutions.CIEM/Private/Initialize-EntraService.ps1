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
    try {
        $script:EntraService.Users = @(Get-AllGraphPage -Uri $usersUri -ResourceName "Users")
    }
    catch {
        if ($_.Exception.Message -match 'Access denied|missing permissions|403|Forbidden') {
            Write-CIEMLog -Severity WARNING -Message "Users data unavailable - missing permissions. User-related checks will be skipped."
            $script:EntraService.Users = $null
        }
        else {
            throw
        }
    }

    # Load user MFA status - requires Azure AD Premium P1/P2 license
    # Handle gracefully if tenant doesn't have the required license
    Write-CIEMLog -Severity DEBUG -Message "Loading user MFA status..."
    $mfaUri = "$graphApiBase/reports/authenticationMethods/userRegistrationDetails"
    try {
        $script:EntraService.UserMFAStatus = @(Get-AllGraphPage -Uri $mfaUri -ResourceName "UserMFAStatus")
    }
    catch {
        # Check for common licensing/permission errors
        if ($_.Exception.Message -match 'RequestFromNonPremiumTenantOrB2CTenant|premium license|Access denied|missing permissions|403|Forbidden') {
            Write-CIEMLog -Severity WARNING -Message "MFA status data unavailable - Azure AD Premium license required. MFA-related checks will be skipped."
            $script:EntraService.UserMFAStatus = $null
            $script:EntraService.MFAStatusUnavailable = $true
        }
        else {
            # Re-throw other errors
            throw
        }
    }

    # Define non-paginated API endpoints to load - data-driven pattern
    # Some endpoints require Azure AD Premium (ConditionalAccessPolicies, NamedLocations)
    $apiEndpoints = @{
        DirectoryRoles      = @{ Path = 'directoryRoles'; RequiresPremium = $false }
        SecurityDefaults    = @{ Path = 'policies/identitySecurityDefaultsEnforcementPolicy'; RequiresPremium = $false }
        AuthorizationPolicy = @{ Path = 'policies/authorizationPolicy'; RequiresPremium = $false }
        GroupSettings       = @{ Path = 'groupSettings'; RequiresPremium = $false }
        # Premium-required endpoints
        ConditionalAccessPolicies = @{ Path = 'identity/conditionalAccess/policies'; RequiresPremium = $true }
        NamedLocations            = @{ Path = 'identity/conditionalAccess/namedLocations'; RequiresPremium = $true }
    }

    foreach ($endpoint in $apiEndpoints.GetEnumerator()) {
        $params = @{
            Uri          = "$graphApiBase/$($endpoint.Value.Path)"
            ResourceName = $endpoint.Key
        }
        try {
            $script:EntraService[$endpoint.Key] = Invoke-AzureApi @params
        }
        catch {
            if ($_.Exception.Message -match 'Access denied|missing permissions|403|Forbidden') {
                $reason = if ($endpoint.Value.RequiresPremium) { 'Azure AD Premium license required' } else { 'missing permissions' }
                Write-CIEMLog -Severity WARNING -Message "$($endpoint.Key) data unavailable - $reason. Related checks will be skipped."
                $script:EntraService[$endpoint.Key] = $null
            }
            elseif ($endpoint.Value.RequiresPremium -and ($_.Exception.Message -match 'RequestFromNonPremiumTenantOrB2CTenant|premium license')) {
                Write-CIEMLog -Severity WARNING -Message "$($endpoint.Key) data unavailable - Azure AD Premium license required."
                $script:EntraService[$endpoint.Key] = $null
            }
            else {
                throw
            }
        }
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
        MFAData  = if ($script:EntraService.UserMFAStatus) { $script:EntraService.UserMFAStatus.Count } else { 'N/A (Premium required)' }
    }

    Write-CIEMLog -Severity DEBUG -Message "Entra service initialized: $($counts.Users) users, $($counts.Roles) roles, $($counts.Policies) CA policies, MFA data: $($counts.MFAData)"
}
