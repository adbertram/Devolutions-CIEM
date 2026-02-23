function Show-CIEMGraphIdentitySearch {
    <#
    .SYNOPSIS
        Renders the identity search autocomplete for a provider tab.
    .DESCRIPTION
        Separated into its own function because PSU does not preserve -ArgumentList
        across Sync-UDElement re-renders. Called via [scriptblock]::Create() with
        the provider name baked in as a literal parameter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [string]$IdPrefix = ''
    )

    $pfx = "${IdPrefix}${ProviderName}"

    $gData = Get-PSUCache -Key "CIEM:Graph:$ProviderName" -ErrorAction SilentlyContinue
    if (-not $gData) { return }

    $identityType = $Session:GraphState["IdentityType_$pfx"]
    if (-not $identityType) { $identityType = (Get-CIEMIdentity -Provider $ProviderName | Select-Object -First 1).GraphNodeType }
    $options = @(Get-CIEMGraphIdentityOptions -Data $gData -NodeType $identityType)

    $autocompleteOnChange = [scriptblock]::Create(@"
        if (`$EventData -match '\[([^\]]+)\]`$') {
            `$Session:GraphState['SelectedIdentityId_$pfx'] = `$Matches[1]
        }
"@)
    New-UDAutocomplete -Id "identitySearch_${pfx}_$identityType" -Label 'Search Identity' -Options $options -OnChange $autocompleteOnChange
}

function Show-CIEMGraphIdentityResults {
    <#
    .SYNOPSIS
        Renders identity access query results for a provider tab.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [string]$IdPrefix = ''
    )

    $pfx = "${IdPrefix}${ProviderName}"

    $identityId = $Session:GraphState["SelectedIdentityId_$pfx"]
    if (-not $identityId) {
        New-UDTypography -Text 'Select an identity and click Search to view access.' -Style @{ color = '#666'; padding = '20px'; textAlign = 'center' }
        return
    }

    $gData = Get-PSUCache -Key "CIEM:Graph:$ProviderName" -ErrorAction SilentlyContinue
    if (-not $gData) { return }

    $queryParams = @{ Data = $gData; IdentityId = $identityId }
    if ([bool]$Session:GraphState["ExpandGroups_$pfx"]) { $queryParams.ExpandGroups = $true }
    $queryResult = Invoke-CIEMIdentityAccessQuery @queryParams
    $results = @($queryResult.Results)

    if ($results.Count -eq 0) {
        New-UDTypography -Text 'No access found for this identity.' -Style @{ color = '#666'; padding = '20px'; textAlign = 'center' }
        return
    }

    New-UDTypography -Text "Access for: $($queryResult.IdentityName) ($($results.Count) entries)" -Variant 'subtitle2' -Style @{ marginBottom = '12px'; marginTop = '16px' }

    New-UDTable -Data $results -Columns @(
        New-UDTableColumn -Property 'Relationship' -Title 'Relationship' -Render {
            $rel = $EventData.Relationship
            $color = Get-CIEMRelationshipColor -Relationship $rel
            New-UDChip -Label $rel -Style @{ backgroundColor = $color; color = 'white' }
        }
        New-UDTableColumn -Property 'TargetType' -Title 'Target'
        New-UDTableColumn -Property 'Scopes' -Title 'Scopes' -Render {
            $scopes = $EventData.Scopes
            if ($scopes -is [array]) { ($scopes | Select-Object -First 3) -join '; ' } else { [string]$scopes }
        }
        New-UDTableColumn -Property 'IsDirect' -Title 'Source' -Render {
            if ($EventData.IsDirect) { 'Direct' } else { 'Inherited' }
        }
    ) -Paging -PageSize 10
}

