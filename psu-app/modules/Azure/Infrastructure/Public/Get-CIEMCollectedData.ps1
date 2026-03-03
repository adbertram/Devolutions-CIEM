function Get-CIEMCollectedData {
    <#
    .SYNOPSIS
        Reads collected service data from normalized Azure tables.
    .DESCRIPTION
        Reconstructs the service cache hashtable shape from the azure_* tables
        in the CIEM SQLite database using granular Get- functions. Returns the
        same data structure that Get-CIEMAzure*Data functions produce, so it can
        be fed directly to New-CIEMGraph for building the identity graph on-demand.
    .PARAMETER ProviderName
        The provider name (e.g., 'Azure'). Used to derive the provider_id.
    .OUTPUTS
        [hashtable] with keys:
        - EntraData: Hashtable matching Entra.ps1 output shape
        - IAMData: Hashtable matching IAM.ps1 output shape (keyed by subscription)
        - TenantId: The Azure AD tenant ID from the active authentication profile
    .EXAMPLE
        $data = Get-CIEMCollectedData -ProviderName 'Azure'
        $graph = New-CIEMGraph -EntraData $data.EntraData -IAMData $data.IAMData -TenantId $tenantId
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName
    )

    $ErrorActionPreference = 'Stop'

    $providerId = $ProviderName.ToLower()

    # Check if we have any data for this provider
    $principals = @(Get-CIEMAzureSecurityPrincipal -ProviderId $providerId)
    if ($principals.Count -eq 0) {
        Write-Verbose "Get-CIEMCollectedData: No collected data for provider '$ProviderName'"
        return $null
    }

    # --- Reconstruct Entra Data ---
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

    # Users
    $users = @($principals | Where-Object { $_.Type -eq 'User' })
    if ($users.Count -gt 0) {
        $entraData.Users = @($users | ForEach-Object {
            [PSCustomObject]@{
                id                = $_.Id
                displayName       = $_.DisplayName
                userPrincipalName = $_.UserPrincipalName
                accountEnabled    = if ($null -ne $_.Enabled) { [bool]$_.Enabled } else { $false }
                userType          = $_.UserType
            }
        })
    }

    # Groups
    $groups = @($principals | Where-Object { $_.Type -eq 'Group' })
    if ($groups.Count -gt 0) {
        $entraData.Groups = @($groups | ForEach-Object {
            [PSCustomObject]@{
                id          = $_.Id
                displayName = $_.DisplayName
            }
        })

        # Group memberships
        foreach ($group in $entraData.Groups) {
            $memberships = @(Get-CIEMAzureGroupMembership -GroupId $group.id)
            if ($memberships.Count -gt 0) {
                $entraData.GroupMembers[$group.id] = @($memberships | ForEach-Object {
                    $mp = @(Get-CIEMAzureSecurityPrincipal -Id $_.MemberId) | Select-Object -First 1
                    $odataType = ConvertTo-CIEMAzureOdataType -Type $_.MemberType
                    [PSCustomObject]@{
                        id                = $_.MemberId
                        displayName       = if ($mp) { $mp.DisplayName } else { '' }
                        userPrincipalName = if ($mp) { $mp.UserPrincipalName } else { '' }
                        '@odata.type'     = $odataType
                    }
                })
            }
        }
    }

    # Service Principals
    $sps = @($principals | Where-Object { $_.Type -eq 'ServicePrincipal' })
    if ($sps.Count -gt 0) {
        $entraData.ServicePrincipals = @($sps | ForEach-Object {
            [PSCustomObject]@{
                id                    = $_.Id
                appId                 = $_.AppId
                displayName           = $_.DisplayName
                servicePrincipalType  = $_.ServicePrincipalType
                accountEnabled        = if ($null -ne $_.Enabled) { [bool]$_.Enabled } else { $false }
            }
        })
    }

    # Applications
    $apps = @($principals | Where-Object { $_.Type -eq 'Application' })
    if ($apps.Count -gt 0) {
        $entraData.Applications = @($apps | ForEach-Object {
            [PSCustomObject]@{
                id          = $_.Id
                appId       = $_.AppId
                displayName = $_.DisplayName
            }
        })
    }

    # Directory Role Assignments → reconstruct DirectoryRoles + DirectoryRoleMembers
    $dirRoleAssignments = @(Get-CIEMAzureDirectoryRoleAssignment -ProviderId $providerId)
    if ($dirRoleAssignments.Count -gt 0) {
        $roleGroups = $dirRoleAssignments | Group-Object -Property RoleTemplateId
        $entraData.DirectoryRoles = @($roleGroups | ForEach-Object {
            $first = $_.Group[0]
            [PSCustomObject]@{
                id             = $first.RoleTemplateId
                displayName    = $first.RoleName
                roleTemplateId = $first.RoleTemplateId
            }
        })

        foreach ($role in $entraData.DirectoryRoles) {
            $roleMembers = @($dirRoleAssignments | Where-Object { $_.RoleTemplateId -eq $role.roleTemplateId })
            $entraData.DirectoryRoleMembers[$role.id] = @($roleMembers | ForEach-Object {
                $mp = @(Get-CIEMAzureSecurityPrincipal -Id $_.PrincipalId) | Select-Object -First 1
                $odataType = ConvertTo-CIEMAzureOdataType -Type $(if ($mp) { $mp.Type } else { '' })
                [PSCustomObject]@{
                    id                = $_.PrincipalId
                    displayName       = if ($mp) { $mp.DisplayName } else { '' }
                    userPrincipalName = if ($mp) { $mp.UserPrincipalName } else { '' }
                    '@odata.type'     = $odataType
                }
            })
        }
    }

    # App Role Assignments → reconstruct per-SP hashtable
    $appRoleAssignments = @(Get-CIEMAzureAppRoleAssignment -ProviderId $providerId)
    if ($appRoleAssignments.Count -gt 0) {
        $groupedByResource = $appRoleAssignments | Group-Object -Property ResourceId
        foreach ($group in $groupedByResource) {
            $entraData.AppRoleAssignments[$group.Name] = @($group.Group | ForEach-Object {
                [PSCustomObject]@{
                    id                  = $_.Id
                    principalId         = $_.PrincipalId
                    principalType       = $_.PrincipalType
                    resourceId          = $_.ResourceId
                    resourceDisplayName = $_.ResourceDisplayName
                    appRoleId           = $_.AppRoleId
                    appRoleValue        = $_.AppRoleValue
                }
            })
        }
    }

    # --- Reconstruct IAM Data ---
    $iamData = @{}

    $roleAssignments = @(Get-CIEMAzureRoleAssignment -ProviderId $providerId)
    $roleDefinitions = @(Get-CIEMAzureRoleDefinition -ProviderId $providerId)

    if ($roleAssignments.Count -gt 0 -or $roleDefinitions.Count -gt 0) {
        # Group role assignments by subscription (extracted from scope)
        $subscriptionIds = @($roleAssignments | ForEach-Object {
            if ($_.Scope -match '^/subscriptions/([^/]+)') { $Matches[1] }
        } | Select-Object -Unique)

        if ($subscriptionIds.Count -eq 0) { $subscriptionIds = @('default') }

        foreach ($subId in $subscriptionIds) {
            $subRoleAssignments = @($roleAssignments | Where-Object { $_.Scope -match "^/subscriptions/$subId" -or $subId -eq 'default' })

            # Reconstruct ARM API format
            $iamData[$subId] = @{
                RoleDefinitions = @($roleDefinitions | ForEach-Object {
                    $rdId = $_.Id
                    $perms = @(Get-CIEMAzureRoleDefinitionPermission -RoleDefinitionId $rdId)

                    $actions = @($perms | Where-Object { $_.ActionType -eq 'action' } | ForEach-Object { $_.Action })
                    $notActions = @($perms | Where-Object { $_.ActionType -eq 'notAction' } | ForEach-Object { $_.Action })
                    $dataActions = @($perms | Where-Object { $_.ActionType -eq 'dataAction' } | ForEach-Object { $_.Action })
                    $notDataActions = @($perms | Where-Object { $_.ActionType -eq 'notDataAction' } | ForEach-Object { $_.Action })

                    $assignableScopes = @()
                    if ($_.AssignableScopes) {
                        try { $assignableScopes = @($_.AssignableScopes | ConvertFrom-Json) } catch {}
                    }

                    [PSCustomObject]@{
                        id         = $_.Id
                        properties = [PSCustomObject]@{
                            roleName        = $_.RoleName
                            type            = $_.RoleType
                            description     = $_.Description
                            assignableScopes = $assignableScopes
                            permissions     = @([PSCustomObject]@{
                                actions        = $actions
                                notActions     = $notActions
                                dataActions    = $dataActions
                                notDataActions = $notDataActions
                            })
                        }
                    }
                })
                CustomRoles = @($roleDefinitions | Where-Object { $_.RoleType -eq 'CustomRole' } | ForEach-Object {
                    [PSCustomObject]@{
                        id         = $_.Id
                        properties = [PSCustomObject]@{
                            roleName = $_.RoleName
                            type     = 'CustomRole'
                        }
                    }
                })
                RoleAssignments = @($subRoleAssignments | ForEach-Object {
                    [PSCustomObject]@{
                        id         = $_.Id
                        properties = [PSCustomObject]@{
                            principalId      = $_.PrincipalId
                            principalType    = $_.PrincipalType
                            roleDefinitionId = $_.RoleDefinitionId
                            scope            = $_.Scope
                            condition        = $_.Condition
                            conditionVersion = $_.ConditionVersion
                            description      = $_.Description
                            createdOn        = $_.CreatedOn
                        }
                    }
                })
            }
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
