function New-CIEMEnvironmentPage {
    <#
    .SYNOPSIS
        Creates the Environment Explorer page with an interactive ARM hierarchy tree.
    .DESCRIPTION
        Renders a visual hierarchical diagram of the cloud environment using ECharts.
        Users select a provider (Azure), load the hierarchy, and interactively
        expand/collapse nodes to explore Tenant -> Subscription -> ResourceGroup -> Resource
        relationships.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Environment' -Url '/ciem/environment' -Content {

        Devolutions.CIEM\Write-CIEMLog -Message "Environment page Content block executing" -Severity INFO -Component 'PSU-EnvironmentPage'

        New-UDTypography -Text 'Environment Explorer' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Explore your cloud infrastructure hierarchy - expand and collapse nodes to navigate resources' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

        # Provider selector + Layout toggle + Discovery button
        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '200px' } } -Content {
                    New-UDSelect -Id 'envProviderSelect' -Label 'Provider' -Option {
                        New-UDSelectOption -Name 'Azure' -Value 'Azure'
                    } -DefaultValue 'Azure' -OnChange {
                        $Page:SelectedEnvProvider = $EventData
                    }
                }
                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'envViewSelect' -Label 'View' -Option {
                        New-UDSelectOption -Name 'Infrastructure' -Value 'Infrastructure'
                        New-UDSelectOption -Name 'Identities' -Value 'Identities'
                    } -DefaultValue 'Infrastructure' -OnChange {
                        $Page:SelectedEnvView = $EventData
                        Sync-UDElement -Id 'envChartDynamic'
                    }
                }
                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'envOrientSelect' -Label 'Layout' -Option {
                        New-UDSelectOption -Name 'Left to Right' -Value 'LR'
                        New-UDSelectOption -Name 'Top to Bottom' -Value 'TB'
                    } -DefaultValue 'LR' -OnChange {
                        $Page:SelectedEnvOrient = $EventData
                        Sync-UDElement -Id 'envChartDynamic'
                    }
                }
                New-UDButton -Id 'startDiscoveryBtn' -Text 'Start Discovery' -Variant 'outlined' -Color 'secondary' -ShowLoading -OnClick {
                    try {
                        $provider = $Page:SelectedEnvProvider
                        if (-not $provider) { $provider = 'Azure' }

                        Devolutions.CIEM\Write-CIEMLog -Message "DISCOVERY ONCLICK: entered handler, provider=$provider" -Severity INFO -Component 'PSU-EnvironmentPage'

                        if ($provider -ne 'Azure') {
                            Show-UDToast -Message "Provider '$provider' is not yet supported for discovery." -Duration 5000 -BackgroundColor '#ff9800'
                            return
                        }

                        Show-UDToast -Message 'Starting Azure discovery...' -Duration 5000 -BackgroundColor '#2196f3'

                        # Progress is shown by the auto-refresh status banner above — no ProgressElementId needed
                        $run = Devolutions.CIEM\Invoke-CIEMJobWithProgress `
                            -ScriptName 'Devolutions.CIEM\Start-CIEMAzureDiscovery' `
                            -DisableElementIds @('startDiscoveryBtn') `
                            -MaxPollSeconds 600

                        if (-not $run) {
                            Devolutions.CIEM\Write-CIEMLog -Message "DISCOVERY ONCLICK: Invoke-CIEMJobWithProgress returned null — job produced no pipeline output" -Severity WARNING -Component 'PSU-EnvironmentPage'
                            Sync-UDElement -Id 'envChartDynamic'
                            Show-UDToast -Message "Discovery completed but returned no output — check logs for warnings" -Duration 8000 -BackgroundColor '#ff9800'
                            return
                        }

                        Devolutions.CIEM\Write-CIEMLog -Message "DISCOVERY ONCLICK: Invoke-CIEMJobWithProgress returned, run type=$($run.GetType().Name), run=$($run | ConvertTo-Json -Depth 2 -Compress -ErrorAction SilentlyContinue)" -Severity INFO -Component 'PSU-EnvironmentPage'

                        $status = $run.Status
                        $armCount = $run.ArmRowCount
                        $entraCount = $run.EntraRowCount

                        Devolutions.CIEM\Write-CIEMLog -Message "DISCOVERY ONCLICK: parsed results — status=$status, arm=$armCount, entra=$entraCount" -Severity INFO -Component 'PSU-EnvironmentPage'

                        # Auto-reload the environment tree
                        Devolutions.CIEM\Write-CIEMLog -Message "DISCOVERY ONCLICK: calling Sync-UDElement envChartDynamic" -Severity INFO -Component 'PSU-EnvironmentPage'
                        Sync-UDElement -Id 'envChartDynamic'
                        Devolutions.CIEM\Write-CIEMLog -Message "DISCOVERY ONCLICK: Sync-UDElement returned" -Severity INFO -Component 'PSU-EnvironmentPage'

                        if ($status -eq 'Completed') {
                            Show-UDToast -Message "Discovery completed: $armCount ARM resources, $entraCount Entra resources" -Duration 8000 -BackgroundColor '#4caf50'
                        } elseif ($status -eq 'Partial') {
                            Show-UDToast -Message "Discovery partially completed: $armCount ARM, $entraCount Entra (some warnings)" -Duration 8000 -BackgroundColor '#ff9800'
                        } else {
                            Show-UDToast -Message "Discovery finished with status: $status" -Duration 8000 -BackgroundColor '#ff9800'
                        }
                    }
                    catch {
                        $errorMsg = $_.Exception.Message
                        Devolutions.CIEM\Write-CIEMLog -Message "Discovery from Environment page failed: $errorMsg" -Severity ERROR -Component 'PSU-EnvironmentPage'
                        Show-UDToast -Message "Discovery failed: $errorMsg" -Duration 8000 -BackgroundColor '#f44336'
                    }
                }
            }
        }

        # Discovery status banner — auto-refreshes to show running discovery with cancel button
        New-UDElement -Tag 'div' -Id 'envDiscoveryStatusBanner' -Content {
            New-UDDynamic -Id 'envDiscoveryStatusDynamic' -AutoRefresh -AutoRefreshInterval 5 -Content {
                $runningRuns = @(Devolutions.CIEM\Get-CIEMAzureDiscoveryRun -Status 'Running')
                if ($runningRuns.Count -gt 0) {
                    $run = $runningRuns[0]
                    $startedAt = $run.StartedAt
                    $elapsed = ''
                    if ($startedAt) {
                        try {
                            $startTime = [DateTimeOffset]::Parse($startedAt)
                            $duration = [DateTimeOffset]::UtcNow - $startTime
                            if ($duration.TotalMinutes -ge 1) {
                                $elapsed = " — started $([math]::Floor($duration.TotalMinutes)) min ago"
                            } else {
                                $elapsed = " — started $([math]::Floor($duration.TotalSeconds))s ago"
                            }
                        } catch {
                            # Ignore parse errors on started_at
                        }
                    }

                    New-UDCard -Style @{ marginTop = '8px'; marginBottom = '8px'; backgroundColor = '#e3f2fd'; border = '1px solid #90caf9' } -Content {
                        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -JustifyContent 'space-between' -Content {
                            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                New-UDProgress -Circular -Size 'small'
                                New-UDTypography -Text "Discovery in progress (Run #$($run.Id), Scope: $($run.Scope))$elapsed" -Variant 'body2' -Style @{ color = '#1565c0' }
                            }
                            New-UDButton -Id 'cancelDiscoveryBtn' -Text 'Cancel' -Variant 'outlined' -Color 'error' -Size 'small' -OnClick {
                                Devolutions.CIEM\Stop-CIEMAzureDiscovery
                                # Also cancel the CIEM discovery PSU script job.
                                $discoveryJobs = @(Get-PSUJob -Status 'Running' -Integrated | Where-Object { $_.Script -and $_.Script.Name -eq 'Devolutions.CIEM\Start-CIEMAzureDiscovery' })
                                foreach ($job in $discoveryJobs) {
                                    Stop-PSUJob -Job $job -Integrated
                                }
                                Show-UDToast -Message 'Discovery cancelled' -Duration 5000 -BackgroundColor '#ff9800'
                                Sync-UDElement -Id 'envDiscoveryStatusDynamic'
                            }
                        }
                    }
                }
            }
        }

        # Chart area — outer wrapper preserves #envChartArea for E2E selectors
        New-UDElement -Tag 'div' -Id 'envChartArea' -Content {
            New-UDDynamic -Id 'envChartDynamic' -LoadingComponent {
                New-UDCard -Style @{ textAlign = 'center'; padding = '40px' } -Content {
                    New-UDProgress -Circular
                    New-UDTypography -Text 'Loading environment data...' -Variant 'body1' -Style @{ marginTop = '16px'; color = '#666' }
                }
            } -Content {
                Devolutions.CIEM\Write-CIEMLog -Message "DYNAMIC CONTENT: envChartDynamic Content block entered" -Severity INFO -Component 'PSU-EnvironmentPage'
                $loadedModule = Get-Module 'Devolutions.CIEM' | Select-Object -First 1
                Devolutions.CIEM\Write-CIEMLog -Message "ENV PAGE: Loaded module version=$($loadedModule.Version), path=$($loadedModule.ModuleBase)" -Severity INFO -Component 'PSU-EnvironmentPage'
                Devolutions.CIEM\Write-CIEMLog -Message "ENV PAGE: DatabasePath=$script:DatabasePath" -Severity INFO -Component 'PSU-EnvironmentPage'
                Devolutions.CIEM\Write-CIEMLog -Message "ENV PAGE: ModuleRoot=$script:ModuleRoot" -Severity INFO -Component 'PSU-EnvironmentPage'
                try {
                    $orient = $Page:SelectedEnvOrient
                    if (-not $orient) { $orient = 'LR' }
                    $viewMode = $Page:SelectedEnvView
                    if (-not $viewMode) { $viewMode = 'Infrastructure' }

                    Devolutions.CIEM\Write-CIEMLog -Message "DYNAMIC CONTENT: view=$viewMode, orient=$orient" -Severity INFO -Component 'PSU-EnvironmentPage'

                    if ($viewMode -eq 'Identities') {
                        # --- Identity View ---
                        $assignmentMode = $Page:SelectedEnvAssignmentMode
                        if (-not $assignmentMode) { $assignmentMode = 'Effective' }

                        # Assignment mode sub-toggle
                        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '12px' } } -Content {
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '250px'; maxWidth = '300px' } } -Content {
                                New-UDSelect -Id 'envAssignmentModeSelect' -Label 'Assignment Mode' -Option {
                                    New-UDSelectOption -Name 'Effective (Group Expanded)' -Value 'Effective'
                                    New-UDSelectOption -Name 'Direct Only' -Value 'Direct'
                                } -DefaultValue $assignmentMode -OnChange {
                                    $Page:SelectedEnvAssignmentMode = $EventData
                                    Sync-UDElement -Id 'envChartDynamic'
                                }
                            }
                        }

                        Devolutions.CIEM\Write-CIEMLog -Message "DYNAMIC CONTENT: calling Get-CIEMAzureIdentityHierarchy (mode: $assignmentMode)" -Severity INFO -Component 'PSU-EnvironmentPage'
                        $hierarchy = @(Devolutions.CIEM\Get-CIEMAzureIdentityHierarchy -Mode $assignmentMode)
                        Devolutions.CIEM\Write-CIEMLog -Message "DYNAMIC CONTENT: got $($hierarchy.Count) identity hierarchy nodes" -Severity INFO -Component 'PSU-EnvironmentPage'

                        # Identity-specific summary counts
                        $identityCount = @($hierarchy | Where-Object { $_.NodeType -eq 'Identities' }).Count
                        $roleCount     = @($hierarchy | Where-Object { $_.NodeType -eq 'Role' }).Count
                        $scopeCount    = @($hierarchy | Where-Object { $_.NodeType -eq 'Scope' }).Count
                        $typeCount     = @($hierarchy | Where-Object { $_.NodeType -eq 'IdentityType' }).Count

                        New-UDCard -Style @{ marginBottom = '16px'; backgroundColor = '#f5f5f5' } -Content {
                            New-UDStack -Direction 'row' -Spacing 4 -AlignItems 'center' -Content {
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Identity Types' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$typeCount" -Variant 'h6' -Style @{ color = '#7b1fa2' }
                                }
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Identities' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$identityCount" -Variant 'h6' -Style @{ color = '#1565c0' }
                                }
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Roles' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$roleCount" -Variant 'h6' -Style @{ color = '#00838f' }
                                }
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Scopes' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$scopeCount" -Variant 'h6' -Style @{ color = '#558b2f' }
                                }
                            }
                        }
                    } else {
                        # --- Infrastructure View ---
                        Devolutions.CIEM\Write-CIEMLog -Message "DYNAMIC CONTENT: calling Get-CIEMAzureArmHierarchy (orient: $orient)" -Severity INFO -Component 'PSU-EnvironmentPage'

                        $hierarchy = @(Devolutions.CIEM\Get-CIEMAzureArmHierarchy)
                        Devolutions.CIEM\Write-CIEMLog -Message "DYNAMIC CONTENT: got $($hierarchy.Count) hierarchy nodes" -Severity INFO -Component 'PSU-EnvironmentPage'

                        # Summary counts
                        $tenantCount = @($hierarchy | Where-Object { $_.NodeType -eq 'Tenant' }).Count
                        $subCount    = @($hierarchy | Where-Object { $_.NodeType -eq 'Subscription' }).Count
                        $rgCount     = @($hierarchy | Where-Object { $_.NodeType -eq 'ResourceGroup' }).Count
                        $resCount    = @($hierarchy | Where-Object { $_.NodeType -eq 'Resource' }).Count

                        New-UDCard -Style @{ marginBottom = '16px'; backgroundColor = '#f5f5f5' } -Content {
                            New-UDStack -Direction 'row' -Spacing 4 -AlignItems 'center' -Content {
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Tenants' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$tenantCount" -Variant 'h6' -Style @{ color = '#1565c0' }
                                }
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Subscriptions' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$subCount" -Variant 'h6' -Style @{ color = '#2e7d32' }
                                }
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Resource Groups' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$rgCount" -Variant 'h6' -Style @{ color = '#e65100' }
                                }
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Resources' -Variant 'caption' -Style @{ color = '#666' }
                                    New-UDTypography -Text "$resCount" -Variant 'h6' -Style @{ color = '#546e7a' }
                                }
                            }
                        }
                    }

                    # --- Convert flat hierarchy to nested ECharts tree data ---

                    # Node type styling table (color, size)
                    $nodeStyles = @{
                        'Tenant'        = @{ Color = '#42a5f5'; Size = 32 }
                        'Subscription'  = @{ Color = '#66bb6a'; Size = 26 }
                        'ResourceGroup' = @{ Color = '#ffa726'; Size = 22 }
                        'Category'      = @{ Color = '#ab47bc'; Size = 22 }
                        'Resource'      = @{ Color = '#78909c'; Size = 16 }
                    }
                    # Identity view node types
                    $nodeStyles['IdentityType'] = @{ Color = '#7b1fa2'; Size = 26 }
                    $nodeStyles['Identities']     = @{ Color = '#1565c0'; Size = 22 }
                    $nodeStyles['Role']         = @{ Color = '#00838f'; Size = 20 }
                    $nodeStyles['Scope']        = @{ Color = '#558b2f'; Size = 16 }

                    $defaultStyle = @{ Color = '#bdbdbd'; Size = 18 }

                    $nodeById = @{}
                    foreach ($node in $hierarchy) {
                        $nodeById[$node.NodeId] = $node
                    }
                    $lookup = @{}
                    foreach ($node in $hierarchy) {
                        $style = $nodeStyles[$node.NodeType] ?? $defaultStyle
                        $nodeColor = $style.Color
                        $nodeSize  = $style.Size

                        $resType = if ($node.ResourceType) { $node.ResourceType } elseif ($node.Resource) { $node.Resource.Type } else { $null }
                        $entraType = $null
                        if ($viewMode -eq 'Identities') {
                            $identityTypeLabel = $null
                            if ($node.NodeType -eq 'IdentityType') {
                                $identityTypeLabel = $node.Label
                            } elseif ($node.NodeType -eq 'Identities' -and $node.ParentNodeId -and $nodeById.ContainsKey($node.ParentNodeId)) {
                                $identityTypeLabel = $nodeById[$node.ParentNodeId].Label
                            }
                            if ($identityTypeLabel) {
                                $identityTypeName = $identityTypeLabel -replace '\s+\(\d+\)$', ''
                                $entraType = switch ($identityTypeName) {
                                    'User' { 'user' }
                                    'Group' { 'group' }
                                    'ServicePrincipal' { 'servicePrincipal' }
                                    'ManagedIdentity' { 'ManagedIdentity' }
                                    default { $null }
                                }
                            }
                        }
                        $nodeIcon = Resolve-CIEMResourceIconDataUri -NodeType ([string]$node.NodeType) -AzureResourceType $resType -EntraType $entraType

                        $tooltipParts = @($node.NodeType)
                        if ($node.NodeType -eq 'Resource' -and $node.Resource) {
                            $tooltipParts += $node.Resource.Type
                            if ($node.Resource.Location) { $tooltipParts += $node.Resource.Location }
                        }

                        $lookup[$node.NodeId] = @{
                            name       = [string]$node.Label
                            symbol     = "image://$nodeIcon"
                            symbolKeepAspect = $true
                            value      = @{
                                nodeType = $node.NodeType
                                tooltip  = ($tooltipParts -join '|')
                            }
                            symbolSize = $nodeSize
                            itemStyle  = @{ color = $nodeColor; borderColor = $nodeColor }
                            children   = [System.Collections.Generic.List[object]]::new()
                        }
                    }

                    $roots = [System.Collections.Generic.List[object]]::new()
                    foreach ($node in $hierarchy) {
                        $entry = $lookup[$node.NodeId]
                        if ($node.ParentNodeId -and $lookup.ContainsKey($node.ParentNodeId)) {
                            $lookup[$node.ParentNodeId].children.Add($entry)
                        } else {
                            $roots.Add($entry)
                        }
                    }

                    $treeRoot = if ($roots.Count -eq 1) { $roots[0] } else {
                        $rootIcon = Resolve-CIEMResourceIconDataUri -GraphKind 'AzureResource'
                        @{
                            name       = 'Cloud Environment'
                            symbol     = "image://$rootIcon"
                            symbolKeepAspect = $true
                            symbolSize = 34
                            itemStyle  = @{ color = '#90a4ae'; borderColor = '#90a4ae' }
                            children   = $roots
                        }
                    }

                    # Render the chart through the CIEM PSU custom component.
                    New-UDCard -Content {
                        New-CIEMEnvironmentTree -Id 'ciemEnvTreeContainer' -Data $treeRoot -Orientation $orient -Height 700
                    }

                    Devolutions.CIEM\Write-CIEMLog -Message "Environment tree rendered: view=$viewMode, orient=$orient" -Severity INFO -Component 'PSU-EnvironmentPage'
                }
                catch {
                    $errorMsg = $_.Exception.Message
                    Devolutions.CIEM\Write-CIEMLog -Message "Environment auto-load failed: $errorMsg" -Severity ERROR -Component 'PSU-EnvironmentPage'

                    if ($errorMsg -match 'No ARM resources found' -or $errorMsg -match 'No effective role assignments' -or $errorMsg -match 'No role assignment resources' -or $errorMsg -match 'No valid role assignment') {
                        New-UDCard -Style @{ textAlign = 'center'; padding = '40px' } -Content {
                            New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 3 -Content {
                                New-UDIcon -Icon 'Database' -Size '3x' -Style @{ color = '#ff9800'; marginBottom = '16px' }
                                New-UDTypography -Text 'No Data Discovered' -Variant 'h5' -Style @{ marginBottom = '8px' }
                                New-UDTypography -Text 'Run Azure discovery first to populate resource and identity data, then return here to explore.' -Variant 'body1' -Style @{ color = '#666' }
                            }
                        }
                    } else {
                        Devolutions.CIEM\New-CIEMErrorContent -Text 'Failed to Load Environment' -Details $errorMsg
                    }
                }
            }
        }

    } -Navigation $Navigation -NavigationLayout permanent
}
