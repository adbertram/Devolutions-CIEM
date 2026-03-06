function Save-CIEMCollectedData {
    <#
    .SYNOPSIS
        Persists collected service cache data to normalized Azure tables.
    .DESCRIPTION
        Called during a scan after service data has been collected.
        Accepts the service data hashtables (Entra, IAM, Defender, Monitor, Network,
        Policy, Vm) and persists them to the azure_* tables via granular CRUD functions.

        Clears previous data for the provider before inserting (Remove + Save).
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER EntraData
        The Entra service data hashtable from Get-CIEMAzureEntraData.
    .PARAMETER IAMData
        The IAM service data hashtable from Get-CIEMAzureIAMData.
    .PARAMETER DefenderData
        The Defender service cache hashtable (keyed by subscription ID).
    .PARAMETER MonitorData
        The Monitor service cache hashtable (keyed by subscription ID).
    .PARAMETER NetworkData
        The Network service cache hashtable (keyed by subscription ID).
    .PARAMETER PolicyData
        The Policy service cache hashtable (keyed by subscription ID).
    .PARAMETER VmData
        The Vm service cache hashtable (keyed by subscription ID).
    .PARAMETER TenantId
        The Azure AD tenant ID (for context).
    .EXAMPLE
        Save-CIEMCollectedData -ProviderId 'azure' -EntraData $entraCache.CacheData -IAMData $iamCache.CacheData -DefenderData $defenderCache.CacheData
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Persists collected data to database')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter()]
        [hashtable]$EntraData,

        [Parameter()]
        [hashtable]$IAMData,

        [Parameter()]
        [hashtable]$DefenderData,

        [Parameter()]
        [hashtable]$MonitorData,

        [Parameter()]
        [hashtable]$NetworkData,

        [Parameter()]
        [hashtable]$PolicyData,

        [Parameter()]
        [hashtable]$VmData,

        [Parameter()]
        [string]$TenantId
    )

    $ErrorActionPreference = 'Stop'

    $dbPath = Get-CIEMDatabasePath
    if (-not $dbPath) {
        Write-Verbose "Save-CIEMCollectedData: No database path — skipping."
        return
    }

    # Clear previous collected data for this provider (leaf tables first).
    # CASCADE handles group_memberships and role_definition_permissions automatically.
    try {
        Remove-CIEMAzureAppRoleAssignment -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
        Remove-CIEMAzureDirectoryRoleAssignment -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
        Remove-CIEMAzureRoleAssignment -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
        Remove-CIEMAzureDenyAssignment -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
        Remove-CIEMAzureRoleDefinition -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
        Remove-CIEMAzureResource -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
        Remove-CIEMAzureSecurityPrincipal -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
        Remove-CIEMAzureServiceData -ProviderId $ProviderId -Confirm:$false -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Save-CIEMCollectedData: Failed to clear previous data: $($_.Exception.Message)"
    }

    # --- Entra Data ---
    try {
        if ($EntraData) {
            # Users → azure_security_principals
            if ($EntraData.Users) {
                foreach ($user in $EntraData.Users) {
                    Save-CIEMAzureSecurityPrincipal -Id $user.id -ProviderId $ProviderId -Type 'User' `
                        -DisplayName $user.displayName -Enabled ([bool]$user.accountEnabled) `
                        -Category 'Human' -PrincipalType 'User' `
                        -UserPrincipalName $user.userPrincipalName -UserType $user.userType
                }
            }

            # Groups → azure_security_principals
            if ($EntraData.Groups) {
                foreach ($group in $EntraData.Groups) {
                    Save-CIEMAzureSecurityPrincipal -Id $group.id -ProviderId $ProviderId -Type 'Group' `
                        -DisplayName $group.displayName -Enabled $true -Category 'Collection'
                }

                # Group memberships
                if ($EntraData.GroupMembers) {
                    foreach ($groupId in $EntraData.GroupMembers.Keys) {
                        $members = $EntraData.GroupMembers[$groupId]
                        if (-not $members) { continue }
                        foreach ($member in $members) {
                            $memberType = switch -Wildcard ($member.'@odata.type') {
                                '*user' { 'User' }
                                '*group' { 'Group' }
                                '*servicePrincipal' { 'ServicePrincipal' }
                                default { 'Unknown' }
                            }
                            # Ensure member exists as a principal (may be a nested group)
                            Save-CIEMAzureSecurityPrincipal -Id $member.id -ProviderId $ProviderId `
                                -Type $memberType -DisplayName $member.displayName `
                                -Enabled $true -Category 'Unknown'

                            Save-CIEMAzureGroupMembership -GroupId $groupId -MemberId $member.id -MemberType $memberType
                        }
                    }
                }
            }

            # Service Principals → azure_security_principals
            if ($EntraData.ServicePrincipals) {
                foreach ($sp in $EntraData.ServicePrincipals) {
                    Save-CIEMAzureSecurityPrincipal -Id $sp.id -ProviderId $ProviderId -Type 'ServicePrincipal' `
                        -DisplayName $sp.displayName -Enabled ([bool]$sp.accountEnabled) `
                        -Category 'Workload' -AppId $sp.appId -ServicePrincipalType $sp.servicePrincipalType
                }
            }

            # Applications → azure_security_principals (type='Application')
            if ($EntraData.Applications) {
                foreach ($app in $EntraData.Applications) {
                    Save-CIEMAzureSecurityPrincipal -Id $app.id -ProviderId $ProviderId -Type 'Application' `
                        -DisplayName $app.displayName -Enabled $true -Category 'Workload' -AppId $app.appId
                }
            }

            # Directory Role Assignments
            if ($EntraData.DirectoryRoles -and $EntraData.DirectoryRoleMembers) {
                foreach ($role in $EntraData.DirectoryRoles) {
                    $members = $EntraData.DirectoryRoleMembers[$role.id]
                    if (-not $members) { continue }
                    foreach ($member in $members) {
                        $assignmentId = "$($role.id)_$($member.id)"
                        Save-CIEMAzureDirectoryRoleAssignment -Id $assignmentId -ProviderId $ProviderId `
                            -PrincipalId $member.id -RoleName $role.displayName -RoleTemplateId $role.roleTemplateId
                    }
                }
            }

            # App Role Assignments
            if ($EntraData.AppRoleAssignments) {
                foreach ($spId in $EntraData.AppRoleAssignments.Keys) {
                    $assignments = $EntraData.AppRoleAssignments[$spId]
                    if (-not $assignments) { continue }
                    foreach ($assignment in $assignments) {
                        Save-CIEMAzureAppRoleAssignment -Id $assignment.id -ProviderId $ProviderId `
                            -PrincipalId $assignment.principalId -PrincipalType $assignment.principalType `
                            -ResourceId $assignment.resourceId -ResourceDisplayName $assignment.resourceDisplayName `
                            -AppRoleId $assignment.appRoleId -AppRoleValue $assignment.appRoleValue
                    }
                }
            }
        }

    } catch {
        Write-Warning "Save-CIEMCollectedData: Failed to persist Entra data: $($_.Exception.Message)"
    }

    # --- IAM Data (keyed by subscription) ---
    try {
        if ($IAMData) {
            foreach ($subscriptionId in $IAMData.Keys) {
                $subData = $IAMData[$subscriptionId]
                if (-not $subData) { continue }

                # Role Definitions
                if ($subData.RoleDefinitions) {
                    foreach ($roleDef in $subData.RoleDefinitions) {
                        $roleId = $roleDef.id
                        $props = $roleDef.properties
                        Save-CIEMAzureRoleDefinition -Id $roleId -ProviderId $ProviderId `
                            -RoleName $props.roleName -RoleType $props.type `
                            -Description $props.description `
                            -AssignableScopes ($props.assignableScopes | ConvertTo-Json -Compress)

                        # Role permissions
                        if ($props.permissions) {
                            foreach ($perm in $props.permissions) {
                                foreach ($action in @($perm.actions | Where-Object { $_ })) {
                                    Save-CIEMAzureRoleDefinitionPermission -RoleDefinitionId $roleId -ActionType 'action' -Action $action
                                }
                                foreach ($action in @($perm.notActions | Where-Object { $_ })) {
                                    Save-CIEMAzureRoleDefinitionPermission -RoleDefinitionId $roleId -ActionType 'notAction' -Action $action
                                }
                                foreach ($action in @($perm.dataActions | Where-Object { $_ })) {
                                    Save-CIEMAzureRoleDefinitionPermission -RoleDefinitionId $roleId -ActionType 'dataAction' -Action $action
                                }
                                foreach ($action in @($perm.notDataActions | Where-Object { $_ })) {
                                    Save-CIEMAzureRoleDefinitionPermission -RoleDefinitionId $roleId -ActionType 'notDataAction' -Action $action
                                }
                            }
                        }
                    }
                }

                # Role Assignments
                if ($subData.RoleAssignments) {
                    foreach ($ra in $subData.RoleAssignments) {
                        $props = $ra.properties
                        Save-CIEMAzureRoleAssignment -Id $ra.id -ProviderId $ProviderId `
                            -PrincipalId $props.principalId -PrincipalType $props.principalType `
                            -RoleDefinitionId $props.roleDefinitionId -Scope $props.scope `
                            -Condition $props.condition -ConditionVersion $props.conditionVersion `
                            -Description $props.description -CreatedOn $props.createdOn
                    }
                }
            }
        }

    } catch {
        Write-Warning "Save-CIEMCollectedData: Failed to persist IAM data: $($_.Exception.Message)"
    }

    # --- Defender Data (keyed by subscription) ---
    try {
        if ($DefenderData) {
            foreach ($subscriptionId in $DefenderData.Keys) {
                $sub = $DefenderData[$subscriptionId]
                if (-not $sub) { continue }

                # Pricings
                if ($sub.Pricings) {
                    foreach ($key in @($sub.Pricings.Keys)) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Defender' -ResourceType 'Pricing' `
                            -ResourceId $key -ResourceName $key -Data $sub.Pricings[$key]
                    }
                }

                # AutoProvisioningSettings
                if ($sub.AutoProvisioningSettings) {
                    foreach ($key in @($sub.AutoProvisioningSettings.Keys)) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Defender' -ResourceType 'AutoProvisioningSetting' `
                            -ResourceId $key -ResourceName $key -Data $sub.AutoProvisioningSettings[$key]
                    }
                }

                # Assessments
                if ($sub.Assessments) {
                    foreach ($key in @($sub.Assessments.Keys)) {
                        $a = $sub.Assessments[$key]
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Defender' -ResourceType 'Assessment' `
                            -ResourceId $a.ResourceId -ResourceName $key -Data $a
                    }
                }

                # Settings
                if ($sub.Settings) {
                    foreach ($key in @($sub.Settings.Keys)) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Defender' -ResourceType 'Setting' `
                            -ResourceId $key -ResourceName $key -Data $sub.Settings[$key]
                    }
                }

                # SecurityContacts
                if ($sub.SecurityContacts) {
                    foreach ($key in @($sub.SecurityContacts.Keys)) {
                        $c = $sub.SecurityContacts[$key]
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Defender' -ResourceType 'SecurityContact' `
                            -ResourceId $c.Id -ResourceName $c.Name -Data $c
                    }
                }
            }
        }

    } catch {
        Write-Warning "Save-CIEMCollectedData: Failed to persist Defender data: $($_.Exception.Message)"
    }

    # --- Monitor Data (keyed by subscription) ---
    try {
        if ($MonitorData) {
            foreach ($subscriptionId in $MonitorData.Keys) {
                $sub = $MonitorData[$subscriptionId]
                if (-not $sub) { continue }

                # AlertRules (array)
                if ($sub.AlertRules) {
                    foreach ($rule in $sub.AlertRules) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Monitor' -ResourceType 'AlertRule' `
                            -ResourceId $rule.id -ResourceName $rule.name -Data $rule
                    }
                }

                # DiagnosticSettings (array)
                if ($sub.DiagnosticSettings) {
                    foreach ($ds in $sub.DiagnosticSettings) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Monitor' -ResourceType 'DiagnosticSetting' `
                            -ResourceId $ds.id -ResourceName $ds.name -Data $ds
                    }
                }
            }
        }

    } catch {
        Write-Warning "Save-CIEMCollectedData: Failed to persist Monitor data: $($_.Exception.Message)"
    }

    # --- Network Data (keyed by subscription) ---
    try {
        if ($NetworkData) {
            foreach ($subscriptionId in $NetworkData.Keys) {
                $sub = $NetworkData[$subscriptionId]
                if (-not $sub) { continue }

                # NetworkSecurityGroups (array)
                if ($sub.NetworkSecurityGroups) {
                    foreach ($nsg in $sub.NetworkSecurityGroups) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Network' -ResourceType 'NetworkSecurityGroup' `
                            -ResourceId $nsg.id -ResourceName $nsg.name -Data $nsg
                    }
                }

                # PublicIpAddresses (array)
                if ($sub.PublicIpAddresses) {
                    foreach ($pip in $sub.PublicIpAddresses) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Network' -ResourceType 'PublicIpAddress' `
                            -ResourceId $pip.id -ResourceName $pip.name -Data $pip
                    }
                }

                # BastionHosts (array)
                if ($sub.BastionHosts) {
                    foreach ($bastion in $sub.BastionHosts) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Network' -ResourceType 'BastionHost' `
                            -ResourceId $bastion.id -ResourceName $bastion.name -Data $bastion
                    }
                }

                # NetworkWatchers (array)
                if ($sub.NetworkWatchers) {
                    foreach ($watcher in $sub.NetworkWatchers) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Network' -ResourceType 'NetworkWatcher' `
                            -ResourceId $watcher.id -ResourceName $watcher.name -Data $watcher
                    }
                }

                # FlowLogs (hashtable keyed by watcher name, each value is an array)
                if ($sub.FlowLogs) {
                    foreach ($watcherName in @($sub.FlowLogs.Keys)) {
                        $flowLogs = $sub.FlowLogs[$watcherName]
                        if (-not $flowLogs) { continue }
                        foreach ($flowLog in $flowLogs) {
                            Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                                -ServiceName 'Network' -ResourceType 'FlowLog' `
                                -ResourceId $flowLog.id -ResourceName $flowLog.name -Data $flowLog
                        }
                    }
                }
            }
        }

    } catch {
        Write-Warning "Save-CIEMCollectedData: Failed to persist Network data: $($_.Exception.Message)"
    }

    # --- Policy Data (keyed by subscription) ---
    try {
        if ($PolicyData) {
            foreach ($subscriptionId in $PolicyData.Keys) {
                $sub = $PolicyData[$subscriptionId]
                if (-not $sub) { continue }

                # PolicyAssignments (hashtable)
                if ($sub.PolicyAssignments) {
                    foreach ($key in @($sub.PolicyAssignments.Keys)) {
                        $pa = $sub.PolicyAssignments[$key]
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Policy' -ResourceType 'PolicyAssignment' `
                            -ResourceId $pa.Id -ResourceName $pa.Name -Data $pa
                    }
                }
            }
        }

    } catch {
        Write-Warning "Save-CIEMCollectedData: Failed to persist Policy data: $($_.Exception.Message)"
    }

    # --- Vm Data (keyed by subscription) ---
    try {
        if ($VmData) {
            foreach ($subscriptionId in $VmData.Keys) {
                $sub = $VmData[$subscriptionId]
                if (-not $sub) { continue }

                # VirtualMachines (array)
                if ($sub.VirtualMachines) {
                    foreach ($vm in $sub.VirtualMachines) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Vm' -ResourceType 'VirtualMachine' `
                            -ResourceId $vm.id -ResourceName $vm.name -Data $vm
                    }
                }

                # Disks (array)
                if ($sub.Disks) {
                    foreach ($disk in $sub.Disks) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Vm' -ResourceType 'Disk' `
                            -ResourceId $disk.id -ResourceName $disk.name -Data $disk
                    }
                }

                # VmScaleSets (array)
                if ($sub.VmScaleSets) {
                    foreach ($vmss in $sub.VmScaleSets) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Vm' -ResourceType 'VmScaleSet' `
                            -ResourceId $vmss.id -ResourceName $vmss.name -Data $vmss
                    }
                }

                # RecoveryVaults (array)
                if ($sub.RecoveryVaults) {
                    foreach ($vault in $sub.RecoveryVaults) {
                        Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                            -ServiceName 'Vm' -ResourceType 'RecoveryVault' `
                            -ResourceId $vault.id -ResourceName $vault.name -Data $vault
                    }
                }

                # BackupItems (hashtable keyed by vault name, each value is an array)
                if ($sub.BackupItems) {
                    foreach ($vaultName in @($sub.BackupItems.Keys)) {
                        $backupItems = $sub.BackupItems[$vaultName]
                        if (-not $backupItems) { continue }
                        foreach ($item in $backupItems) {
                            Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                                -ServiceName 'Vm' -ResourceType 'BackupItem' `
                                -ResourceId $item.id -ResourceName $item.name -Data $item
                        }
                    }
                }
            }
        }

    } catch {
        Write-Warning "Save-CIEMCollectedData: Failed to persist Vm data: $($_.Exception.Message)"
    }

    Write-Verbose "Save-CIEMCollectedData: Persisted collected data for provider '$ProviderId'"
}