function Show-CIEMGraphResourceDiagram {
    <#
    .SYNOPSIS
        Renders a Mermaid diagram of identities with access to a resource type.
    .DESCRIPTION
        Called via [scriptblock]::Create() when the user clicks Visualize.
        Builds the Mermaid diagram via ConvertTo-CIEMGraphMermaid and renders
        it in an iframe using the same pattern as the ResourceGraph page.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [string]$IdPrefix = ''
    )

    $pfx = "${IdPrefix}${ProviderName}"

    $gData = Get-PSUCache -Key "CIEM:Graph:$ProviderName" -ErrorAction SilentlyContinue
    if (-not $gData) {
        New-UDTypography -Text 'No graph data available.' -Style @{ color = '#666'; padding = '20px'; textAlign = 'center' }
        return
    }

    $resourceType = $Session:GraphState["ResourceType_$pfx"]
    if (-not $resourceType) { $resourceType = 'KeyVault' }

    try {
        $mermaidDiagram = ConvertTo-CIEMGraphMermaid -Data $gData -TargetType $resourceType

        # Render Mermaid in an iframe (same pattern as ResourceGraph page)
        $diagramJson = ($mermaidDiagram | ConvertTo-Json -Compress)
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
        New-UDTypography -Text "Diagram rendering error: $($_.Exception.Message)" -Style @{ color = '#f44336'; padding = '20px' }
    }
}

function Show-CIEMGraphResourceResults {
    <#
    .SYNOPSIS
        Renders resource access query results for a provider tab.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [string]$IdPrefix = ''
    )

    $pfx = "${IdPrefix}${ProviderName}"

    $resourceType = $Session:GraphState["ResourceType_$pfx"]
    if (-not $resourceType) { $resourceType = 'KeyVault' }

    $gData = Get-PSUCache -Key "CIEM:Graph:$ProviderName" -ErrorAction SilentlyContinue
    if (-not $gData) { return }

    $queryParams = @{ Data = $gData; TargetType = $resourceType }
    $permLevel = $Session:GraphState["PermissionLevel_$pfx"]
    if ($permLevel -and $permLevel -ne 'All') {
        $queryParams.Relationship = $permLevel
    }

    $results = @(Invoke-CIEMResourceAccessQuery @queryParams)

    if ($results.Count -eq 0) {
        New-UDTypography -Text "No identities found with access to $resourceType." -Style @{ color = '#666'; padding = '20px'; textAlign = 'center' }
        return
    }

    New-UDTypography -Text "$($results.Count) identities with access to $resourceType" -Variant 'subtitle2' -Style @{ marginBottom = '12px'; marginTop = '16px' }

    New-UDTable -Data $results -Columns @(
        New-UDTableColumn -Property 'IdentityName' -Title 'Identity'
        New-UDTableColumn -Property 'IdentityType' -Title 'Type' -Render {
            $type = $EventData.IdentityType -replace '^Entra', ''
            New-UDChip -Label $type -Size 'small'
        }
        New-UDTableColumn -Property 'Relationship' -Title 'Permission' -Render {
            $rel = $EventData.Relationship
            $color = Get-CIEMRelationshipColor -Relationship $rel
            New-UDChip -Label $rel -Style @{ backgroundColor = $color; color = 'white' }
        }
        New-UDTableColumn -Property 'Scopes' -Title 'Scopes' -Render {
            $scopes = $EventData.Scopes
            if ($scopes -is [array]) { ($scopes | Select-Object -First 3) -join '; ' } else { [string]$scopes }
        }
    ) -Paging -PageSize 10
}

