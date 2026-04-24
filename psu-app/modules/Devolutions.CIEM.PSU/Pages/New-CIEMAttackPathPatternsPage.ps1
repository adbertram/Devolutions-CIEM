function New-CIEMAttackPathPatternsPage {
    <#
    .SYNOPSIS
        Creates the Attack Path Patterns catalog page.
    .DESCRIPTION
        Renders a datagrid listing every attack path pattern the scan engine
        evaluates. Static data sourced from shipped JSON via
        Get-CIEMAttackPathPattern. Distinct from the Attack Paths page which
        shows discovered findings.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    # NOTE: $ErrorActionPreference = 'Stop' set above does NOT flow into
    # New-UDPage -Content scriptblocks — PSU invokes them later in a separate
    # runspace. The inner try/catch below is load-bearing.
    New-UDPage -Name 'Attack Path Patterns' -Url '/ciem/attack-path-patterns' -Content {
        New-UDTypography -Text 'Attack Path Patterns' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Catalog of attack path patterns the scan engine evaluates against the security graph' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; opacity = 0.7 }

        New-UDCard -Content {
            New-UDDynamic -Id 'attackPathPatternsPanel' -Content {
                try {
                    $patterns = @(Devolutions.CIEM\Get-CIEMAttackPathPattern)

                    if ($patterns.Count -eq 0) {
                        New-UDTypography -Text 'No attack path patterns found.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                    }
                    else {
                        New-UDDataGrid -LoadRows {
                            $rows = @(Devolutions.CIEM\Get-CIEMAttackPathPattern |
                                Sort-Object @{ Expression = { Devolutions.CIEM\Get-CIEMSeverityRank -Severity $_.Severity } }, Name |
                                ForEach-Object {
                                    @{
                                        id          = $_.Id
                                        name        = $_.Name
                                        severity    = $_.Severity
                                        category    = $_.Category
                                        description = $_.Description
                                        steps       = $_.StepCount
                                    }
                                })
                            @($rows) | Out-UDDataGridData -Context $EventData -TotalRows @($rows).Count
                        } -Columns @(
                            New-UDDataGridColumn -Field 'name' -HeaderName 'Name' -Flex 1
                            New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 130 -Render {
                                $color = Devolutions.CIEM\Get-SeverityColor -Severity $EventData.severity
                                New-UDChip -Label $EventData.severity -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                            }
                            New-UDDataGridColumn -Field 'category' -HeaderName 'Category' -Width 200
                            New-UDDataGridColumn -Field 'steps' -HeaderName 'Steps' -Width 90 -Type 'number'
                        ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -LoadDetailContent {
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '14px 18px'; display = 'grid'; gap = '14px' } } -Content {
                                New-UDElement -Tag 'section' -Content {
                                    New-UDTypography -Text 'Description' -Variant 'subtitle2' -Style @{ fontWeight = '600'; marginBottom = '6px' }
                                    New-UDElement -Tag 'pre' -Attributes @{
                                        'data-ciem-attack-path-pattern-description' = 'true'
                                        style = @{
                                            margin = '0'
                                            padding = '12px'
                                            border = '1px solid #d0d7de'
                                            borderRadius = '6px'
                                            backgroundColor = '#ffffff'
                                            whiteSpace = 'pre-wrap'
                                            overflowWrap = 'anywhere'
                                            fontFamily = 'inherit'
                                            fontSize = '14px'
                                            lineHeight = '1.45'
                                            maxHeight = '220px'
                                            overflow = 'auto'
                                        }
                                    } -Content {
                                        $EventData.row.description
                                    }
                                }
                            }
                        }
                    }
                }
                catch {
                    Devolutions.CIEM\Write-CIEMLog -Message "Attack Path Patterns page failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-AttackPathPatternsPage'
                    New-UDTypography -Text 'Unable to load attack path patterns.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
