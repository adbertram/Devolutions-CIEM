function New-CIEMReportsPage {
    <#
    .SYNOPSIS
        Creates the Reports page with registered CIEM report definitions.
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
                        return
                    }

                    if (-not $Page:SelectedReportId) {
                        $Page:SelectedReportId = [string]$reports[0].Id
                    }
                    if (-not $Page:SelectedReportParameters) {
                        $Page:SelectedReportParameters = @{}
                    }

                    $selectedReport = $reports | Where-Object { $_.Id -eq $Page:SelectedReportId } | Select-Object -First 1
                    if (-not $selectedReport) {
                        throw "Selected CIEM report '$($Page:SelectedReportId)' is not registered."
                    }

                    $validParameterNames = @($selectedReport.Parameters | ForEach-Object { [string]$_.name })
                    foreach ($parameterName in @($Page:SelectedReportParameters.Keys)) {
                        if ($parameterName -notin $validParameterNames) {
                            $Page:SelectedReportParameters.Remove($parameterName)
                        }
                    }

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

                    $optionSourceDispatch = @{
                        CompletedDiscoveryRuns = {
                            @(Devolutions.CIEM\Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 25 | ForEach-Object {
                                $completedAt = ([datetime]$_.CompletedAt).ToString('yyyy-MM-dd HH:mm')
                                [pscustomobject]@{
                                    Value = [string]$_.Id
                                    Label = "Run #$($_.Id) - $completedAt UTC - Scope $($_.Scope)"
                                }
                            })
                        }
                        EnvironmentalProgressEvidencePairs = {
                            @(Devolutions.CIEM\Get-CIEMEnvironmentalProgressEvidencePairOption | ForEach-Object {
                                [pscustomobject]@{
                                    Value = [string]$_.Value
                                    Label = [string]$_.Label
                                }
                            })
                        }
                    }

                    $parameterOptionRows = @{}
                    foreach ($parameter in @($selectedReport.Parameters)) {
                        $optionSource = [string]$parameter.optionSource
                        if (-not $optionSourceDispatch.ContainsKey($optionSource)) {
                            throw "Unsupported CIEM report option source '$optionSource'."
                        }
                        $parameterOptionRows[[string]$parameter.name] = @(& $optionSourceDispatch[$optionSource])
                    }

                    $generateDisabled = $false

                    New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-history' = 'true'; style = @{ marginBottom = '18px' } } -Content {
                        New-UDTypography -Text 'Report Selection' -Variant 'h5' -Style @{ marginBottom = '8px' }

                        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '300px' } } -Content {
                                New-UDSelect -Id 'reportSelector' -Label 'Report' -Option {
                                    foreach ($report in $reports) {
                                        New-UDSelectOption -Name $report.Title -Value $report.Id
                                    }
                                } -DefaultValue $Page:SelectedReportId -OnChange {
                                    $Page:SelectedReportId = [string]$EventData
                                    $Page:ReportResult = $null
                                    $Page:ReportError = $null
                                    if (-not $Page:SelectedReportParameters) {
                                        $Page:SelectedReportParameters = @{}
                                    }
                                    Sync-UDElement -Id 'ciemReportsPanel'
                                } -FullWidth
                            }

                            foreach ($parameter in @($selectedReport.Parameters)) {
                                $parameterName = [string]$parameter.name
                                $options = @($parameterOptionRows[$parameterName])
                                if ($options.Count -eq 0) {
                                    if (-not [bool]$parameter.allowEmpty) {
                                        $generateDisabled = $true
                                        if ($selectedReport.Id -eq 'azure.discovery.coverage') {
                                            New-UDTypography -Text 'No completed discovery runs are available for report generation.' -Variant 'body2' -Style @{ opacity = 0.6; fontStyle = 'italic'; padding = '12px' }
                                        }
                                    }
                                    continue
                                }

                                if (-not $Page:SelectedReportParameters.ContainsKey($parameterName)) {
                                    $Page:SelectedReportParameters[$parameterName] = [string]$options[0].Value
                                }

                                New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '420px' } } -Content {
                                    New-UDSelect -Id ([string]$parameter.selectorId) -Label ([string]$parameter.label) -Option {
                                        foreach ($option in $options) {
                                            New-UDSelectOption -Name ([string]$option.Label) -Value ([string]$option.Value)
                                        }
                                    } -DefaultValue $Page:SelectedReportParameters[$parameterName] -OnChange {
                                        if (-not $Page:SelectedReportParameters) {
                                            $Page:SelectedReportParameters = @{}
                                        }
                                        $Page:SelectedReportParameters[$parameterName] = [string]$EventData
                                        $Page:ReportResult = $null
                                        $Page:ReportError = $null
                                        Sync-UDElement -Id 'ciemReportsPanel'
                                    } -FullWidth
                                }
                            }

                            New-UDButton -Id 'generateReportBtn' -Text 'Generate Report' -Variant 'contained' -Color 'primary' -Disabled:$generateDisabled -OnClick {
                                try {
                                    $selectedReportId = [string](Get-UDElement -Id 'reportSelector').value
                                    if ([string]::IsNullOrWhiteSpace($selectedReportId)) {
                                        throw 'Report selection is required.'
                                    }

                                    $reports = @(Devolutions.CIEM\Get-CIEMReport)
                                    $selectedReport = $reports | Where-Object { $_.Id -eq $selectedReportId } | Select-Object -First 1
                                    if (-not $selectedReport) {
                                        throw "Selected CIEM report '$selectedReportId' is not registered."
                                    }

                                    $Page:SelectedReportId = $selectedReportId
                                    $parameters = @{}
                                    foreach ($parameter in @($selectedReport.Parameters)) {
                                        $parameterName = [string]$parameter.name
                                        $selectorId = [string]$parameter.selectorId
                                        $element = Get-UDElement -Id $selectorId -ErrorAction SilentlyContinue
                                        if ($element -and -not [string]::IsNullOrWhiteSpace([string]$element.value)) {
                                            $Page:SelectedReportParameters[$parameterName] = [string]$element.value
                                            $parameters[$parameterName] = [string]$element.value
                                        }
                                        elseif ($Page:SelectedReportParameters.ContainsKey($parameterName) -and -not [string]::IsNullOrWhiteSpace([string]$Page:SelectedReportParameters[$parameterName])) {
                                            $parameters[$parameterName] = [string]$Page:SelectedReportParameters[$parameterName]
                                        }
                                    }

                                    $Page:ReportResult = Devolutions.CIEM\Invoke-CIEMReport -InputObject $selectedReport -Parameter $parameters
                                    $Page:ReportError = $null
                                }
                                catch {
                                    $Page:ReportError = $_.Exception.Message
                                    $Page:ReportResult = $null
                                }
                                Sync-UDElement -Id 'ciemReportsPanel'
                            }
                        }
                    }

                    if ($Page:ReportError) {
                        New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-result' = 'true'; style = @{ padding = '14px' } } -Content {
                            New-UDTypography -Text "Unable to generate CIEM report: $Page:ReportError" -Variant 'body2' -Style @{ color = '#d32f2f' }
                        }
                    }
                    elseif ($Page:ReportResult) {
                        $result = $Page:ReportResult
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
                                    foreach ($key in @($result.Context.ContextChipKeys)) {
                                        $value = $result.Context[$key]
                                        New-UDElement -Tag 'span' -Id "reportContextChip_$key" -Attributes @{ 'data-ciem-report-context-chip' = $key } -Content {
                                            New-UDChip -Label "$key $value" -Size 'small' -Variant 'outlined'
                                        }
                                    }
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
                                $emptyText = if ($result.Context.StatusMessage) { [string]$result.Context.StatusMessage } else { [string]$selectedReport.EmptyState }
                                New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-result-table' = 'true' } -Content {
                                    New-UDTypography -Text $emptyText -Variant 'body2' -Style @{ opacity = 0.6; fontStyle = 'italic'; padding = '12px' }
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
                    else {
                        New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-report-placeholder' = 'true'; style = @{ padding = '14px'; opacity = 0.7 } } -Content {
                            New-UDTypography -Text 'Select a report and generate it.' -Variant 'body2'
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