function Show-CIEMGraphSummary {
    <#
    .SYNOPSIS
        Renders the graph summary section for a provider tab.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [string]$IdPrefix = ''
    )

    $gData = Get-PSUCache -Key "CIEM:Graph:$ProviderName" -ErrorAction SilentlyContinue
    if (-not $gData) { return }
    $s = Get-CIEMGraphSummary -Data $gData
    $buildTime = ([datetime]$s.BuildTime).ToString('yyyy-MM-dd HH:mm:ss') + ' UTC'

    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '16px' } } -Content {
        New-UDTypography -Text "Tenant: $($s.TenantId) | Built: $buildTime" -Variant 'caption' -Style @{ color = '#999' }
    }

    # Node counts by type — identity types from Get-CIEMIdentity, RBAC types fixed
    $identityColors = @{ 'Human' = '#1976d2'; 'Collection' = '#4caf50'; 'Workload' = '#ff9800' }
    $nodeTypes = [System.Collections.ArrayList]::new()
    foreach ($ident in (Get-CIEMIdentity -Provider $ProviderName | Where-Object { $_.Name -eq $_.GraphNodeType })) {
        $count = if ($s.NodeCounts.PSObject.Properties.Name -contains $ident.GraphNodeType) { $s.NodeCounts.($ident.GraphNodeType) } else { 0 }
        [void]$nodeTypes.Add(@{ Name = $ident.DisplayName + 's'; Count = $count; Color = $identityColors[$ident.Type] })
    }
    if ($s.NodeCounts.PSObject.Properties.Name -contains 'AzureRoleAssignment') {
        [void]$nodeTypes.Add(@{ Name = 'Role Assignments'; Count = $s.NodeCounts.AzureRoleAssignment; Color = '#f44336' })
    }
    if ($s.NodeCounts.PSObject.Properties.Name -contains 'AzureRoleDefinition') {
        [void]$nodeTypes.Add(@{ Name = 'Role Definitions'; Count = $s.NodeCounts.AzureRoleDefinition; Color = '#607d8b' })
    }

    New-UDTypography -Text 'Node Distribution' -Variant 'h6' -Style @{ marginBottom = '12px'; marginTop = '16px' }
    New-UDGrid -Container -Content {
        foreach ($nt in $nodeTypes) {
            $currentNt = $nt
            New-UDGrid -Item -ExtraSmallSize 6 -SmallSize 4 -MediumSize 2 -Content {
                New-UDCard -Content {
                    New-UDTypography -Text $currentNt.Count -Variant 'h4' -Style @{ color = $currentNt.Color; textAlign = 'center' }
                    New-UDTypography -Text $currentNt.Name -Variant 'caption' -Style @{ color = '#666'; textAlign = 'center' }
                } -Style @{ textAlign = 'center' }
            }
        }
    }

    # Edge breakdown by relationship type
    New-UDTypography -Text 'Relationship Distribution' -Variant 'h6' -Style @{ marginBottom = '12px'; marginTop = '24px' }
    $edgeData = @($s.EdgeCounts.GetEnumerator() | ForEach-Object {
        @{ Name = $_.Key; Count = $_.Value }
    })

    if ($edgeData.Count -gt 0) {
        New-UDCard -Content {
            New-UDChartJS -Type 'bar' -Data $edgeData -DataProperty Count -LabelProperty Name -BackgroundColor '#1976d2'
        }
    } else {
        New-UDTypography -Text 'No edges in graph.' -Style @{ color = '#666'; padding = '12px' }
    }

    # Largest groups by member count
    New-UDTypography -Text 'Largest Groups (by member count)' -Variant 'h6' -Style @{ marginBottom = '12px'; marginTop = '24px' }
    if ($s.LargestGroups.Count -gt 0) {
        New-UDTable -Data $s.LargestGroups -Columns @(
            New-UDTableColumn -Property 'GroupName' -Title 'Group'
            New-UDTableColumn -Property 'MemberCount' -Title 'Members'
        )
    } else {
        New-UDTypography -Text 'No group memberships found.' -Style @{ color = '#666'; padding = '12px' }
    }

    # Users in most groups
    New-UDTypography -Text 'Users in Most Groups' -Variant 'h6' -Style @{ marginBottom = '12px'; marginTop = '24px' }
    if ($s.UsersInMostGroups.Count -gt 0) {
        New-UDTable -Data $s.UsersInMostGroups -Columns @(
            New-UDTableColumn -Property 'UserName' -Title 'User'
            New-UDTableColumn -Property 'GroupCount' -Title 'Groups'
        )
    } else {
        New-UDTypography -Text 'No users with group memberships found.' -Style @{ color = '#666'; padding = '12px' }
    }
}

