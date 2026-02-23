function Show-CIEMResourceGraphDiagram {
    <#
    .SYNOPSIS
        Renders the Mermaid diagram from cached data.
    .DESCRIPTION
        Called via [scriptblock]::Create() from the main page. Reads the cached
        Mermaid diagram string from PSU cache and renders it in an iframe.
    #>
    [CmdletBinding()]
    param()

    $cached = Get-PSUCache -Key 'CIEM:ResourceGraph:Latest' -ErrorAction SilentlyContinue
    if (-not $cached -or -not $cached.MermaidDiagram) {
        New-UDTypography -Text 'No resource graph available. Use the controls above to build one.' -Style @{ color = '#666'; padding = '20px'; textAlign = 'center' }
        return
    }

    if ($cached.NodeCount -eq 0) {
        New-UDTypography -Text 'Graph is empty (no resources found matching the query).' -Style @{ color = '#666'; padding = '20px'; textAlign = 'center' }
        return
    }

    try {
        # Render Mermaid in an iframe so the CDN script executes in its own document context
        # Pass diagram as JSON-encoded value read by JavaScript to prevent XSS injection
        $diagramJson = ($cached.MermaidDiagram | ConvertTo-Json -Compress)
        $iframeHtml = @"
<!DOCTYPE html>
<html><head>
<script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.3/dist/mermaid.min.js" integrity="sha384-R63zfMfSwJF4xCR11wXii+QUsbiBIdiDzDbtxia72oGWfkT7WHJfmD/I/eeHPJyT" crossorigin="anonymous"></script>
<style>body{margin:0;padding:16px;font-family:sans-serif;background:#fff;overflow:auto;} .mermaid{text-align:center;}</style>
</head><body>
<div class="mermaid" id="diagram"></div>
<script>
mermaid.initialize({startOnLoad:false,theme:'default',securityLevel:'strict'});
var diagramText = $diagramJson;
document.getElementById('diagram').textContent = diagramText;
mermaid.run({nodes:[document.getElementById('diagram')]});
</script>
</body></html>
"@
        $encodedHtml = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($iframeHtml))
        New-UDHtml -Markup "<iframe src='data:text/html;base64,$encodedHtml' style='width:100%;min-height:500px;border:1px solid #e0e0e0;border-radius:4px;' frameborder='0'></iframe>"
    }
    catch {
        New-CIEMErrorContent -Text 'Mermaid Rendering Error' -Details $_.Exception.Message
    }
}

