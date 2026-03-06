function Get-CIEMAzureEntraData {
    <#
    .SYNOPSIS
        Retrieves Entra ID (Azure AD) data from Microsoft Graph API.
    .DESCRIPTION
        Fetches comprehensive Entra ID data including users, groups, service principals,
        applications, directory roles, conditional access policies, and more.
        This function is tenant-scoped and does not require subscription IDs.
    .OUTPUTS
        [hashtable] - Contains Users, Groups, ServicePrincipals, Applications, DirectoryRoles,
        DirectoryRoleMembers, GroupMembers, GroupOwners, ConditionalAccessPolicies, etc.
    .EXAMPLE
        $entraData = Get-CIEMAzureEntraData
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $ErrorActionPreference = 'Stop'

    # Comprehensive Graph API error patterns for catch blocks
    $graphPermissionErrors = 'Access denied|missing permissions|403|Forbidden|Authorization_RequestDenied|Insufficient privileges|InvalidAuthenticationToken|Authentication_MissingOrMalformed|Unauthorized'
    $graphLicenseErrors = 'RequestFromNonPremiumTenantOrB2CTenant|premium license|premium subscription'

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
        Groups                    = $null
        GroupMembers              = @{}
        GroupOwners               = @{}
        ServicePrincipals         = $null
        Applications              = $null
        AppRoleAssignments        = @{}
    }

    # Load paginated resources
    Write-CIEMLog -Severity DEBUG -Message "Loading users..."
    try {
        $data.Users = @(Invoke-AzureApi -Api Graph -Path "users?`$select=id,displayName,userPrincipalName,accountEnabled,userType,department,jobTitle&`$expand=manager(`$select=id)" -ResourceName "Users")
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
    Write-CIEMLog -Severity DEBUG -Message "Loading user MFA status..."
    try {
        $data.UserMFAStatus = @(Invoke-AzureApi -Api Graph -Path "reports/authenticationMethods/userRegistrationDetails" -ResourceName "UserMFAStatus")
    }
    catch {
        if ($_.Exception.Message -match "$graphLicenseErrors|$graphPermissionErrors") {
            Write-CIEMLog -Severity WARNING -Message "MFA status data unavailable - Azure AD Premium license required. MFA-related checks will be skipped."
            $data.UserMFAStatus = $null
            $data.MFAStatusUnavailable = $true
        }
        else {
            throw
        }
    }

    # Define non-paginated API endpoints to load
    $apiEndpoints = @{
        DirectoryRoles      = @{ Path = 'directoryRoles'; RequiresPremium = $false }
        SecurityDefaults    = @{ Path = 'policies/identitySecurityDefaultsEnforcementPolicy'; RequiresPremium = $false }
        AuthorizationPolicy = @{ Path = 'policies/authorizationPolicy'; RequiresPremium = $false }
        GroupSettings       = @{ Path = 'groupSettings'; RequiresPremium = $false }
        ConditionalAccessPolicies = @{ Path = 'identity/conditionalAccess/policies'; RequiresPremium = $true }
        NamedLocations            = @{ Path = 'identity/conditionalAccess/namedLocations'; RequiresPremium = $true }
    }

    foreach ($endpoint in $apiEndpoints.GetEnumerator()) {
        $params = @{
            Api          = 'Graph'
            Path         = $endpoint.Value.Path
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
                Api          = 'Graph'
                Path         = "directoryRoles/$($role.id)/members"
                ResourceName = "DirectoryRole Members ($($role.displayName))"
            }
            try {
                $data.DirectoryRoleMembers[$role.id] = Invoke-AzureApi @params
            }
            catch {
                Write-CIEMLog -Severity WARNING -Message "DirectoryRole Members ($($role.displayName)) unavailable - $($_.Exception.Message)"
                $data.DirectoryRoleMembers[$role.id] = $null
            }
        }
    }

    # Load groups
    Write-CIEMLog -Severity DEBUG -Message "Loading groups..."
    try {
        $data.Groups = @(Invoke-AzureApi -Api Graph -Path "groups?`$select=id,displayName,securityEnabled,isAssignableToRole,groupTypes,visibility" -ResourceName "Groups")
    }
    catch {
        if ($_.Exception.Message -match $graphPermissionErrors) {
            Write-CIEMLog -Severity WARNING -Message "Groups data unavailable - missing permissions. Group-related checks will be skipped."
            $data.Groups = $null
        }
        else { throw }
    }

    # Load members for each group
    $data.GroupMembers = @{}
    if ($data.Groups) {
        $groupCount = $data.Groups.Count
        Write-CIEMLog -Severity DEBUG -Message "Loading group members for $groupCount groups..."
        $groupIdx = 0
        foreach ($group in $data.Groups) {
            $groupIdx++
            if ($groupIdx % 50 -eq 0) {
                Write-CIEMLog -Severity DEBUG -Message "Loading group members: $groupIdx of $groupCount..."
            }
            try {
                $data.GroupMembers[$group.id] = @(Invoke-AzureApi -Api Graph -Path "groups/$($group.id)/members" -ResourceName "Group Members ($($group.displayName))")
            }
            catch {
                Write-CIEMLog -Severity WARNING -Message "Group Members ($($group.displayName)) unavailable - $($_.Exception.Message)"
                $data.GroupMembers[$group.id] = $null
            }
        }
    }

    # Load owners for each group
    $data.GroupOwners = @{}
    if ($data.Groups) {
        $groupCount = $data.Groups.Count
        Write-CIEMLog -Severity DEBUG -Message "Loading group owners for $groupCount groups..."
        $groupIdx = 0
        foreach ($group in $data.Groups) {
            $groupIdx++
            if ($groupIdx % 50 -eq 0) {
                Write-CIEMLog -Severity DEBUG -Message "Loading group owners: $groupIdx of $groupCount..."
            }
            try {
                $data.GroupOwners[$group.id] = @(Invoke-AzureApi -Api Graph -Path "groups/$($group.id)/owners" -ResourceName "Group Owners ($($group.displayName))")
            }
            catch {
                Write-CIEMLog -Severity WARNING -Message "Group Owners ($($group.displayName)) unavailable - $($_.Exception.Message)"
                $data.GroupOwners[$group.id] = $null
            }
        }
    }

    # Load service principals
    Write-CIEMLog -Severity DEBUG -Message "Loading service principals..."
    try {
        $data.ServicePrincipals = @(Invoke-AzureApi -Api Graph -Path "servicePrincipals?`$select=id,appId,displayName,servicePrincipalType,accountEnabled,signInAudience,tags" -ResourceName "ServicePrincipals")
    }
    catch {
        if ($_.Exception.Message -match $graphPermissionErrors) {
            Write-CIEMLog -Severity WARNING -Message "ServicePrincipals data unavailable - missing permissions."
            $data.ServicePrincipals = $null
        }
        else { throw }
    }

    # Load applications
    Write-CIEMLog -Severity DEBUG -Message "Loading applications..."
    try {
        $data.Applications = @(Invoke-AzureApi -Api Graph -Path "applications?`$select=id,appId,displayName,publisherDomain,signInAudience" -ResourceName "Applications")
    }
    catch {
        if ($_.Exception.Message -match $graphPermissionErrors) {
            Write-CIEMLog -Severity WARNING -Message "Applications data unavailable - missing permissions."
            $data.Applications = $null
        }
        else { throw }
    }

    # Load app role assignments per service principal
    $data.AppRoleAssignments = @{}
    if ($data.ServicePrincipals) {
        $spCount = $data.ServicePrincipals.Count
        Write-CIEMLog -Severity DEBUG -Message "Loading app role assignments for $spCount service principals..."
        $spIdx = 0
        foreach ($sp in $data.ServicePrincipals) {
            $spIdx++
            if ($spIdx % 50 -eq 0) {
                Write-CIEMLog -Severity DEBUG -Message "Loading app role assignments: $spIdx of $spCount..."
            }
            try {
                $assignments = @(Invoke-AzureApi -Api Graph -Path "servicePrincipals/$($sp.id)/appRoleAssignedTo" -ResourceName "AppRoleAssignments ($($sp.displayName))")
                if ($assignments.Count -gt 0) {
                    $data.AppRoleAssignments[$sp.id] = $assignments
                }
            }
            catch {
                Write-CIEMLog -Severity WARNING -Message "AppRoleAssignments ($($sp.displayName)) unavailable - $($_.Exception.Message)"
                $data.AppRoleAssignments[$sp.id] = $null
            }
        }
    }

    # Log summary
    $counts = @{
        Users             = if ($data.Users) { $data.Users.Count } else { 0 }
        Roles             = if ($data.DirectoryRoles) { $data.DirectoryRoles.Count } else { 0 }
        Policies          = if ($data.ConditionalAccessPolicies) { $data.ConditionalAccessPolicies.Count } else { 0 }
        MFAData           = if ($data.UserMFAStatus) { $data.UserMFAStatus.Count } else { 'N/A (Premium required)' }
        Groups            = if ($data.Groups) { $data.Groups.Count } else { 0 }
        ServicePrincipals = if ($data.ServicePrincipals) { $data.ServicePrincipals.Count } else { 0 }
        Applications      = if ($data.Applications) { $data.Applications.Count } else { 0 }
    }

    Write-CIEMLog -Severity DEBUG -Message "Entra service initialized: $($counts.Users) users, $($counts.Roles) roles, $($counts.Policies) CA policies, $($counts.Groups) groups, $($counts.ServicePrincipals) service principals, $($counts.Applications) applications, MFA data: $($counts.MFAData)"

    $data
}
