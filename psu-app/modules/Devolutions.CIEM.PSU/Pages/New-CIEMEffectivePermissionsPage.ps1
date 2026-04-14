function New-CIEMEffectivePermissionsPage {
    <#
    .SYNOPSIS
        Creates the Effective Permissions page for provider-neutral entitlement exploration.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Effective Permissions' -Url '/ciem/effective-permissions' -Content {
        New-UDTypography -Text 'Effective Permissions' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Explore who can perform which effective actions on discovered resources' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; opacity = 0.7 }

        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'effectiveProviderSelect' -Label 'Provider' -Option {
                        New-UDSelectOption -Name 'Azure' -Value 'Azure'
                        New-UDSelectOption -Name 'AWS' -Value 'AWS'
                    } -DefaultValue $(if ($Session:EffectivePermissionsProvider) { $Session:EffectivePermissionsProvider } else { 'Azure' }) -OnChange {
                        $Session:EffectivePermissionsProvider = $EventData
                        Sync-UDElement -Id 'effectivePermissionsGrid'
                    }
                }

                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '220px' } } -Content {
                    New-UDSelect -Id 'effectiveAccessLevelSelect' -Label 'Access Level' -Option {
                        New-UDSelectOption -Name 'All' -Value 'All'
                        New-UDSelectOption -Name 'Read' -Value 'Read'
                        New-UDSelectOption -Name 'Write' -Value 'Write'
                        New-UDSelectOption -Name 'Manage' -Value 'Manage'
                        New-UDSelectOption -Name 'Permission Admin' -Value 'PermissionAdmin'
                        New-UDSelectOption -Name 'Data Access' -Value 'DataAccess'
                        New-UDSelectOption -Name 'Secret Access' -Value 'SecretAccess'
                        New-UDSelectOption -Name 'Assume Role' -Value 'AssumeRole'
                        New-UDSelectOption -Name 'Unclassified' -Value 'Unclassified'
                    } -DefaultValue $(if ($Session:EffectivePermissionsAccessLevel) { $Session:EffectivePermissionsAccessLevel } else { 'All' }) -OnChange {
                        $Session:EffectivePermissionsAccessLevel = $EventData
                        Sync-UDElement -Id 'effectivePermissionsGrid'
                    }
                }

                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'effectivePrivilegedSelect' -Label 'Privilege' -Option {
                        New-UDSelectOption -Name 'All' -Value 'All'
                        New-UDSelectOption -Name 'Privileged Only' -Value 'Privileged'
                    } -DefaultValue $(if ($Session:EffectivePermissionsPrivilege) { $Session:EffectivePermissionsPrivilege } else { 'All' }) -OnChange {
                        $Session:EffectivePermissionsPrivilege = $EventData
                        Sync-UDElement -Id 'effectivePermissionsGrid'
                    }
                }
            }
        }

        New-UDDynamic -Id 'effectivePermissionsGrid' -Content {
            try {
                $provider = if ($Session:EffectivePermissionsProvider) { $Session:EffectivePermissionsProvider } else { 'Azure' }
                $accessLevel = if ($Session:EffectivePermissionsAccessLevel) { $Session:EffectivePermissionsAccessLevel } else { 'All' }
                $privilege = if ($Session:EffectivePermissionsPrivilege) { $Session:EffectivePermissionsPrivilege } else { 'All' }

                $splat = @{ Provider = $provider; IncludeRaw = $true }
                if ($accessLevel -ne 'All') { $splat.AccessLevel = $accessLevel }
                if ($privilege -eq 'Privileged') { $splat.PrivilegedOnly = $true }

                $permissions = @(Devolutions.CIEM\Get-CIEMEffectivePermission @splat)

                if ($permissions.Count -eq 0) {
                    New-UDTypography -Text 'No effective permission data found. Run discovery to populate the local graph data first.' -Variant 'body2' -Style @{ opacity = 0.6; fontStyle = 'italic'; padding = '16px' }
                    return
                }

                New-UDDataGrid -LoadRows {
                    $rows = @($permissions | ForEach-Object {
                        $actionLabels = @($_.Actions | ForEach-Object { $_.NativeAction }) -join ', '
                        $accessLevels = @($_.Actions | ForEach-Object { [string]$_.AccessLevel } | Select-Object -Unique) -join ', '
                        $effects = @($_.Actions | ForEach-Object { [string]$_.Effect } | Select-Object -Unique) -join ', '
                        $pathTypes = @($_.Path | ForEach-Object { [string]$_.Type } | Select-Object -Unique) -join ', '
                        $pathText = @($_.Path | ForEach-Object { $_.Description }) -join ' | '
                        $evidenceText = @($_.Evidence | ForEach-Object { "$($_.SourceSystem):$($_.SourceApi):$($_.SourceRecordId)" }) -join ' | '

                        @{
                            id = "$($_.Provider)-$($_.Principal.Id)-$($_.Entitlement.Type)-$($_.Target.Id)-$($_.Entitlement.Id)"
                            provider = [string]$_.Provider
                            principal = $_.Principal.DisplayName
                            principalType = [string]$_.Principal.Type
                            actions = $actionLabels
                            accessLevel = $accessLevels
                            target = $_.Target.DisplayName
                            targetType = $_.Target.Type
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
                    New-UDDataGridColumn -Field 'actions' -HeaderName 'Can Do' -Flex 1
                    New-UDDataGridColumn -Field 'accessLevel' -HeaderName 'Access Level' -Width 150
                    New-UDDataGridColumn -Field 'target' -HeaderName 'Target Resource' -Flex 1
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
                        New-UDTypography -Text 'Entitlement Path' -Variant 'h6' -Style @{ marginBottom = '4px' }
                        New-UDTypography -Text $EventData.row.path -Variant 'body2' -Style @{ fontFamily = 'monospace'; marginBottom = '12px' }
                        New-UDTypography -Text 'Evidence' -Variant 'h6' -Style @{ marginBottom = '4px' }
                        New-UDTypography -Text $EventData.row.evidence -Variant 'body2' -Style @{ fontFamily = 'monospace'; opacity = 0.8 }
                    }
                }
            }
            catch {
                New-UDTypography -Text "Unable to load effective permissions: $($_.Exception.Message)" -Variant 'body2' -Style @{ color = '#f44336'; padding = '16px' }
            }
        } -LoadingComponent {
            New-UDProgress -Circular
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