function New-CIEMGraphTabContent {
    <#
    .SYNOPSIS
        Renders the content for a single provider tab on the Identity Graph page.
    .DESCRIPTION
        Called from New-CIEMGraphPage via [scriptblock]::Create() to work around
        PSU's lack of variable capture in New-UDTab -Content blocks.

        All UDDynamic content and OnChange/OnClick handlers also use
        [scriptblock]::Create() with helper functions because:
        1. PSU event handlers run in separate runspaces (no parent variable capture)
        2. PSU does not preserve -ArgumentList across Sync-UDElement re-renders
    .PARAMETER ProviderName
        The cloud provider name (e.g., 'Azure', 'AWS'). Used for cache key lookups.
    .PARAMETER IdPrefix
        Optional prefix for PSU component IDs and session state keys to avoid collisions
        when the same provider appears in multiple tabs (e.g., individual + All).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderName,

        [string]$IdPrefix = ''
    )

    # Escape single quotes to prevent script injection in [scriptblock]::Create() strings
    $ProviderName = $ProviderName -replace "'", "''"
    $IdPrefix = $IdPrefix -replace "'", "''"

    # $pfx is used for all PSU component IDs and session state keys
    $pfx = "${IdPrefix}${ProviderName}"

    New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '16px' } } -Content {

        # ── SECTION 1: Identity Access ────────────────────────
        New-UDCard -Title 'Identity Access' -Style @{ marginBottom = '20px' } -Content {
            New-UDTypography -Text 'What can this identity access?' -Variant 'h6' -Style @{ marginBottom = '16px' }

            # Controls row
            New-UDGrid -Container -Spacing 2 -Content {
                # Identity type selector
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 3 -Content {
                    $identityTypes = @(Get-CIEMIdentity -Provider $ProviderName | Where-Object { $_.Name -eq $_.GraphNodeType })
                    $defaultIdentityType = ($identityTypes | Select-Object -First 1).GraphNodeType
                    New-UDSelect -Id "identityTypeSelect_$pfx" -Label 'Identity Type' -DefaultValue $defaultIdentityType -Option {
                        foreach ($ident in (Get-CIEMIdentity -Provider $ProviderName | Where-Object { $_.Name -eq $_.GraphNodeType })) {
                            New-UDSelectOption -Name $ident.DisplayName -Value $ident.GraphNodeType
                        }
                    } -OnChange ([scriptblock]::Create(@"
                        `$Session:GraphState['IdentityType_$pfx'] = `$EventData
                        `$Session:GraphState['SelectedIdentityId_$pfx'] = `$null
                        Sync-UDElement -Id 'identitySearchDynamic_$pfx'
"@))
                }

                # Identity search (autocomplete refreshes when type changes)
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 5 -Content {
                    New-UDDynamic -Id "identitySearchDynamic_$pfx" -Content ([scriptblock]::Create("Show-CIEMGraphIdentitySearch -ProviderName '$ProviderName' -IdPrefix '$IdPrefix'"))
                }

                # Expand groups toggle
                New-UDGrid -Item -ExtraSmallSize 6 -SmallSize 2 -Content {
                    New-UDStack -Direction 'row' -AlignItems 'center' -Spacing 1 -Content {
                        New-UDSwitch -Id "expandGroupsSwitch_$pfx" -OnChange ([scriptblock]::Create(@"
                            `$Session:GraphState['ExpandGroups_$pfx'] = `$EventData
"@))
                        New-UDTypography -Text 'Expand Groups' -Variant 'body2'
                    }
                }

                # Search button
                New-UDGrid -Item -ExtraSmallSize 6 -SmallSize 2 -Content {
                    New-UDButton -Text 'Search' -Variant 'contained' -Color 'primary' -OnClick ([scriptblock]::Create("Sync-UDElement -Id 'identityResults_$pfx'"))
                }
            }

            # Identity Results
            New-UDDynamic -Id "identityResults_$pfx" -Content ([scriptblock]::Create("Show-CIEMGraphIdentityResults -ProviderName '$ProviderName' -IdPrefix '$IdPrefix'")) -LoadingComponent {
                New-UDProgress -Circular
            }
        }

        # ── SECTION 2: Resource Access ────────────────────────
        New-UDCard -Title 'Resource Access' -Style @{ marginBottom = '20px' } -Content {
            New-UDTypography -Text 'Who can access this resource?' -Variant 'h6' -Style @{ marginBottom = '16px' }

            # Controls row
            New-UDGrid -Container -Spacing 2 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 4 -Content {
                    New-UDSelect -Id "resourceTypeSelect_$pfx" -Label 'Resource Type' -DefaultValue 'KeyVault' -Option {
                        foreach ($rt in (Get-CIEMResourceType -Provider 'Azure')) {
                            New-UDSelectOption -Name $rt.DisplayName -Value $rt.Name
                        }
                    } -OnChange ([scriptblock]::Create(@"
                        `$Session:GraphState['ResourceType_$pfx'] = `$EventData
"@))
                }
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 4 -Content {
                    New-UDSelect -Id "permissionLevelSelect_$pfx" -Label 'Permission Level' -DefaultValue 'All' -Option {
                        New-UDSelectOption -Name 'All' -Value 'All'
                        New-UDSelectOption -Name 'Can Read' -Value 'CAN_READ'
                        New-UDSelectOption -Name 'Can Write' -Value 'CAN_WRITE'
                        New-UDSelectOption -Name 'Can Manage' -Value 'CAN_MANAGE'
                    } -OnChange ([scriptblock]::Create(@"
                        `$Session:GraphState['PermissionLevel_$pfx'] = `$EventData
"@))
                }
                New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 4 -Content {
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ paddingTop = '16px'; display = 'flex'; gap = '8px' } } -Content {
                        New-UDButton -Text 'Search' -Variant 'contained' -Color 'primary' -OnClick ([scriptblock]::Create("Sync-UDElement -Id 'resourceResults_$pfx'"))
                        New-UDButton -Text 'Visualize' -Variant 'outlined' -Color 'primary' -OnClick ([scriptblock]::Create("Sync-UDElement -Id 'resourceDiagram_$pfx'"))
                    }
                }
            }

            # Resource Results
            New-UDDynamic -Id "resourceResults_$pfx" -Content ([scriptblock]::Create("Show-CIEMGraphResourceResults -ProviderName '$ProviderName' -IdPrefix '$IdPrefix'")) -LoadingComponent {
                New-UDProgress -Circular
            }

            # Mermaid Diagram (rendered on Visualize click)
            New-UDDynamic -Id "resourceDiagram_$pfx" -Content ([scriptblock]::Create("Show-CIEMGraphResourceDiagram -ProviderName '$ProviderName' -IdPrefix '$IdPrefix'")) -LoadingComponent {
                New-UDProgress -Circular
            }
        }

        # ── SECTION 3: Summary ────────────────────────────────
        New-UDCard -Title 'Summary' -Style @{ marginBottom = '20px' } -Content {
            New-UDDynamic -Content ([scriptblock]::Create("Show-CIEMGraphSummary -ProviderName '$ProviderName' -IdPrefix '$IdPrefix'")) -LoadingComponent {
                New-UDProgress -Circular
            }
        }
    }
}

function New-CIEMGraphAllProvidersContent {
    <#
    .SYNOPSIS
        Renders the All Providers tab showing each provider's sections stacked vertically.
    .PARAMETER Providers
        Comma-separated list of provider names with graph data available.
        Uses a flat string (not [string[]]) because PSU's [scriptblock]::Create()
        can only interpolate simple string literals into baked parameters.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Providers
    )

    $providerList = $Providers -split ','

    New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '16px' } } -Content {
        foreach ($provider in $providerList) {
            $currentProvider = ($provider.Trim()) -replace "'", "''"

            # Provider header
            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px'; marginTop = '16px' } } -Content {
                New-UDTypography -Text $currentProvider -Variant 'h5' -Style @{ color = '#1976d2'; borderBottom = '2px solid #1976d2'; paddingBottom = '8px' }
            }

            # Render the full tab content for this provider with 'all_' prefix to avoid ID collisions
            New-CIEMGraphTabContent -ProviderName $currentProvider -IdPrefix 'all_'
        }
    }
}

