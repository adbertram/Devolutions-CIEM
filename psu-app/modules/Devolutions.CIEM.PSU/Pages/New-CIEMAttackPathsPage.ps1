function New-CIEMAttackPathsPage {
    <#
    .SYNOPSIS
        Creates the Attack Paths page with a data grid of discovered attack path findings.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Attack Paths' -Url '/ciem/attack-paths' -Content {
        New-UDTypography -Text 'Attack Paths' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Discovered attack paths evaluated against the security graph' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; opacity = 0.7 }

        New-UDCard -Content {
            New-UDDynamic -Id 'attackPathsPanel' -Content {

                try {
                    $hasData = (Devolutions.CIEM\Invoke-CIEMQuery -Query 'SELECT COUNT(*) as c FROM graph_nodes').c -gt 0

                    if ($hasData) {
                        New-UDDataGrid -LoadRows {

                            $findings = @(Devolutions.CIEM\Get-CIEMAttackPath)
                            $idx = 0
                            $gridData = $findings | ForEach-Object {
                                $idx++
                                $chainLabels = @($_.Path | ForEach-Object {
                                    $label = if ($_.display_name) { $_.display_name } else { $_.kind }
                                    "$label ($($_.kind))"
                                })
                                $chainText = $chainLabels -join ' → '

                                @{
                                    id          = "$($_.PatternId)-$idx"
                                    patternName = $_.PatternName
                                    severity    = $_.Severity
                                    category    = $_.Category
                                    pathChain   = $chainText
                                    steps       = @($_.Path).Count
                                }
                            }
                            @($gridData) | Out-UDDataGridData -Context $EventData -TotalRows @($gridData).Count
                        } -Columns @(
                            New-UDDataGridColumn -Field 'patternName' -HeaderName 'Pattern Name' -Flex 1
                            New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 130 -Render {
                                $color = Devolutions.CIEM\Get-SeverityColor -Severity $EventData.severity
                                New-UDChip -Label $EventData.severity -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                            }
                            New-UDDataGridColumn -Field 'category' -HeaderName 'Category' -Width 200
                            New-UDDataGridColumn -Field 'pathChain' -HeaderName 'Path Chain' -Flex 2 -Render {
                                New-UDTypography -Text $EventData.pathChain -Variant 'body2' -Style @{ fontFamily = 'monospace'; opacity = 0.8 }
                            }
                            New-UDDataGridColumn -Field 'steps' -HeaderName 'Steps' -Width 90 -Type 'number'
                        ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter
                    }
                    else {
                        New-UDTypography -Text 'No attack path data available. Run Azure Discovery from the Environment page to build the security graph.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                    }
                }
                catch {
                    New-UDTypography -Text 'Unable to load attack path data.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