function New-CIEMResourceGraphPage {
    <#
    .SYNOPSIS
        Creates the Resource Graph page for visualizing Azure resource dependencies as Mermaid diagrams.
    .DESCRIPTION
        Queries ARM resources via Azure Resource Graph (Search-AzGraph), builds a dependency
        graph using New-ResourceDependencyGraph, and renders it as an interactive Mermaid
        flowchart using New-UDMermaid from the UniversalDashboard.Mermaid module.

        Supported resource types are defined in the Devolutions.CIEM.ResourceGraph schema
        (17 types: VMs, NICs, Subnets, VNets, NSGs, Disks, KeyVaults, etc.).
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    New-UDPage -Name 'Resource Graph' -Url '/ciem/resourcegraph' -Content {
        try {
            Import-Module Devolutions.CIEM -ErrorAction Stop
            Import-Module Devolutions.CIEM.ResourceGraph -ErrorAction Stop
        }
        catch {
            New-UDCard -Content { New-UDTypography -Text "Failed to load required modules: $($_.Exception.Message)" -Style @{ color = '#f44336' } }
            return
        }

        New-UDTypography -Text 'Resource Dependency Graph' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Visualize Azure resource dependencies and relationships' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

        # Initialize session state defaults
        if (-not $Session:ResourceGraphDirection) { $Session:ResourceGraphDirection = 'TD' }

        # ── SECTION 1: Scan Controls ─────────────────────────────────────
        New-UDCard -Title 'Resource Scope' -Style @{ marginBottom = '20px' } -Content {

            New-UDGrid -Container -Spacing 2 -Content {

                # Subscription ID input
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 4 -Content {
                    New-UDTextbox -Id 'rgSubscriptionId' -Label 'Subscription ID (optional)' -Placeholder 'Leave blank for current subscription' -FullWidth
                }

                # Resource Group filter
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 4 -Content {
                    New-UDTextbox -Id 'rgResourceGroup' -Label 'Resource Group (optional)' -Placeholder 'Filter to a specific resource group' -FullWidth
                }

                # Direction selector
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 2 -Content {
                    New-UDSelect -Id 'rgDirection' -Label 'Layout Direction' -DefaultValue 'TD' -Option {
                        New-UDSelectOption -Name 'Top Down' -Value 'TD'
                        New-UDSelectOption -Name 'Left Right' -Value 'LR'
                        New-UDSelectOption -Name 'Bottom Top' -Value 'BT'
                        New-UDSelectOption -Name 'Right Left' -Value 'RL'
                    } -OnChange ([scriptblock]::Create(@"
                        `$Session:ResourceGraphDirection = `$EventData
                        Sync-UDElement -Id 'rgDiagramSection'
"@))
                }

                # Build Graph button
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 2 -Content {
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ paddingTop = '16px' } } -Content {
                        New-UDButton -Id 'buildGraphBtn' -Text 'Build Graph' -Variant 'contained' -Color 'primary' -FullWidth -ShowLoading -OnClick {
                            try {
                                # PSU dashboard runspaces don't load ScriptsToProcess classes — dot-source them explicitly
                                $rgModule = Get-Module Devolutions.CIEM.ResourceGraph -ListAvailable | Select-Object -First 1
                                if (-not $rgModule) { throw 'Devolutions.CIEM.ResourceGraph module not found. Ensure it is installed.' }
                                $classPath = Join-Path $rgModule.ModuleBase 'Classes/ResourceGraphClasses.ps1'
                                if (-not (Test-Path $classPath)) { throw "ResourceGraph class file not found at: $classPath" }
                                . $classPath
                                Write-CIEMLog -Message 'Build Graph button clicked' -Severity INFO -Component 'PSU-ResourceGraphPage'

                                # Disable button and show progress
                                Set-UDElement -Id 'buildGraphBtn' -Properties @{ disabled = $true }
                                Set-UDElement -Id 'rgProgressArea' -Content {
                                    New-CIEMProgressContent -Text 'Connecting to Azure...'
                                }
                                $connectResult = Connect-CIEM -Provider 'Azure'
                                $providerResult = $connectResult.Providers | Where-Object { $_.Provider -eq 'Azure' }
                                if (-not $providerResult -or $providerResult.Status -notin @('Connected', 'AlreadyConnected')) {
                                    $failMsg = if ($providerResult) { $providerResult.Message } else { 'No connection result returned' }
                                    throw "Azure connection failed: $failMsg"
                                }

                                $subscriptionIds = @($providerResult.SubscriptionIds)

                                # Read user inputs — override subscription scope if provided
                                $subscriptionId = (Get-UDElement -Id 'rgSubscriptionId').Value
                                $resourceGroup = (Get-UDElement -Id 'rgResourceGroup').Value
                                if ($subscriptionId) {
                                    $subscriptionIds = @($subscriptionId)
                                }

                                if ($subscriptionIds.Count -eq 0) {
                                    throw 'No accessible subscriptions found. Check your Azure provider configuration.'
                                }

                                # Query Azure Resource Graph for ARM resources
                                Set-UDElement -Id 'rgProgressArea' -Content {
                                    New-CIEMProgressContent -Text 'Querying Azure Resource Graph...'
                                }

                                $queryParams = @{ SubscriptionIds = $subscriptionIds }
                                if ($resourceGroup) { $queryParams['ResourceGroup'] = $resourceGroup }
                                $uniqueResources = Get-CIEMResourceGraphResources @queryParams

                                if ($uniqueResources.Count -eq 0) {
                                    Set-UDElement -Id 'rgProgressArea' -Content {
                                        New-CIEMInfoContent -Text 'No Resources Found' -Details 'No resources matching the supported types were found in the specified scope. Verify the subscription ID and resource group.'
                                    }
                                    Set-UDElement -Id 'buildGraphBtn' -Properties @{ disabled = $false }
                                    return
                                }

                                # Build dependency graph
                                Set-UDElement -Id 'rgProgressArea' -Content {
                                    New-CIEMProgressContent -Text "Building dependency graph from $($uniqueResources.Count) resources..."
                                }

                                $graph = New-ResourceDependencyGraph -Resources $uniqueResources
                                Write-CIEMLog -Message "Graph built: $($graph.Nodes.Count) nodes, $($graph.Edges.Count) edges" -Severity INFO -Component 'PSU-ResourceGraphPage'

                                # Pre-render and cache as plain hashtable (custom classes don't survive PSU cache serialization)
                                $direction = $Session:ResourceGraphDirection
                                if (-not $direction) { $direction = 'TD' }

                                $nodeCount = $graph.Nodes.Count
                                $edgeCount = $graph.Edges.Count
                                $mermaidDiagram = ConvertTo-MermaidDiagram -Graph $graph -Direction $direction
                                $cacheData = @{
                                    NodeCount      = $nodeCount
                                    EdgeCount      = $edgeCount
                                    MermaidDiagram = $mermaidDiagram
                                    BuildTime      = [datetime]::UtcNow
                                }
                                Set-PSUCache -Key 'CIEM:ResourceGraph:Latest' -Value $cacheData -Persist -ErrorAction SilentlyContinue

                                # Show success
                                $scopeDesc = if ($resourceGroup) { "resource group '$resourceGroup'" } elseif ($subscriptionId) { "subscription '$subscriptionId'" } else { 'current subscription' }
                                Set-UDElement -Id 'rgProgressArea' -Content {
                                    New-CIEMSuccessContent -Text 'Resource Graph Built' -Details "$nodeCount nodes, $edgeCount edges from $scopeDesc"
                                }

                                Show-UDToast -Message "Graph built: $nodeCount nodes, $edgeCount edges" -Duration 4000 -BackgroundColor '#4caf50'

                                # Refresh the diagram section
                                Sync-UDElement -Id 'rgDiagramSection'
                            }
                            catch {
                                Write-CIEMLog -Message "Resource graph build failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ResourceGraphPage'
                                Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ResourceGraphPage'

                                Set-UDElement -Id 'rgProgressArea' -Content {
                                    New-CIEMErrorContent -Text 'Graph Build Failed' -Details $_.Exception.Message
                                }

                                Show-UDToast -Message "Graph build failed: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                            }
                            finally {
                                Set-UDElement -Id 'buildGraphBtn' -Properties @{ disabled = $false }
                            }
                        }
                    }
                }
            }

            # Progress area (populated dynamically during build)
            New-UDElement -Tag 'div' -Id 'rgProgressArea' -Content {}
        }

        # ── SECTION 2: Mermaid Diagram ──────────────────────────────────
        New-UDCard -Title 'Dependency Diagram' -Style @{ marginBottom = '20px' } -Content {
            New-UDDynamic -Id 'rgDiagramSection' -Content ([scriptblock]::Create('Show-CIEMResourceGraphDiagram')) -LoadingComponent {
                New-UDProgress -Circular
            }
        }

    } -Navigation $Navigation -NavigationLayout permanent
}