function New-CIEMGraphPage {
    <#
    .SYNOPSIS
        Creates the Identity Graph page for exploring identity-to-resource relationships.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    New-UDPage -Name 'Identity Graph' -Url '/ciem/graph' -Content {
        try {
            Import-Module Devolutions.CIEM -ErrorAction Stop
            Import-Module Devolutions.CIEM.Graph -ErrorAction Stop
        }
        catch {
            New-UDCard -Content { New-UDTypography -Text "Failed to load required modules: $($_.Exception.Message)" -Style @{ color = '#f44336' } }
            return
        }

        New-UDTypography -Text 'Identity Graph' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Explore identity-to-resource relationships and permissions' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

        # Clean up legacy single-provider cache key (one-time, tracked via PSU cache sentinel)
        if (-not (Get-PSUCache -Key 'CIEM:Graph:LegacyCleanupDone' -ErrorAction SilentlyContinue)) {
            Remove-PSUCache -Key 'CIEM:Graph:Latest' -ErrorAction SilentlyContinue
            Set-PSUCache -Key 'CIEM:Graph:LegacyCleanupDone' -Value $true -Persist -ErrorAction SilentlyContinue
        }

        # Discover which providers have graph data cached (dynamic — no hardcoded list)
        $enabledProviders = @(Get-CIEMProvider | Where-Object Enabled | Select-Object -ExpandProperty Name)
        $providerGraphData = [ordered]@{}
        foreach ($pName in $enabledProviders) {
            $pData = Get-PSUCache -Key "CIEM:Graph:$pName" -ErrorAction SilentlyContinue
            if ($pData) {
                $providerGraphData[$pName] = $pData
            }
        }

        if ($providerGraphData.Count -eq 0) {
            New-UDCard -Style @{ marginTop = '20px'; textAlign = 'center'; padding = '40px' } -Content {
                New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 3 -Content {
                    New-UDIcon -Icon 'ProjectDiagram' -Size '4x' -Style @{ color = '#1976d2'; marginBottom = '16px' }
                    New-UDTypography -Text 'No Identity Graph Available' -Variant 'h5' -Style @{ marginBottom = '8px' }
                    New-UDTypography -Text 'Run a security scan to build the identity relationship graph.' -Variant 'body1' -Style @{ color = '#666'; marginBottom = '24px' }
                    New-UDButton -Text 'Run a Scan' -Variant 'contained' -Color 'primary' -Size 'large' -OnClick {
                        Invoke-UDRedirect '/ciem/scan'
                    }
                }
            }
            return
        }

        # Initialize session state container
        if (-not $Session:GraphState) { $Session:GraphState = @{} }

        # Provider tabs - one tab per provider with all sections stacked vertically.
        # PSU does NOT capture parent-scope variables into New-UDTab -Content blocks,
        # and does NOT preserve -ArgumentList across Sync-UDElement re-renders.
        # All dynamic content and event handlers use [scriptblock]::Create() with
        # helper functions to bake provider names in as literal string parameters.
        $providerNames = @($providerGraphData.Keys)

        New-UDTabs -Tabs {
            # "All Providers" tab (always first)
            $allProvCsv = ($providerNames | ForEach-Object { $_ -replace "'", "''" }) -join ','
            New-UDTab -Text 'All Providers' -Content ([scriptblock]::Create("New-CIEMGraphAllProvidersContent -Providers '$allProvCsv'"))

            # Individual provider tabs
            foreach ($provEntry in $providerGraphData.GetEnumerator()) {
                $tabProvName = $provEntry.Key -replace "'", "''"

                # Initialize defaults for this provider in session state (both prefixed and unprefixed)
                foreach ($prefix in @('', 'all_')) {
                    $stateKey = "${prefix}${tabProvName}"
                    if (-not $Session:GraphState["IdentityType_$stateKey"]) {
                        $Session:GraphState["IdentityType_$stateKey"] = (Get-CIEMIdentity -Provider $tabProvName | Select-Object -First 1).GraphNodeType
                    }
                }

                New-UDTab -Text $tabProvName -Content ([scriptblock]::Create("New-CIEMGraphTabContent -ProviderName '$tabProvName'"))
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
