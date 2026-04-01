function New-CIEMIdentityRiskPage {
    <#
    .SYNOPSIS
        Creates the Identity Risk page with a data grid of identities and drill-down details.
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
        New-UDTypography -Text 'Drill down from identity towards entitlements and risk signals' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; opacity = 0.7 }

        New-UDCard -Content {
            New-UDDynamic -Id 'identityRiskPanel' -Content {

                try {
                    $hasData = (Invoke-CIEMQuery -Query 'SELECT COUNT(*) as c FROM graph_nodes WHERE kind IN (''EntraUser'',''EntraServicePrincipal'',''EntraManagedIdentity'',''EntraGroup'')').c -gt 0

                    if ($hasData) {
                        New-UDDataGrid -LoadRows {

                            $data = @(Get-CIEMIdentityRiskSummary)
                            $gridData = $data | ForEach-Object {
                                @{
                                    id               = $_.Id
                                    displayName      = $_.DisplayName
                                    principalType    = $_.PrincipalType
                                    entitlementCount = $_.EntitlementCount
                                    privilegedCount  = $_.PrivilegedCount
                                    riskLevel        = $_.RiskLevel
                                    lastActivity     = if ($_.LastSignIn) {
                                        ([datetime]$_.LastSignIn).ToString('yyyy-MM-dd HH:mm')
                                    } else { 'N/A' }
                                }
                            }
                            @($gridData) | Out-UDDataGridData -Context $EventData -TotalRows @($gridData).Count
                        } -Columns @(
                            New-UDDataGridColumn -Field 'displayName' -HeaderName 'Name' -Flex 1
                            New-UDDataGridColumn -Field 'principalType' -HeaderName 'Type' -Width 160 -Render {
                                $typeIcons = @{
                                    'User'             = 'User'
                                    'ServicePrincipal' = 'Robot'
                                    'ManagedIdentity'  = 'Key'
                                    'Group'            = 'Users'
                                }
                                $icon = $typeIcons[$EventData.principalType]
                                if (-not $icon) { $icon = 'QuestionCircle' }
                                New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                    New-UDIcon -Icon $icon -Size 'sm' -Style @{ opacity = 0.5; marginRight = '4px' }
                                    New-UDTypography -Text $EventData.principalType -Variant 'body2'
                                }
                            }
                            New-UDDataGridColumn -Field 'entitlementCount' -HeaderName 'Entitlements' -Width 130 -Type 'number'
                            New-UDDataGridColumn -Field 'privilegedCount' -HeaderName 'Privileged' -Width 120 -Type 'number' -Render {
                                $color = if ([int]$EventData.privilegedCount -gt 0) { '#f44336' } else { '#9e9e9e' }
                                New-UDChip -Label $EventData.privilegedCount -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                            }
                            New-UDDataGridColumn -Field 'riskLevel' -HeaderName 'Risk Level' -Width 130 -Render {
                                $color = Get-SeverityColor -Severity $EventData.riskLevel
                                New-UDChip -Label $EventData.riskLevel -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                            }
                            New-UDDataGridColumn -Field 'lastActivity' -HeaderName 'Last Activity' -Width 160
                        ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -LoadDetailContent {

                            $principalId = $EventData.row.id

                            try {
                                $details = Get-CIEMIdentityRiskSignals -PrincipalId $principalId

                                New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '8px 16px' } } -Content {

                                    # Hosting resource info for managed identities
                                    if ($details.HostingResource) {
                                        $hr = $details.HostingResource
                                        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                                            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                New-UDIcon -Icon 'Server' -Size 'sm' -Style @{ color = '#1976d2' }
                                                New-UDTypography -Text "Hosting Resource: $($hr.Name) ($($hr.Type))" -Variant 'subtitle2'
                                                if ($hr.HasPublicIP) {
                                                    New-UDChip -Label 'Public IP' -Size 'small' -Style @{ backgroundColor = '#f44336'; color = 'white' }
                                                }
                                            }
                                        }
                                    }

                                    # Sign-In Activity breakdown
                                    New-UDTypography -Text 'Sign-In Activity' -Variant 'h6' -Style @{ marginBottom = '4px' }
                                    $identity = $details.Identity
                                    $fmtInteractive = if ($identity.LastInteractiveSignIn) { ([datetime]$identity.LastInteractiveSignIn).ToString('yyyy-MM-dd HH:mm') } else { 'None' }
                                    $fmtNonInteractive = if ($identity.LastNonInteractiveSignIn) { ([datetime]$identity.LastNonInteractiveSignIn).ToString('yyyy-MM-dd HH:mm') } else { 'None' }
                                    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                                        New-UDTypography -Text "Interactive: $fmtInteractive" -Variant 'body2'
                                        New-UDTypography -Text "Non-Interactive: $fmtNonInteractive" -Variant 'body2'
                                    }
                                    New-UDDivider

                                    # Entitlements section
                                    New-UDTypography -Text 'Entitlements' -Variant 'h6' -Style @{ marginBottom = '4px' }

                                    $idx = 0
                                    $roleData = @($details.RoleAssignments | ForEach-Object {
                                        $idx++
                                        @{
                                            id            = "ra_$idx"
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

                                    # Risk Signals section
                                    New-UDDivider
                                    New-UDTypography -Text 'Risk Signals' -Variant 'h6' -Style @{ marginTop = '8px'; marginBottom = '4px' }

                                    if ($details.RiskSignals.Count -gt 0) {
                                        foreach ($signal in $details.RiskSignals) {
                                            $sevColor = Get-SeverityColor -Severity $signal.Severity
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

                                    # Attack Paths section
                                    New-UDDivider
                                    New-UDTypography -Text 'Attack Paths' -Variant 'h6' -Style @{ marginTop = '8px'; marginBottom = '4px' }

                                    New-UDDynamic -Content {
                                      try {
                                        $attackPaths = @(Get-CIEMAttackPath -PrincipalId $principalId)
                                        if ($attackPaths.Count -gt 0) {
                                            foreach ($ap in $attackPaths) {
                                                $apSevColor = Get-SeverityColor -Severity $ap.Severity
                                                $chainLabels = @($ap.Path | ForEach-Object {
                                                    $label = if ($_.display_name) { $_.display_name } else { $_.kind }
                                                    "$label ($($_.kind))"
                                                })
                                                $chainText = $chainLabels -join ' → '

                                                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                        New-UDChip -Label $ap.Severity -Size 'small' -Style @{ backgroundColor = $apSevColor; color = 'white' }
                                                        New-UDTypography -Text $ap.PatternName -Variant 'body1'
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
                                }
                            }
                            catch {
                                New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '20px'; textAlign = 'center' } } -Content {
                                    New-UDTypography -Text "Error loading identity details: $($_.Exception.Message)" -Variant 'body2' -Style @{ color = '#f44336' }
                                }
                            }
                        }
                    }
                    else {
                        New-UDTypography -Text 'No identity data available. Run Azure Discovery from the Environment page to collect identity data.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                    }
                }
                catch {
                    New-UDTypography -Text 'Unable to load identity risk data.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
