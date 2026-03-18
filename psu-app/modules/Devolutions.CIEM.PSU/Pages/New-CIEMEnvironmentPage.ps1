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

    New-UDPage -Name 'Environment' -Url '/ciem/environment' -Content {

        # Load ECharts community library from CDN
        New-UDHelmet -Tag 'script' -Attributes @{
            src  = 'https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js'
            type = 'text/javascript'
        }

        New-UDTypography -Text 'Environment Explorer' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Explore your cloud infrastructure hierarchy - expand and collapse nodes to navigate resources' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

        # Provider selector + Layout toggle + Load button
        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '200px' } } -Content {
                    New-UDSelect -Id 'envProviderSelect' -Label 'Provider' -Option {
                        New-UDSelectOption -Name 'Azure' -Value 'Azure'
                    } -DefaultValue 'Azure' -OnChange {
                        $Session:SelectedEnvProvider = $EventData
                    }
                }
                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '180px' } } -Content {
                    New-UDSelect -Id 'envOrientSelect' -Label 'Layout' -Option {
                        New-UDSelectOption -Name 'Left to Right' -Value 'LR'
                        New-UDSelectOption -Name 'Top to Bottom' -Value 'TB'
                    } -DefaultValue 'LR' -OnChange {
                        $Session:SelectedEnvOrient = $EventData
                    }
                }
                New-UDButton -Id 'startDiscoveryBtn' -Text 'Start Discovery' -Variant 'outlined' -Color 'secondary' -ShowLoading -OnClick {
                    try {
                        $provider = $Session:SelectedEnvProvider
                        if (-not $provider) { $provider = 'Azure' }

                        Write-CIEMLog -Message "Starting discovery from Environment page for provider: $provider" -Severity INFO -Component 'PSU-EnvironmentPage'

                        if ($provider -ne 'Azure') {
                            Show-UDToast -Message "Provider '$provider' is not yet supported for discovery." -Duration 5000 -BackgroundColor '#ff9800'
                            return
                        }

                        Show-UDToast -Message 'Starting Azure discovery...' -Duration 5000 -BackgroundColor '#2196f3'

                        $run = Invoke-CIEMJobWithProgress `
                            -ScriptName 'Devolutions.CIEM\Start-CIEMAzureDiscovery' `
                            -ProgressElementId 'envChartArea' `
                            -DisableElementIds @('startDiscoveryBtn', 'loadEnvBtn') `
                            -MaxPollSeconds 600

                        $status = $run.Status
                        $armCount = $run.ArmRowCount
                        $entraCount = $run.EntraRowCount

                        if ($status -eq 'Completed') {
                            Set-UDElement -Id 'envChartArea' -Content {
                                New-CIEMSuccessContent -Text "Discovery completed: $armCount ARM resources, $entraCount Entra resources" -Details 'Click "Load Environment" to visualize the hierarchy.'
                            }
                            Show-UDToast -Message "Discovery completed: $armCount ARM resources, $entraCount Entra resources" -Duration 8000 -BackgroundColor '#4caf50'
                        } elseif ($status -eq 'Partial') {
                            Set-UDElement -Id 'envChartArea' -Content {
                                New-CIEMInfoContent -Text "Discovery partially completed: $armCount ARM, $entraCount Entra (some warnings)" -Details 'Click "Load Environment" to visualize available data.'
                            }
                            Show-UDToast -Message "Discovery partially completed: $armCount ARM, $entraCount Entra (some warnings)" -Duration 8000 -BackgroundColor '#ff9800'
                        } else {
                            Set-UDElement -Id 'envChartArea' -Content {
                                New-CIEMErrorContent -Text "Discovery finished with status: $status" -Details 'No resources were collected. Check authentication and try again.'
                            }
                            Show-UDToast -Message "Discovery finished with status: $status" -Duration 8000 -BackgroundColor '#ff9800'
                        }
                    }
                    catch {
                        $errorMsg = $_.Exception.Message
                        Write-CIEMLog -Message "Discovery from Environment page failed: $errorMsg" -Severity ERROR -Component 'PSU-EnvironmentPage'
                        Set-UDElement -Id 'envChartArea' -Content {
                            New-CIEMErrorContent -Text 'Discovery Failed' -Details $errorMsg
                        }
                        Show-UDToast -Message "Discovery failed: $errorMsg" -Duration 8000 -BackgroundColor '#f44336'
                    }
                }
                New-UDButton -Id 'loadEnvBtn' -Text 'Load Environment' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                    try {
                        $provider = $Session:SelectedEnvProvider
                        if (-not $provider) { $provider = 'Azure' }
                        $orient = $Session:SelectedEnvOrient
                        if (-not $orient) { $orient = 'LR' }

                        Write-CIEMLog -Message "Loading environment tree for provider: $provider (orient: $orient)" -Severity INFO -Component 'PSU-EnvironmentPage'

                        if ($provider -ne 'Azure') {
                            Show-UDToast -Message "Provider '$provider' is not yet supported." -Duration 5000 -BackgroundColor '#ff9800'
                            return
                        }

                        # Fetch the ARM hierarchy (throws if no resources exist)
                        $hierarchy = @(Get-CIEMAzureArmHierarchy)

                        # Summary counts
                        $tenantCount = @($hierarchy | Where-Object { $_.NodeType -eq 'Tenant' }).Count
                        $subCount    = @($hierarchy | Where-Object { $_.NodeType -eq 'Subscription' }).Count
                        $rgCount     = @($hierarchy | Where-Object { $_.NodeType -eq 'ResourceGroup' }).Count
                        $resCount    = @($hierarchy | Where-Object { $_.NodeType -eq 'Resource' }).Count

                        Set-UDElement -Id 'envSummary' -Content {
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
                        $lookup = @{}
                        foreach ($node in $hierarchy) {
                            $nodeColor = switch ($node.NodeType) {
                                'Tenant'        { '#1565c0' }
                                'Subscription'  { '#2e7d32' }
                                'ResourceGroup' { '#e65100' }
                                'Resource'      { '#546e7a' }
                                default         { '#757575' }
                            }
                            $nodeSize = switch ($node.NodeType) {
                                'Tenant'        { 16 }
                                'Subscription'  { 14 }
                                'ResourceGroup' { 12 }
                                'Resource'      { 8 }
                                default         { 10 }
                            }

                            $tooltipParts = @($node.NodeType)
                            if ($node.NodeType -eq 'Resource' -and $node.Resource) {
                                $tooltipParts += $node.Resource.Type
                                if ($node.Resource.Location) { $tooltipParts += $node.Resource.Location }
                            }

                            $lookup[$node.NodeId] = @{
                                name       = $node.Label
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
                            @{
                                name       = 'Cloud Environment'
                                symbolSize = 18
                                itemStyle  = @{ color = '#37474f'; borderColor = '#37474f' }
                                children   = $roots
                            }
                        }

                        $treeJson = $treeRoot | ConvertTo-Json -Depth 20 -Compress

                        # Render the chart container
                        Set-UDElement -Id 'envChartArea' -Content {
                            New-UDCard -Content {
                                New-UDHtml -Markup '<div id="ciemEnvTreeContainer" style="width:100%;height:700px;"></div>'
                            }
                        }

                        # Render the ECharts tree via browser JavaScript
                        # NOTE: @"..."@ here-string interpolates $treeJson and $orient from PowerShell;
                        #       the JS code itself contains no $ variables so no false interpolation.
                        $js = @"
(function() {
    var attempts = 0;
    function tryRender() {
        if (typeof echarts === 'undefined') {
            attempts++;
            if (attempts < 30) { setTimeout(tryRender, 200); return; }
            console.error('CIEM: ECharts library failed to load from CDN');
            return;
        }
        var container = document.getElementById('ciemEnvTreeContainer');
        if (!container) {
            attempts++;
            if (attempts < 30) { setTimeout(tryRender, 200); return; }
            console.error('CIEM: Tree container element not found');
            return;
        }
        var existing = echarts.getInstanceByDom(container);
        if (existing) existing.dispose();
        var chart = echarts.init(container);
        var data = ${treeJson};
        var isLR = '$orient' === 'LR';
        chart.setOption({
            tooltip: {
                trigger: 'item',
                triggerOn: 'mousemove',
                confine: true,
                formatter: function(params) {
                    var d = params.data.value || {};
                    var lines = ['<b>' + params.name + '</b>'];
                    var parts = (d.tooltip || '').split('|');
                    for (var i = 0; i < parts.length; i++) {
                        if (parts[i]) lines.push(parts[i]);
                    }
                    return lines.join('<br/>');
                }
            },
            series: [{
                type: 'tree',
                data: [data],
                top: isLR ? '2%' : '8%',
                left: isLR ? '12%' : '2%',
                bottom: isLR ? '2%' : '20%',
                right: isLR ? '25%' : '2%',
                symbolSize: function(value, params) {
                    return params.data.symbolSize || 10;
                },
                orient: '$orient',
                label: {
                    position: isLR ? 'left' : 'top',
                    verticalAlign: 'middle',
                    align: isLR ? 'right' : 'center',
                    fontSize: 12,
                    fontFamily: '"Roboto","Helvetica","Arial",sans-serif',
                    color: '#333'
                },
                leaves: {
                    label: {
                        position: isLR ? 'right' : 'bottom',
                        verticalAlign: 'middle',
                        align: isLR ? 'left' : 'center'
                    }
                },
                lineStyle: {
                    color: '#ccc',
                    width: 1.5,
                    curveness: 0.5
                },
                emphasis: {
                    focus: 'descendant',
                    itemStyle: { borderWidth: 2 }
                },
                expandAndCollapse: true,
                initialTreeDepth: 2,
                animationDuration: 550,
                animationDurationUpdate: 750
            }]
        });
        window.addEventListener('resize', function() { chart.resize(); });
    }
    tryRender();
})();
"@
                        Invoke-UDJavaScript -JavaScript $js

                        Write-CIEMLog -Message "Environment tree rendered: $resCount resources, $subCount subs, $rgCount RGs" -Severity INFO -Component 'PSU-EnvironmentPage'
                        Show-UDToast -Message "Loaded $resCount resources across $subCount subscriptions" -Duration 5000 -BackgroundColor '#4caf50'
                    }
                    catch {
                        $errorMsg = $_.Exception.Message
                        Write-CIEMLog -Message "Environment load failed: $errorMsg" -Severity ERROR -Component 'PSU-EnvironmentPage'

                        if ($errorMsg -match 'No ARM resources found') {
                            Set-UDElement -Id 'envChartArea' -Content {
                                New-UDCard -Style @{ textAlign = 'center'; padding = '40px' } -Content {
                                    New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 3 -Content {
                                        New-UDIcon -Icon 'Database' -Size '3x' -Style @{ color = '#ff9800'; marginBottom = '16px' }
                                        New-UDTypography -Text 'No Resources Discovered' -Variant 'h5' -Style @{ marginBottom = '8px' }
                                        New-UDTypography -Text 'Run Azure discovery first to populate resource data, then return here to explore the hierarchy.' -Variant 'body1' -Style @{ color = '#666' }
                                    }
                                }
                            }
                            Show-UDToast -Message 'No ARM resources found. Run discovery first.' -Duration 5000 -BackgroundColor '#ff9800'
                        } else {
                            Set-UDElement -Id 'envChartArea' -Content {
                                New-CIEMErrorContent -Text 'Failed to Load Environment' -Details $errorMsg
                            }
                            Show-UDToast -Message "Error: $errorMsg" -Duration 8000 -BackgroundColor '#f44336'
                        }
                    }
                }
            }
        }

        # Summary area (populated after load)
        New-UDElement -Tag 'div' -Id 'envSummary' -Content {}

        # Chart area (initially shows empty state, replaced after load)
        New-UDElement -Tag 'div' -Id 'envChartArea' -Content {
            New-UDCard -Style @{ textAlign = 'center'; padding = '40px' } -Content {
                New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 3 -Content {
                    New-UDIcon -Icon 'SiteMap' -Size '4x' -Style @{ color = '#1976d2'; marginBottom = '16px' }
                    New-UDTypography -Text 'No Environment Data Loaded' -Variant 'h5' -Style @{ marginBottom = '8px' }
                    New-UDTypography -Text 'Select a provider and click "Load Environment" to visualize your cloud infrastructure hierarchy.' -Variant 'body1' -Style @{ color = '#666'; marginBottom = '24px' }
                }
            }
        }

    } -Navigation $Navigation -NavigationLayout permanent
}
