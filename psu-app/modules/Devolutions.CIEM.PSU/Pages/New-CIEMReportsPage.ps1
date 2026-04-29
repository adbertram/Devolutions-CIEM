function New-CIEMReportsPage {
    <#
    .SYNOPSIS
        Creates the Reports page with registered CIEM report definitions.
    .DESCRIPTION
        Renders the report registry exposed by Get-CIEMReport so users can see
        available report workflows from the CIEM sidebar.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Reports' -Url '/ciem/reports' -Content {
        New-UDTypography -Text 'Reports' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Available CIEM reports and evidence views' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; opacity = 0.7 }

        New-UDCard -Content {
            New-UDDynamic -Id 'ciemReportsPanel' -Content {
                try {
                    $reports = @(Devolutions.CIEM\Get-CIEMReport | Sort-Object Provider, Category, Title)

                    if ($reports.Count -eq 0) {
                        New-UDTypography -Text 'No CIEM reports are registered.' -Variant 'body2' -Style @{ opacity = 0.5; fontStyle = 'italic'; padding = '16px' }
                    }
                    else {
                        $selectedReport = $reports[0]
                        $registryRows = @(
                            foreach ($report in $reports) {
                                [pscustomobject]@{
                                    Title       = $report.Title
                                    Provider    = $report.Provider
                                    Category    = $report.Category
                                    Description = $report.Description
                                }
                            }
                        )

                        New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-reports-table' = 'true'; style = @{ marginBottom = '18px' } } -Content {
                            New-UDTable -Data $registryRows -Columns @(
                                New-UDTableColumn -Property 'Title' -Title 'Report'
                                New-UDTableColumn -Property 'Provider' -Title 'Provider'
                                New-UDTableColumn -Property 'Category' -Title 'Category'
                                New-UDTableColumn -Property 'Description' -Title 'Description'
                            )
                        }

                        $result = Devolutions.CIEM\Invoke-CIEMReport -Id $selectedReport.Id
                        $reportRows = @($result.Rows)
                        $tableRows = @(
                            foreach ($row in $reportRows) {
                                $tableRow = [ordered]@{}
                                foreach ($column in $result.Columns) {
                                    $property = $row.PSObject.Properties[$column]
                                    if (-not $property) {
                                        throw "CIEM report '$($result.ReportId)' row is missing configured column '$column'."
                                    }
                                    $tableRow[$column] = $property.Value
                                }
                                [pscustomobject]$tableRow
                            }
                        )

                        New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-result' = 'true'; style = @{ display = 'grid'; gap = '14px' } } -Content {
                            New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-context' = 'true' } -Content {
                                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                    New-UDTypography -Text $result.Title -Variant 'h5'
                                    New-UDChip -Label "Run #$($result.Context.RunId)" -Size 'small' -Variant 'outlined'
                                    New-UDChip -Label "Scope $($result.Context.Scope)" -Size 'small' -Variant 'outlined'
                                    New-UDChip -Label "Status $($result.Context.Status)" -Size 'small' -Variant 'outlined'
                                    New-UDChip -Label "Generated $($result.GeneratedAt.ToString('yyyy-MM-dd HH:mm')) UTC" -Size 'small' -Variant 'outlined'
                                }
                            }

                            New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-summary' = 'true' } -Content {
                                New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                    foreach ($summary in @($selectedReport.StatusSummary)) {
                                        $status = [string]$summary.status
                                        $count = @($reportRows | Where-Object { $_.Status -eq $status }).Count
                                        New-UDChip -Label "$status $count" -Size 'small' -Style @{ backgroundColor = [string]$summary.color; color = 'white' }
                                    }
                                }
                            }

                            if ($tableRows.Count -eq 0) {
                                New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-result-table' = 'true' } -Content {
                                    New-UDTypography -Text $selectedReport.EmptyState -Variant 'body2' -Style @{ opacity = 0.6; fontStyle = 'italic'; padding = '12px' }
                                }
                            }
                            else {
                                New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-result-table' = 'true' } -Content {
                                    New-UDTable -Data $tableRows -Columns @(
                                        foreach ($column in $result.Columns) {
                                            New-UDTableColumn -Property $column -Title $column
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                catch {
                    Devolutions.CIEM\Write-CIEMLog -Message "Reports page failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ReportsPage'
                    New-UDTypography -Text "Unable to load CIEM report: $($_.Exception.Message)" -Variant 'body2' -Style @{ opacity = 0.8; fontStyle = 'italic'; padding = '16px' }
                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
