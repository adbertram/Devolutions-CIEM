function Save-CIEMAzureEntraData {
    <#
    .SYNOPSIS
        Persists Entra ID data to the azure_service_data table.
    .DESCRIPTION
        Clears previous Entra data for the provider, then saves all Entra entities
        (users, groups, service principals, applications, directory roles, policies,
        memberships, and assignments) as JSON blobs in azure_service_data.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER Data
        The Entra service data hashtable from Get-CIEMAzureEntraData.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Persists collected data to database')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $ErrorActionPreference = 'Stop'

    # Clear previous Entra data
    Remove-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName 'Entra' -Confirm:$false

    # Entity collections: each item has an .id property
    $entityCollections = @{
        Users              = 'User'
        Groups             = 'Group'
        ServicePrincipals  = 'ServicePrincipal'
        Applications       = 'Application'
        DirectoryRoles     = 'DirectoryRole'
        ConditionalAccessPolicies = 'ConditionalAccessPolicy'
        NamedLocations     = 'NamedLocation'
        GroupSettings      = 'GroupSetting'
    }

    foreach ($key in $entityCollections.Keys) {
        $resourceType = $entityCollections[$key]
        if ($Data[$key]) {
            foreach ($item in $Data[$key]) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId `
                    -ServiceName 'Entra' -ResourceType $resourceType `
                    -ResourceId $item.id -ResourceName ($item.displayName ?? $item.id) -Data $item
            }
        }
    }

    # Singleton objects
    if ($null -ne $Data.SecurityDefaults) {
        Save-CIEMAzureServiceData -ProviderId $ProviderId `
            -ServiceName 'Entra' -ResourceType 'SecurityDefaults' `
            -ResourceId 'default' -ResourceName 'SecurityDefaults' -Data $Data.SecurityDefaults
    }

    if ($null -ne $Data.AuthorizationPolicy) {
        Save-CIEMAzureServiceData -ProviderId $ProviderId `
            -ServiceName 'Entra' -ResourceType 'AuthorizationPolicy' `
            -ResourceId 'default' -ResourceName 'AuthorizationPolicy' -Data $Data.AuthorizationPolicy
    }

    # UserMFAStatus is a flat array of registration details (each has .id)
    if ($Data.UserMFAStatus -and $Data.UserMFAStatus -is [array]) {
        foreach ($mfa in $Data.UserMFAStatus) {
            Save-CIEMAzureServiceData -ProviderId $ProviderId `
                -ServiceName 'Entra' -ResourceType 'UserMFAStatus' `
                -ResourceId $mfa.id -ResourceName ($mfa.userPrincipalName ?? $mfa.id) -Data $mfa
        }
    }

    # Keyed collections: hashtable where key = parent ID, value = array of children
    $keyedCollections = @{
        GroupMembers           = 'GroupMembers'
        GroupOwners            = 'GroupOwners'
        DirectoryRoleMembers   = 'DirectoryRoleMembers'
        AppRoleAssignments     = 'AppRoleAssignments'
    }

    foreach ($key in $keyedCollections.Keys) {
        $resourceType = $keyedCollections[$key]
        if ($Data[$key] -and $Data[$key] -is [hashtable]) {
            foreach ($parentId in $Data[$key].Keys) {
                $childData = $Data[$key][$parentId]
                Save-CIEMAzureServiceData -ProviderId $ProviderId `
                    -ServiceName 'Entra' -ResourceType $resourceType `
                    -ResourceId $parentId -ResourceName $parentId -Data $childData
            }
        }
    }
}
