[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$SubscriptionIds = @()
)

$ErrorActionPreference = 'Stop'

# Comprehensive Graph API error patterns for catch blocks
$graphPermissionErrors = 'Access denied|missing permissions|403|Forbidden|Authorization_RequestDenied|Insufficient privileges|InvalidAuthenticationToken|Authentication_MissingOrMalformed|Unauthorized'
$graphLicenseErrors = 'RequestFromNonPremiumTenantOrB2CTenant|premium license|premium subscription'

$graphApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.graphApi

# Initialize service hashtable
$data = @{
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
    $data.Users = @(Get-AllGraphPage -Uri $usersUri -ResourceName "Users")
}
catch {
    if ($_.Exception.Message -match $graphPermissionErrors) {
        Write-CIEMLog -Severity WARNING -Message "Users data unavailable - missing permissions. User-related checks will be skipped."
        $data.Users = $null
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
    $data.UserMFAStatus = @(Get-AllGraphPage -Uri $mfaUri -ResourceName "UserMFAStatus")
}
catch {
    # Check for common licensing/permission errors
    if ($_.Exception.Message -match "$graphLicenseErrors|$graphPermissionErrors") {
        Write-CIEMLog -Severity WARNING -Message "MFA status data unavailable - Azure AD Premium license required. MFA-related checks will be skipped."
        $data.UserMFAStatus = $null
        $data.MFAStatusUnavailable = $true
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
        $data[$endpoint.Key] = Invoke-AzureApi @params
    }
    catch {
        if ($_.Exception.Message -match $graphPermissionErrors) {
            $reason = if ($endpoint.Value.RequiresPremium) { 'Azure AD Premium license required' } else { 'missing permissions' }
            Write-CIEMLog -Severity WARNING -Message "$($endpoint.Key) data unavailable - $reason. Related checks will be skipped."
            $data[$endpoint.Key] = $null
        }
        elseif ($endpoint.Value.RequiresPremium -and ($_.Exception.Message -match $graphLicenseErrors)) {
            Write-CIEMLog -Severity WARNING -Message "$($endpoint.Key) data unavailable - Azure AD Premium license required."
            $data[$endpoint.Key] = $null
        }
        else {
            throw
        }
    }
}

# Load members for each directory role
if ($data.DirectoryRoles) {
    foreach ($role in $data.DirectoryRoles) {
        $params = @{
            Uri          = "$graphApiBase/directoryRoles/$($role.id)/members"
            ResourceName = "DirectoryRole Members ($($role.displayName))"
        }
        try {
            $data.DirectoryRoleMembers[$role.id] = Invoke-AzureApi @params
        }
        catch {
            if ($_.Exception.Message -match $graphPermissionErrors) {
                Write-CIEMLog -Severity WARNING -Message "DirectoryRole Members ($($role.displayName)) unavailable - missing permissions. Role member checks may be incomplete."
                $data.DirectoryRoleMembers[$role.id] = $null
            }
            else {
                throw
            }
        }
    }
}

# Log summary
$counts = @{
    Users    = if ($data.Users) { $data.Users.Count } else { 0 }
    Roles    = if ($data.DirectoryRoles) { $data.DirectoryRoles.Count } else { 0 }
    Policies = if ($data.ConditionalAccessPolicies) { $data.ConditionalAccessPolicies.Count } else { 0 }
    MFAData  = if ($data.UserMFAStatus) { $data.UserMFAStatus.Count } else { 'N/A (Premium required)' }
}

Write-CIEMLog -Severity DEBUG -Message "Entra service initialized: $($counts.Users) users, $($counts.Roles) roles, $($counts.Policies) CA policies, MFA data: $($counts.MFAData)"

$data
