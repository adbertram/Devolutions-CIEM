function Get-CIEMCollectedData {
    <#
    .SYNOPSIS
        Reads collected Entra and IAM data from the azure_service_data table.
    .DESCRIPTION
        Queries azure_service_data for Entra and IAM services, groups by ResourceType,
        and reconstructs the same hashtable shape that Get-CIEMAzure*Data functions produce.
        The result can be fed directly to New-CIEMGraph for building the identity graph.
    .PARAMETER ProviderName
        The provider name (e.g., 'Azure'). Used to derive the provider_id.
    .OUTPUTS
        [hashtable] with keys:
        - EntraData: Hashtable matching Entra collector output shape
        - IAMData: Hashtable matching IAM collector output shape (keyed by subscription)
        - TenantId: The Azure AD tenant ID from the active authentication profile
    .EXAMPLE
        $data = Get-CIEMCollectedData -ProviderName 'Azure'
        $graph = New-CIEMGraph -EntraData $data.EntraData -IAMData $data.IAMData -TenantId $data.TenantId
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName
    )

    $ErrorActionPreference = 'Stop'

    $providerId = $ProviderName.ToLower()

    # --- Reconstruct Entra Data ---
    $entraRows = @(Get-CIEMAzureServiceData -ProviderId $providerId -ServiceName 'Entra')
    if ($entraRows.Count -eq 0) {
        Write-Verbose "Get-CIEMCollectedData: No collected data for provider '$ProviderName'"
        return $null
    }

    $entraData = @{
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

    # Group rows by ResourceType
    $byType = @{}
    foreach ($row in $entraRows) {
        if (-not $byType.ContainsKey($row.ResourceType)) {
            $byType[$row.ResourceType] = [System.Collections.Generic.List[object]]::new()
        }
        $byType[$row.ResourceType].Add($row)
    }

    # Entity arrays (each row.Data is the original API object)
    $arrayTypes = @{
        User              = 'Users'
        Group             = 'Groups'
        ServicePrincipal  = 'ServicePrincipals'
        Application       = 'Applications'
        DirectoryRole     = 'DirectoryRoles'
        ConditionalAccessPolicy = 'ConditionalAccessPolicies'
        NamedLocation     = 'NamedLocations'
        GroupSetting      = 'GroupSettings'
        UserMFAStatus     = 'UserMFAStatus'
    }

    foreach ($resourceType in $arrayTypes.Keys) {
        $key = $arrayTypes[$resourceType]
        if ($byType.ContainsKey($resourceType)) {
            $entraData[$key] = @($byType[$resourceType] | ForEach-Object { $_.Data })
        }
    }

    # Singleton objects
    if ($byType.ContainsKey('SecurityDefaults')) {
        $entraData.SecurityDefaults = $byType['SecurityDefaults'][0].Data
    }
    if ($byType.ContainsKey('AuthorizationPolicy')) {
        $entraData.AuthorizationPolicy = $byType['AuthorizationPolicy'][0].Data
    }

    # Keyed collections (ResourceId = parent ID, Data = array of children)
    $keyedTypes = @{
        GroupMembers           = 'GroupMembers'
        GroupOwners            = 'GroupOwners'
        DirectoryRoleMembers   = 'DirectoryRoleMembers'
        AppRoleAssignments     = 'AppRoleAssignments'
    }

    foreach ($resourceType in $keyedTypes.Keys) {
        $key = $keyedTypes[$resourceType]
        if ($byType.ContainsKey($resourceType)) {
            foreach ($row in $byType[$resourceType]) {
                $entraData[$key][$row.ResourceId] = $row.Data
            }
        }
    }

    # --- Reconstruct IAM Data ---
    $iamData = @{}
    $iamRows = @(Get-CIEMAzureServiceData -ProviderId $providerId -ServiceName 'IAM')

    if ($iamRows.Count -gt 0) {
        # Group by subscription, then by resource type
        $bySub = @{}
        foreach ($row in $iamRows) {
            $subId = if ($row.SubscriptionId) { $row.SubscriptionId } else { 'default' }
            if (-not $bySub.ContainsKey($subId)) {
                $bySub[$subId] = [System.Collections.Generic.List[object]]::new()
            }
            $bySub[$subId].Add($row)
        }

        foreach ($subId in $bySub.Keys) {
            $subRows = $bySub[$subId]
            $subData = @{
                RoleDefinitions = @()
                CustomRoles     = @()
                RoleAssignments = @()
            }

            foreach ($row in $subRows) {
                switch ($row.ResourceType) {
                    'RoleDefinition' { $subData.RoleDefinitions += $row.Data }
                    'CustomRole'     { $subData.CustomRoles += $row.Data }
                    'RoleAssignment' { $subData.RoleAssignments += $row.Data }
                }
            }

            $iamData[$subId] = $subData
        }
    }

    # Resolve TenantId from active authentication profile
    $tenantId = ''
    $authProfiles = @(Get-CIEMAzureAuthenticationProfile -ProviderId $providerId -IsActive $true)
    if ($authProfiles.Count -gt 0) { $tenantId = $authProfiles[0].TenantId }

    @{
        EntraData = $entraData
        IAMData   = $iamData
        TenantId  = $tenantId
    }
}
