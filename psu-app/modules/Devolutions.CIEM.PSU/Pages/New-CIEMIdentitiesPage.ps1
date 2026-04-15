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
                        New-UDSelectOption -Name 'AWS' -Value 'AWS'
                    } -DefaultValue $(if ($Session:IdentitiesProvider) { $Session:IdentitiesProvider } else { 'Azure' }) -OnChange {
                        $Session:IdentitiesProvider = $EventData
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
                    } -DefaultValue $(if ($Session:IdentitiesAccessLevel) { $Session:IdentitiesAccessLevel } else { 'All' }) -OnChange {
                        $Session:IdentitiesAccessLevel = $EventData
                        Sync-UDElement -Id 'identitiesGrid'
                    }
                }

                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'identitiesPrivilegedSelect' -Label 'Privilege' -Option {
                        New-UDSelectOption -Name 'All' -Value 'All'
                        New-UDSelectOption -Name 'Privileged Only' -Value 'Privileged'
                    } -DefaultValue $(if ($Session:IdentitiesPrivilege) { $Session:IdentitiesPrivilege } else { 'All' }) -OnChange {
                        $Session:IdentitiesPrivilege = $EventData
                        Sync-UDElement -Id 'identitiesGrid'
                    }
                }
            }
        }

        New-UDDynamic -Id 'identitiesGrid' -Content {
            try {
                $provider = if ($Session:IdentitiesProvider) { $Session:IdentitiesProvider } else { 'Azure' }
                $accessLevel = if ($Session:IdentitiesAccessLevel) { $Session:IdentitiesAccessLevel } else { 'All' }
                $privilege = if ($Session:IdentitiesPrivilege) { $Session:IdentitiesPrivilege } else { 'All' }

                $splat = @{ Provider = $provider; IncludeRaw = $true }
                if ($accessLevel -ne 'All') { $splat.AccessLevel = $accessLevel }
                if ($privilege -eq 'Privileged') { $splat.PrivilegedOnly = $true }

                $permissions = @(Devolutions.CIEM\Get-CIEMEffectivePermission @splat)

                if ($permissions.Count -eq 0) {
                    New-UDTypography -Text 'No identity permission data found. Run discovery to populate the local graph data first.' -Variant 'body2' -Style @{ opacity = 0.6; fontStyle = 'italic'; padding = '16px' }
                    return
                }

                $identityRiskByPrincipalId = @{}
                if ($provider -eq 'Azure') {
                    foreach ($summary in @(Devolutions.CIEM\Get-CIEMIdentityRiskSummary)) {
                        $identityRiskByPrincipalId[[string]$summary.Id] = $summary
                    }
                }

                New-UDDataGrid -LoadRows {
                    $rows = @($permissions | ForEach-Object {
                        $principalId = [string]$_.Principal.Id
                        $riskSummary = $null
                        if ($provider -eq 'Azure') {
                            if (-not $identityRiskByPrincipalId.ContainsKey($principalId)) {
                                throw "Identity risk summary not found for principal '$principalId'."
                            }
                            $riskSummary = $identityRiskByPrincipalId[$principalId]
                        }

                        $actionLabels = @($_.Actions | ForEach-Object { $_.Description }) -join ', '
                        $accessLevels = @($_.Actions | ForEach-Object { [string]$_.AccessLevel } | Select-Object -Unique) -join ', '
                        $effects = @($_.Actions | ForEach-Object { [string]$_.Effect } | Select-Object -Unique) -join ', '
                        $pathTypes = @($_.Path | ForEach-Object { [string]$_.Type } | Select-Object -Unique) -join ', '
                        $pathText = @($_.Path | ForEach-Object { $_.Description }) -join ' | '
                        $evidenceText = @($_.Evidence | ForEach-Object { "$($_.SourceSystem):$($_.SourceApi):$($_.SourceRecordId)" }) -join ' | '
                        $targetType = [string]$_.Target.Type

                        @{
                            id = "$($_.Provider)-$($_.Principal.Id)-$($_.Entitlement.Type)-$($_.Target.Id)-$($_.Entitlement.Id)"
                            provider = [string]$_.Provider
                            principalId = $principalId
                            principal = $_.Principal.DisplayName
                            principalType = [string]$_.Principal.Type
                            identityEntitlementCount = if ($riskSummary) { [int]$riskSummary.EntitlementCount } else { $null }
                            identityPrivilegedCount = if ($riskSummary) { [int]$riskSummary.PrivilegedCount } else { $null }
                            riskLevel = if ($riskSummary) { [string]$riskSummary.RiskLevel } else { 'Not available' }
                            lastActivity = if ($riskSummary -and $riskSummary.LastSignIn) { ([datetime]$riskSummary.LastSignIn).ToString('yyyy-MM-dd HH:mm') } else { 'None' }
                            actions = $actionLabels
                            accessLevel = $accessLevels
                            target = $_.Target.DisplayName
                            targetType = $targetType
                            targetIcon = Resolve-CIEMResourceIconDataUri -GraphKind $targetType -PropertiesJson $_.Target.PropertiesJson
                            scope = $_.Entitlement.ScopeId
                            entitlement = $_.Entitlement.Name
                            entitlementType = [string]$_.Entitlement.Type
                            pathType = $pathTypes
                            effect = $effects
                            privileged = if ($_.Privileged) { 'Yes' } else { 'No' }
                            path = $pathText
                            evidence = $evidenceText
                        }
                    })

                    @($rows) | Out-UDDataGridData -Context $EventData -TotalRows @($rows).Count
                } -Columns @(
                    New-UDDataGridColumn -Field 'provider' -HeaderName 'Provider' -Width 110
                    New-UDDataGridColumn -Field 'principal' -HeaderName 'Principal' -Flex 1
                    New-UDDataGridColumn -Field 'principalType' -HeaderName 'Type' -Width 150
                    New-UDDataGridColumn -Field 'identityEntitlementCount' -HeaderName 'Entitlements' -Width 130 -Type 'number'
                    New-UDDataGridColumn -Field 'identityPrivilegedCount' -HeaderName 'Privileged Roles' -Width 150 -Type 'number'
                    New-UDDataGridColumn -Field 'riskLevel' -HeaderName 'Risk Level' -Width 130 -Render {
                        if ($EventData.riskLevel -eq 'Not available') {
                            New-UDTypography -Text 'Not available' -Variant 'body2' -Style @{ opacity = 0.6 }
                        } else {
                            $color = Devolutions.CIEM\Get-SeverityColor -Severity $EventData.riskLevel
                            New-UDChip -Label $EventData.riskLevel -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                        }
                    }
                    New-UDDataGridColumn -Field 'lastActivity' -HeaderName 'Last Activity' -Width 160
                    New-UDDataGridColumn -Field 'actions' -HeaderName 'Can Do' -Flex 1
                    New-UDDataGridColumn -Field 'accessLevel' -HeaderName 'Access Level' -Width 150
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
                    New-UDDataGridColumn -Field 'scope' -HeaderName 'Scope' -Flex 1
                    New-UDDataGridColumn -Field 'entitlement' -HeaderName 'Entitlement' -Width 180
                    New-UDDataGridColumn -Field 'pathType' -HeaderName 'Path Type' -Width 160
                    New-UDDataGridColumn -Field 'effect' -HeaderName 'Effect' -Width 110
                    New-UDDataGridColumn -Field 'privileged' -HeaderName 'Privileged' -Width 120 -Render {
                        if ($EventData.privileged -eq 'Yes') {
                            New-UDChip -Label 'Yes' -Size 'small' -Style @{ backgroundColor = '#f44336'; color = 'white' }
                        } else {
                            New-UDTypography -Text 'No' -Variant 'body2' -Style @{ opacity = 0.6 }
                        }
                    }
                ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -LoadDetailContent {
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '8px 16px' } } -Content {
                        if ($EventData.row.provider -eq 'Azure') {
                            try {
                                $principalId = [string]$EventData.row.principalId
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

                        New-UDTypography -Text 'Entitlement Path' -Variant 'h6' -Style @{ marginBottom = '4px' }
                        New-UDTypography -Text $EventData.row.path -Variant 'body2' -Style @{ fontFamily = 'monospace'; marginBottom = '12px' }
                        New-UDTypography -Text 'Evidence' -Variant 'h6' -Style @{ marginBottom = '4px' }
                        New-UDTypography -Text $EventData.row.evidence -Variant 'body2' -Style @{ fontFamily = 'monospace'; opacity = 0.8 }
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
