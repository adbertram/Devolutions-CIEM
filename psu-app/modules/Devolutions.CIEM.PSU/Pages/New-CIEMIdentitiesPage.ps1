function New-CIEMIdentitiesPage {
    <#
    .SYNOPSIS
        Creates the Identities page for provider-neutral entitlement exploration.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Identities' -Url '/ciem/identities' -Content {
        New-UDTypography -Text 'Identities' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Explore identities and the effective actions they can perform on discovered resources' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; opacity = 0.7 }

        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'identitiesProviderSelect' -Label 'Provider' -Option {
                        New-UDSelectOption -Name 'Azure' -Value 'Azure'
                    } -DefaultValue $(if ($Page:IdentitiesProvider) { $Page:IdentitiesProvider } else { 'Azure' }) -OnChange {
                        $Page:IdentitiesProvider = $EventData
                        Sync-UDElement -Id 'identitiesGrid'
                    }
                }

                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '220px' } } -Content {
                    New-UDSelect -Id 'identitiesAccessLevelSelect' -Label 'Access Level' -Option {
                        New-UDSelectOption -Name 'All' -Value 'All'
                        New-UDSelectOption -Name 'Read' -Value 'Read'
                        New-UDSelectOption -Name 'Write' -Value 'Write'
                        New-UDSelectOption -Name 'Manage' -Value 'Manage'
                        New-UDSelectOption -Name 'Permission Admin' -Value 'PermissionAdmin'
                        New-UDSelectOption -Name 'Data Access' -Value 'DataAccess'
                        New-UDSelectOption -Name 'Secret Access' -Value 'SecretAccess'
                        New-UDSelectOption -Name 'Assume Role' -Value 'AssumeRole'
                        New-UDSelectOption -Name 'Unclassified' -Value 'Unclassified'
                    } -DefaultValue $(if ($Page:IdentitiesAccessLevel) { $Page:IdentitiesAccessLevel } else { 'All' }) -OnChange {
                        $Page:IdentitiesAccessLevel = $EventData
                        Sync-UDElement -Id 'identitiesGrid'
                    }
                }

                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'identitiesPrivilegedSelect' -Label 'Privilege' -Option {
                        New-UDSelectOption -Name 'All' -Value 'All'
                        New-UDSelectOption -Name 'Privileged Only' -Value 'Privileged'
                    } -DefaultValue $(if ($Page:IdentitiesPrivilege) { $Page:IdentitiesPrivilege } else { 'All' }) -OnChange {
                        $Page:IdentitiesPrivilege = $EventData
                        Sync-UDElement -Id 'identitiesGrid'
                    }
                }
            }
        }

        New-UDDynamic -Id 'identitiesGrid' -Content {
            try {
                $provider = if ($Page:IdentitiesProvider) { $Page:IdentitiesProvider } else { 'Azure' }
                $accessLevel = if ($Page:IdentitiesAccessLevel) { $Page:IdentitiesAccessLevel } else { 'All' }
                $privilege = if ($Page:IdentitiesPrivilege) { $Page:IdentitiesPrivilege } else { 'All' }

                $splat = @{ Provider = $provider }
                if ($accessLevel -ne 'All') { $splat.AccessLevel = $accessLevel }
                if ($privilege -eq 'Privileged') { $splat.PrivilegedOnly = $true }

                $identities = @(Devolutions.CIEM\Get-CIEMIdentityAccessSummary @splat)

                if ($identities.Count -eq 0) {
                    New-UDTypography -Text 'No identity permission data found. Run discovery to populate the local graph data first.' -Variant 'body2' -Style @{ opacity = 0.6; fontStyle = 'italic'; padding = '16px' }
                    return
                }

                New-UDDataGrid -LoadRows {
                    $rows = @($identities | ForEach-Object {
                        @{
                            id = $_.Id
                            provider = [string]$_.Provider
                            principalId = [string]$_.PrincipalId
                            objectId = [string]$_.ObjectId
                            principal = [string]$_.Principal
                            principalType = [string]$_.PrincipalType
                            identityEntitlementCount = [int]$_.EntitlementCount
                            identityPrivilegedCount = [int]$_.PrivilegedRoleCount
                            effectivePermissionCount = [int]$_.EffectivePermissionCount
                            targetCount = [int]$_.TargetCount
                            riskLevel = [string]$_.RiskLevel
                            lastActivity = if ($_.LastActivity) { ([datetime]$_.LastActivity).ToString('yyyy-MM-dd HH:mm') } else { 'None' }
                            accessLevel = @($_.AccessLevels) -join ', '
                        }
                    })

                    @($rows) | Out-UDDataGridData -Context $EventData -TotalRows @($rows).Count
                } -Columns @(
                    New-UDDataGridColumn -Field 'provider' -HeaderName 'Provider' -Width 80
                    New-UDDataGridColumn -Field 'principal' -HeaderName 'Principal' -Flex 1
                    New-UDDataGridColumn -Field 'objectId' -HeaderName 'Object ID' -Width 240 -Render {
                        New-UDTypography -Text $EventData.objectId -Variant 'body2' -Style @{
                            fontFamily = 'monospace'
                            overflow = 'hidden'
                            textOverflow = 'ellipsis'
                            whiteSpace = 'nowrap'
                        }
                    }
                    New-UDDataGridColumn -Field 'principalType' -HeaderName 'Type' -Width 95
                    New-UDDataGridColumn -Field 'identityEntitlementCount' -HeaderName 'Entitlements' -Width 105 -Type 'number'
                    New-UDDataGridColumn -Field 'identityPrivilegedCount' -HeaderName 'Privileged Roles' -Width 120 -Type 'number'
                    New-UDDataGridColumn -Field 'riskLevel' -HeaderName 'Risk Level' -Width 100 -Render {
                        $color = Devolutions.CIEM\Get-SeverityColor -Severity $EventData.riskLevel
                        New-UDChip -Label $EventData.riskLevel -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                    }
                    New-UDDataGridColumn -Field 'lastActivity' -HeaderName 'Last Activity' -Width 125
                ) -AutoHeight $true -Pagination -PageSize 10 -ShowQuickFilter -LoadDetailContent {
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '8px 16px' } } -Content {
                        $principalId = [string]$EventData.row.principalId
                        $detailAccessLevel = if ($Page:IdentitiesAccessLevel) { $Page:IdentitiesAccessLevel } else { 'All' }
                        $detailPrivilege = if ($Page:IdentitiesPrivilege) { $Page:IdentitiesPrivilege } else { 'All' }
                        $detailSplat = @{
                            Provider = [string]$EventData.row.provider
                            PrincipalId = $principalId
                            IncludeRaw = $true
                        }
                        if ($detailAccessLevel -ne 'All') { $detailSplat.AccessLevel = $detailAccessLevel }
                        if ($detailPrivilege -eq 'Privileged') { $detailSplat.PrivilegedOnly = $true }

                        $targetPermissions = @(Devolutions.CIEM\Get-CIEMEffectivePermission @detailSplat)

                        New-UDTypography -Text "Object ID: $($EventData.row.objectId)" -Variant 'body2' -Style @{ fontFamily = 'monospace'; marginBottom = '8px'; opacity = 0.8 }
                        New-UDTypography -Text 'Target Access' -Variant 'h6' -Style @{ marginBottom = '4px' }

                        $targetAccessIndex = 0
                        $targetAccessRows = @($targetPermissions | ForEach-Object {
                            $targetAccessIndex++
                            $targetType = [string]$_.Target.Type
                            @{
                                id = "identity_target_access_$targetAccessIndex"
                                target = [string]$_.Target.DisplayName
                                targetType = $targetType
                                targetIcon = Resolve-CIEMResourceIconDataUri -GraphKind $targetType -PropertiesJson $_.Target.PropertiesJson
                                entitlement = [string]$_.Entitlement.Name
                                actions = @($_.Actions | ForEach-Object { $_.Description }) -join ', '
                                accessLevel = @($_.Actions | ForEach-Object { [string]$_.AccessLevel } | Select-Object -Unique) -join ', '
                                pathType = @($_.Path | ForEach-Object { [string]$_.Type } | Select-Object -Unique) -join ', '
                                privileged = if ($_.Privileged) { 'Yes' } else { 'No' }
                                evidence = @($_.Evidence | ForEach-Object { "$($_.SourceSystem):$($_.SourceApi):$($_.SourceRecordId)" }) -join ' | '
                            }
                        })

                        if ($targetAccessRows.Count -gt 0) {
                            New-UDDataGrid -LoadRows {
                                $targetAccessRows | Out-UDDataGridData -Context $EventData -TotalRows @($targetAccessRows).Count
                            } -Columns @(
                                New-UDDataGridColumn -Field 'target' -HeaderName 'Target Resource' -Flex 1 -Render {
                                    New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                        if ($EventData.targetIcon) {
                                            New-UDElement -Tag 'img' -Attributes @{
                                                src = $EventData.targetIcon
                                                alt = "$($EventData.targetType) icon"
                                                'data-ciem-resource-icon' = 'target'
                                                style = @{
                                                    width = '18px'
                                                    height = '18px'
                                                    flexShrink = '0'
                                                }
                                            }
                                        }
                                        New-UDTypography -Text $EventData.target -Variant 'body2' -Style @{
                                            overflow = 'hidden'
                                            textOverflow = 'ellipsis'
                                            whiteSpace = 'nowrap'
                                        }
                                    }
                                }
                                New-UDDataGridColumn -Field 'actions' -HeaderName 'Can Do' -Flex 1
                                New-UDDataGridColumn -Field 'accessLevel' -HeaderName 'Access Level' -Width 150
                                New-UDDataGridColumn -Field 'entitlement' -HeaderName 'Entitlement' -Width 180
                                New-UDDataGridColumn -Field 'pathType' -HeaderName 'Path Type' -Width 160
                                New-UDDataGridColumn -Field 'privileged' -HeaderName 'Privileged' -Width 110 -Render {
                                    if ($EventData.privileged -eq 'Yes') {
                                        New-UDChip -Label 'Yes' -Size 'small' -Style @{ backgroundColor = '#f44336'; color = 'white' }
                                    } else {
                                        New-UDTypography -Text 'No' -Variant 'body2' -Style @{ opacity = 0.6 }
                                    }
                                }
                                New-UDDataGridColumn -Field 'evidence' -HeaderName 'Evidence' -Flex 1
                            ) -AutoHeight $true -Pagination -PageSize 10
                        } else {
                            New-UDTypography -Text 'No target access found for this identity.' -Variant 'body2' -Style @{ opacity = 0.5; padding = '4px' }
                        }

                        New-UDDivider
                        if ($EventData.row.provider -eq 'Azure') {
                            try {
                                $details = Devolutions.CIEM\Get-CIEMIdentityRiskSignals -PrincipalId $principalId

                                if ($details.HostingResource) {
                                    $hostingResource = $details.HostingResource
                                    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                                        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                            New-UDIcon -Icon 'Server' -Size 'sm' -Style @{ color = '#1976d2' }
                                            New-UDTypography -Text "Hosting Resource: $($hostingResource.Name) ($($hostingResource.Type))" -Variant 'subtitle2'
                                            if ($hostingResource.HasPublicIP) {
                                                New-UDChip -Label 'Public IP' -Size 'small' -Style @{ backgroundColor = '#f44336'; color = 'white' }
                                            }
                                        }
                                    }
                                }

                                New-UDTypography -Text 'Sign-In Activity' -Variant 'h6' -Style @{ marginBottom = '4px' }
                                $identity = $details.Identity
                                $fmtInteractive = if ($identity.LastInteractiveSignIn) { ([datetime]$identity.LastInteractiveSignIn).ToString('yyyy-MM-dd HH:mm') } else { 'None' }
                                $fmtNonInteractive = if ($identity.LastNonInteractiveSignIn) { ([datetime]$identity.LastNonInteractiveSignIn).ToString('yyyy-MM-dd HH:mm') } else { 'None' }
                                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                                    New-UDTypography -Text "Interactive: $fmtInteractive" -Variant 'body2'
                                    New-UDTypography -Text "Non-Interactive: $fmtNonInteractive" -Variant 'body2'
                                }

                                New-UDDivider
                                New-UDTypography -Text 'Identity Entitlements' -Variant 'h6' -Style @{ marginBottom = '4px' }

                                $idx = 0
                                $roleData = @($details.RoleAssignments | ForEach-Object {
                                    $idx++
                                    @{
                                        id            = "identity_entitlement_$idx"
                                        roleName      = [string]$_.RoleName
                                        scope         = [string]$_.Scope
                                        isPrivileged  = if ($_.IsPrivileged) { 'Yes' } else { 'No' }
                                        inheritedFrom = if ($_.IsInherited) { [string]$_.InheritedFrom } else { 'Direct' }
                                    }
                                })

                                if ($roleData.Count -gt 0) {
                                    New-UDDataGrid -LoadRows {
                                        $roleData | Out-UDDataGridData -Context $EventData -TotalRows @($roleData).Count
                                    } -Columns @(
                                        New-UDDataGridColumn -Field 'roleName' -HeaderName 'Role' -Width 200
                                        New-UDDataGridColumn -Field 'scope' -HeaderName 'Scope' -Flex 1
                                        New-UDDataGridColumn -Field 'isPrivileged' -HeaderName 'Privileged' -Width 110 -Render {
                                            if ($EventData.isPrivileged -eq 'Yes') {
                                                New-UDChip -Label 'Yes' -Size 'small' -Style @{ backgroundColor = '#f44336'; color = 'white' }
                                            } else {
                                                New-UDTypography -Text 'No' -Variant 'body2' -Style @{ opacity = 0.5 }
                                            }
                                        }
                                        New-UDDataGridColumn -Field 'inheritedFrom' -HeaderName 'Inherited From' -Width 200
                                    ) -AutoHeight $true -Pagination -PageSize 10
                                } else {
                                    New-UDTypography -Text 'No role assignments found.' -Variant 'body2' -Style @{ opacity = 0.5; padding = '4px' }
                                }

                                New-UDDivider
                                New-UDTypography -Text 'Risk Signals' -Variant 'h6' -Style @{ marginTop = '8px'; marginBottom = '4px' }

                                if ($details.RiskSignals.Count -gt 0) {
                                    foreach ($signal in $details.RiskSignals) {
                                        $sevColor = Devolutions.CIEM\Get-SeverityColor -Severity $signal.Severity
                                        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '4px' } } -Content {
                                            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                New-UDChip -Label $signal.Severity -Size 'small' -Style @{ backgroundColor = $sevColor; color = 'white' }
                                                New-UDTypography -Text $signal.Description -Variant 'body1'
                                            }
                                        }
                                    }
                                } else {
                                    New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                        New-UDIcon -Icon 'CheckCircle' -Style @{ color = '#4caf50' }
                                        New-UDTypography -Text 'No risk signals detected.' -Variant 'body2' -Style @{ color = '#4caf50' }
                                    }
                                }

                                New-UDDivider
                                New-UDTypography -Text 'Attack Paths' -Variant 'h6' -Style @{ marginTop = '8px'; marginBottom = '4px' }

                                New-UDDynamic -Content {
                                    try {
                                        $attackPaths = @(Devolutions.CIEM\Get-CIEMAttackPath -PrincipalId $principalId)
                                        if ($attackPaths.Count -gt 0) {
                                            foreach ($attackPath in $attackPaths) {
                                                $attackPathSeverityColor = Devolutions.CIEM\Get-SeverityColor -Severity $attackPath.Severity
                                                $chainLabels = @($attackPath.Path | ForEach-Object {
                                                    $label = if ($_.display_name) { $_.display_name } else { $_.kind }
                                                    "$label ($($_.kind))"
                                                })
                                                $chainText = $chainLabels -join ' -> '

                                                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                        New-UDChip -Label $attackPath.Severity -Size 'small' -Style @{ backgroundColor = $attackPathSeverityColor; color = 'white' }
                                                        New-UDTypography -Text $attackPath.PatternName -Variant 'body1'
                                                    }
                                                    New-UDElement -Tag 'div' -Attributes @{ style = @{ paddingLeft = '40px'; marginTop = '2px' } } -Content {
                                                        New-UDTypography -Text $chainText -Variant 'body2' -Style @{ opacity = 0.7; fontFamily = 'monospace' }
                                                    }
                                                }
                                            }
                                        } else {
                                            New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                                New-UDIcon -Icon 'CheckCircle' -Style @{ color = '#4caf50' }
                                                New-UDTypography -Text 'No attack paths detected.' -Variant 'body2' -Style @{ color = '#4caf50' }
                                            }
                                        }
                                    } catch {
                                        New-UDTypography -Text "Unable to load attack paths: $($_.Exception.Message)" -Variant 'body2' -Style @{ color = '#f44336' }
                                    }
                                } -LoadingComponent {
                                    New-UDProgress -Circular -Size 'small'
                                }

                                New-UDDivider
                            }
                            catch {
                                New-UDTypography -Text "Unable to load identity risk context: $($_.Exception.Message)" -Variant 'body2' -Style @{ color = '#f44336'; marginBottom = '12px' }
                            }
                        }

                    }
                }
            }
            catch {
                New-UDTypography -Text "Unable to load identities: $($_.Exception.Message)" -Variant 'body2' -Style @{ color = '#f44336'; padding = '16px' }
            }
        } -LoadingComponent {
            New-UDProgress -Circular
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
