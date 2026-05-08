function New-CIEMDashboardPage {
    <#
    .SYNOPSIS
        Creates the Dashboard page showing scan results overview and severity charts.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Dashboard' -Url '/ciem' -Content {
        New-UDTypography -Text 'Devolutions CIEM Dashboard' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Cloud Infrastructure Entitlement Management - Scan Results Overview' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

        $scanRuns = @(Devolutions.CIEM\Get-CIEMScanRun | Where-Object { $_.TotalResults -gt 0 })
        $needsAttentionItems = @(Devolutions.CIEM\Get-CIEMDashboardNeedsAttention -Limit 3)
        $pamProgress = Devolutions.CIEM\Get-CIEMPAMProgressSummary -Limit 5
        $scanEfficiency = Devolutions.CIEM\Get-CIEMScanEfficiencySummary -Last 5
        $graphCountRows = @(Devolutions.CIEM\Invoke-CIEMQuery -Query 'SELECT COUNT(*) AS c FROM graph_nodes')
        if ($graphCountRows.Count -ne 1) {
            throw "Expected one graph node count row, got $($graphCountRows.Count)."
        }
        $hasDiscoveryGraphData = [int]$graphCountRows[0].c -gt 0

        $latestScanState = if ($scanRuns.Count -gt 0) { [string]$scanRuns[0].Status } else { 'No scan data' }
        $identityDataState = if ($hasDiscoveryGraphData) { 'Present' } else { 'None' }
        $pamReadiness = "$($pamProgress.ReadinessPercent)%"
        New-UDElement -Tag 'section' -Id 'dashboardOverviewSection' -Attributes @{
            style = @{
                display = 'grid'
                gap = '12px'
                marginBottom = '16px'
            }
        } -Content {
            New-UDElement -Id 'dashboardPrimaryStateGrid' -Tag 'div' -Attributes @{
                style = @{
                    display = 'grid'
                    gridTemplateColumns = 'repeat(4, minmax(0, 1fr))'
                    gap = '10px'
                }
            } -Content {
                foreach ($metric in @(
                    @{ Label = 'Needs Attention'; Value = [string]$needsAttentionItems.Count; Detail = 'Priority risk items' },
                    @{ Label = 'Identity Data'; Value = $identityDataState; Detail = 'Discovery graph state' },
                    @{ Label = 'Latest Scan'; Value = $latestScanState; Detail = 'Checks and scan state' },
                    @{ Label = 'PAM Readiness'; Value = $pamReadiness; Detail = 'Implementation progress' }
                )) {
                    New-UDElement -Tag 'div' -Attributes @{
                        'data-ciem-dashboard-status-metric' = 'true'
                        style = @{
                            display = 'grid'
                            gap = '3px'
                            minHeight = '82px'
                            padding = '12px'
                            border = '1px solid #d0d7de'
                            borderRadius = '6px'
                            backgroundColor = '#ffffff'
                        }
                    } -Content {
                        New-UDTypography -Text $metric.Label -Variant 'caption' -Style @{ color = '#57606a'; fontWeight = '600' }
                        New-UDTypography -Text $metric.Value -Variant 'h5' -Style @{ color = '#24292f'; fontWeight = '700'; lineHeight = '1.1' }
                        New-UDTypography -Text $metric.Detail -Variant 'caption' -Style @{ color = '#57606a' }
                    }
                }
            }
        }

        New-UDElement -Tag 'section' -Id 'dashboardPriorityWorkSection' -Attributes @{
            style = @{
                display = 'grid'
                gap = '14px'
                alignItems = 'start'
                marginBottom = '18px'
            }
        } -Content {

        New-UDElement -Tag 'section' -Id 'dashboardNeedsAttentionSection' -Attributes @{
            style = @{
                marginBottom = '22px'
            }
        } -Content {
            New-UDTypography -Text 'Needs Attention' -Variant 'h5' -Style @{ marginBottom = '6px' }
            New-UDTypography -Text 'Highest-priority identity and attack path risks from the current discovery graph.' -Variant 'body2' -Style @{ marginBottom = '12px'; color = '#666' }

            if ($needsAttentionItems.Count -eq 0) {
                $emptyText = if ($hasDiscoveryGraphData) {
                    'No current identity or attack path risks need attention.'
                } else {
                    'No discovered identity or attack path data yet. Run discovery to build the risk queue.'
                }
                New-UDElement -Tag 'div' -Attributes @{
                    'data-ciem-needs-attention-empty' = 'true'
                    style = @{
                        padding = '14px'
                        border = '1px solid #d0d7de'
                        borderRadius = '6px'
                        backgroundColor = '#ffffff'
                    }
                } -Content {
                    New-UDTypography -Text $emptyText -Variant 'body2' -Style @{ color = '#666' }
                }
            } else {
                New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'grid'; gap = '10px' } } -Content {
                    foreach ($item in $needsAttentionItems) {
                        $severityColor = Devolutions.CIEM\Get-SeverityColor -Severity $item.Severity
                        New-UDElement -Tag 'div' -Attributes @{
                            'data-ciem-needs-attention-item' = 'true'
                            style = @{
                                display = 'grid'
                                gap = '8px'
                                padding = '12px'
                                border = '1px solid #d0d7de'
                                borderRadius = '6px'
                                backgroundColor = '#ffffff'
                            }
                        } -Content {
                            New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                New-UDChip -Label $item.Severity -Size 'small' -Style @{ backgroundColor = $severityColor; color = 'white' }
                                New-UDChip -Label $item.SourceType -Size 'small' -Variant 'outlined'
                                New-UDTypography -Text $item.Title -Variant 'subtitle1' -Style @{ fontWeight = '600' }
                            }
                            New-UDTypography -Text "Identity: $($item.Identity)" -Variant 'body2' -Style @{ color = '#555' }
                            New-UDTypography -Text "Target: $($item.Target)" -Variant 'body2' -Style @{ color = '#555'; overflowWrap = 'anywhere' }
                            New-UDTypography -Text $item.Reason -Variant 'body2'
                            New-UDTypography -Text $item.Evidence -Variant 'caption' -Style @{ color = '#666'; overflowWrap = 'anywhere' }
                            if ($item.SourceType -eq 'Identity') {
                                New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-inspect-identity' = 'true' } -Content {
                                    New-UDButton -Text 'Inspect Identity' -Variant 'outlined' -Size 'small' -OnClick {
                                        Invoke-UDRedirect '/ciem/identities'
                                    }
                                }
                            } elseif ($item.SourceType -eq 'AttackPath') {
                                New-UDElement -Tag 'div' -Attributes @{ 'data-ciem-inspect-attack-path' = 'true' } -Content {
                                    $drillInUrl = [string]$item.DrillInUrl
                                    if ([string]::IsNullOrWhiteSpace($drillInUrl)) {
                                        throw "Expected dashboard Needs Attention attack path '$($item.Id)' to include DrillInUrl."
                                    }
                                    New-UDButton -Text 'Inspect Attack Path' -Variant 'outlined' -Size 'small' -OnClick {
                                        Invoke-UDRedirect $drillInUrl
                                    }
                                }
                            } else {
                                throw "Unsupported dashboard Needs Attention item source type '$($item.SourceType)'."
                            }
                        }
                    }
                }
            }
        }

            if ($scanRuns.Count -eq 0) {
                New-UDElement -Tag 'div' -Id 'dashboardNoScanDataState' -Attributes @{
                    style = @{
                        marginTop = '4px'
                        textAlign = 'center'
                        padding = '28px'
                        border = '1px solid #d0d7de'
                        borderRadius = '6px'
                        backgroundColor = '#ffffff'
                    }
                } -Content {
                    New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 2 -Content {
                        New-UDIcon -Icon 'Search' -Size '3x' -Style @{ color = '#1976d2'; marginBottom = '8px' }
                        New-UDTypography -Text 'No Scan Data Available' -Variant 'h5' -Style @{ marginBottom = '4px' }
                        New-UDTypography -Text 'Run a security scan to populate the dashboard.' -Variant 'body1' -Style @{ color = '#666'; marginBottom = '12px' }
                        New-UDButton -Text 'Run Your First Scan' -Variant 'contained' -Color 'primary' -Size 'medium' -OnClick {
                            Invoke-UDRedirect '/ciem/scan'
                        }
                    }
                }
            }
        }

        New-UDElement -Tag 'section' -Id 'dashboardSupportingEvidenceSection' -Attributes @{
            style = @{
                display = 'grid'
                gap = '18px'
            }
        } -Content {
            New-UDExpansionPanelGroup -Id 'dashboardSupportingEvidencePanelGroup' -Type 'Accordion' -Children {
                New-UDExpansionPanel -Id 'dashboardIdentityAndPAMPanel' -Title 'Identity & PAM' -Children {
                    New-UDElement -Tag 'section' -Id 'dashboardIdentitySection' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
                        New-UDTypography -Text 'Identity Stats' -Variant 'h5' -Style @{ marginBottom = '6px' }
                        New-UDTypography -Text 'Identity inventory and effective entitlement coverage.' -Variant 'body2' -Style @{ marginBottom = '16px'; color = '#666' }

                        $identityStatsRows = @(Devolutions.CIEM\Invoke-CIEMQuery -Query @"
SELECT
    (SELECT COUNT(*) FROM graph_nodes WHERE kind IN ('EntraUser', 'EntraServicePrincipal', 'EntraGroup')) AS identity_count,
    (SELECT COUNT(*) FROM azure_effective_role_assignments) AS entitlement_count
"@)
                        if ($identityStatsRows.Count -ne 1) {
                            throw "Expected one dashboard identity stats row, got $($identityStatsRows.Count)."
                        }

                        $identityStats = $identityStatsRows[0]
                        $identityCount = [int]$identityStats.identity_count
                        $entitlementCount = [int]$identityStats.entitlement_count

                        New-UDGrid -Container -Content {
                            New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                                New-UDCard -Title 'Identities' -Content {
                                    New-UDTypography -Text $identityCount -Variant 'h3' -Style @{ color = '#1976d2'; textAlign = 'center' }
                                } -Style @{ textAlign = 'center' }
                            }
                            New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                                New-UDCard -Title 'Entitlements' -Content {
                                    New-UDTypography -Text $entitlementCount -Variant 'h3' -Style @{ color = '#7b1fa2'; textAlign = 'center' }
                                } -Style @{ textAlign = 'center' }
                            }
                        }
                    }

        New-UDElement -Tag 'section' -Id 'dashboardPAMProgressSection' -Attributes @{
            style = @{
                marginBottom = '22px'
            }
        } -Content {
            New-UDTypography -Text 'PAM Implementation Progress' -Variant 'h5' -Style @{ marginBottom = '6px' }
            New-UDTypography -Text 'Read-only CIEM progress toward PAM adoption: readiness, candidate mapping, and scoped handoff status.' -Variant 'body2' -Style @{ marginBottom = '12px'; color = '#666' }
            $riskBurndownMetric = if ($null -eq $pamProgress.RiskBurndownPercent) { 'No baseline' } else { "$($pamProgress.RiskBurndownPercent)%" }

            New-UDElement -Tag 'div' -Attributes @{
                style = @{
                    display = 'grid'
                    gridTemplateColumns = 'repeat(auto-fit, minmax(160px, 1fr))'
                    gap = '10px'
                    marginBottom = '12px'
                }
            } -Content {
                foreach ($metric in @(
                    @{ Label = 'Readiness'; Value = "$($pamProgress.ReadinessPercent)%" },
                    @{ Label = 'PAM Candidates'; Value = [string]$pamProgress.PAMCandidateCount },
                    @{ Label = 'Risk Burndown'; Value = $riskBurndownMetric }
                )) {
                    New-UDElement -Tag 'div' -Attributes @{
                        'data-ciem-pam-progress-metric' = 'true'
                        style = @{
                            padding = '12px'
                            border = '1px solid #d0d7de'
                            borderRadius = '6px'
                            backgroundColor = '#ffffff'
                        }
                    } -Content {
                        New-UDTypography -Text $metric.Label -Variant 'caption' -Style @{ color = '#666' }
                        New-UDTypography -Text $metric.Value -Variant 'h6' -Style @{ marginTop = '4px' }
                    }
                }
            }

            New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'grid'; gap = '8px'; marginBottom = '12px' } } -Content {
                foreach ($stage in @($pamProgress.Stages)) {
                    $stageColor = switch ([string]$stage.Status) {
                        'Complete' { '#2e7d32' }
                        'Pending' { '#ed6c02' }
                        'NotScoped' { '#5f6368' }
                        default { throw "Unsupported PAM progress stage status '$($stage.Status)'." }
                    }
                    New-UDElement -Tag 'div' -Attributes @{
                        'data-ciem-pam-progress-stage' = 'true'
                        style = @{
                            display = 'grid'
                            gap = '6px'
                            padding = '10px 12px'
                            border = '1px solid #d0d7de'
                            borderRadius = '6px'
                            backgroundColor = '#ffffff'
                        }
                    } -Content {
                        New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                            New-UDChip -Label $stage.Status -Size 'small' -Style @{ backgroundColor = $stageColor; color = 'white' }
                            New-UDTypography -Text $stage.Name -Variant 'subtitle2' -Style @{ fontWeight = '600' }
                        }
                        New-UDTypography -Text $stage.Evidence -Variant 'caption' -Style @{ color = '#666'; overflowWrap = 'anywhere' }
                    }
                }
            }

            if ($pamProgress.Candidates.Count -eq 0) {
                New-UDElement -Tag 'div' -Attributes @{
                    'data-ciem-pam-progress-empty' = 'true'
                    style = @{
                        padding = '14px'
                        border = '1px solid #d0d7de'
                        borderRadius = '6px'
                        backgroundColor = '#ffffff'
                    }
                } -Content {
                    New-UDTypography -Text 'No PAM candidates are mapped yet.' -Variant 'body2' -Style @{ color = '#666' }
                }
            }
            else {
                New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'grid'; gap = '10px' } } -Content {
                    foreach ($candidate in @($pamProgress.Candidates)) {
                        $severityColor = Devolutions.CIEM\Get-SeverityColor -Severity $candidate.Severity
                        New-UDElement -Tag 'div' -Attributes @{
                            'data-ciem-pam-progress-candidate' = 'true'
                            style = @{
                                display = 'grid'
                                gap = '7px'
                                padding = '12px'
                                border = '1px solid #d0d7de'
                                borderRadius = '6px'
                                backgroundColor = '#ffffff'
                            }
                        } -Content {
                            New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                New-UDChip -Label $candidate.Severity -Size 'small' -Style @{ backgroundColor = $severityColor; color = 'white' }
                                New-UDChip -Label $candidate.SourceType -Size 'small' -Variant 'outlined'
                                New-UDTypography -Text $candidate.Title -Variant 'subtitle1' -Style @{ fontWeight = '600' }
                            }
                            New-UDTypography -Text $candidate.PAMCapability -Variant 'body2' -Style @{ color = '#555' }
                            New-UDTypography -Text $candidate.RecommendedNextStep -Variant 'caption' -Style @{ color = '#666'; overflowWrap = 'anywhere' }
                        }
                    }
                }
            }
        }

                }

                New-UDExpansionPanel -Id 'dashboardChecksAndScansPanel' -Title 'Checks & Scans' -Children {
        New-UDElement -Tag 'section' -Id 'dashboardScanEfficiencySection' -Attributes @{
            style = @{
                marginBottom = '22px'
            }
        } -Content {
            New-UDTypography -Text 'Scan Efficiency' -Variant 'h5' -Style @{ marginBottom = '6px' }
            New-UDTypography -Text 'Duration and throughput from persisted scan runs and discovery phase timing.' -Variant 'body2' -Style @{ marginBottom = '12px'; color = '#666' }

            if ($scanEfficiency.Status -eq 'NoScanData') {
                New-UDElement -Tag 'div' -Attributes @{
                    'data-ciem-scan-efficiency-empty' = 'true'
                    style = @{
                        padding = '14px'
                        border = '1px solid #d0d7de'
                        borderRadius = '6px'
                        backgroundColor = '#ffffff'
                    }
                } -Content {
                    New-UDTypography -Text 'No timed scan runs are available yet.' -Variant 'body2' -Style @{ color = '#666' }
                }
            }
            elseif ($scanEfficiency.Status -eq 'Tracked') {
                $latestDurationText = "$($scanEfficiency.LatestDurationSeconds)s"
                $averageDurationText = "$($scanEfficiency.AverageDurationSeconds)s"
                $latestThroughputText = if ($null -eq $scanEfficiency.LatestResultsPerSecond) { 'No throughput' } else { "$($scanEfficiency.LatestResultsPerSecond) results/s" }
                $averageThroughputText = if ($null -eq $scanEfficiency.AverageResultsPerSecond) { 'No throughput' } else { "$($scanEfficiency.AverageResultsPerSecond) results/s" }

                New-UDElement -Tag 'div' -Attributes @{
                    style = @{
                        display = 'grid'
                        gridTemplateColumns = 'repeat(auto-fit, minmax(160px, 1fr))'
                        gap = '10px'
                        marginBottom = '12px'
                    }
                } -Content {
                    foreach ($metric in @(
                        @{ Label = 'Latest Duration'; Value = $latestDurationText },
                        @{ Label = 'Average Duration'; Value = $averageDurationText },
                        @{ Label = 'Latest Throughput'; Value = $latestThroughputText },
                        @{ Label = 'Average Throughput'; Value = $averageThroughputText }
                    )) {
                        New-UDElement -Tag 'div' -Attributes @{
                            'data-ciem-scan-efficiency-metric' = 'true'
                            style = @{
                                padding = '12px'
                                border = '1px solid #d0d7de'
                                borderRadius = '6px'
                                backgroundColor = '#ffffff'
                            }
                        } -Content {
                            New-UDTypography -Text $metric.Label -Variant 'caption' -Style @{ color = '#666' }
                            New-UDTypography -Text $metric.Value -Variant 'h6' -Style @{ marginTop = '4px' }
                        }
                    }
                }

                New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'grid'; gap = '8px' } } -Content {
                    foreach ($run in @($scanEfficiency.Runs)) {
                        New-UDElement -Tag 'div' -Attributes @{
                            'data-ciem-scan-efficiency-run' = 'true'
                            style = @{
                                display = 'grid'
                                gap = '6px'
                                padding = '10px 12px'
                                border = '1px solid #d0d7de'
                                borderRadius = '6px'
                                backgroundColor = '#ffffff'
                            }
                        } -Content {
                            New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                New-UDChip -Label $run.Status -Size 'small' -Variant 'outlined'
                                New-UDTypography -Text $run.Id -Variant 'subtitle2' -Style @{ fontWeight = '600'; overflowWrap = 'anywhere' }
                            }
                            New-UDTypography -Text "Duration: $($run.DurationSeconds)s; Results: $($run.TotalResults); Failed: $($run.FailedResults); Throughput: $($run.ResultsPerSecond) results/s" -Variant 'caption' -Style @{ color = '#666'; overflowWrap = 'anywhere' }
                        }
                    }
                }
            }
            else {
                throw "Unsupported scan efficiency status '$($scanEfficiency.Status)'."
            }

            $discoveryPhaseMetrics = @($scanEfficiency.LatestDiscoveryPhaseMetrics)
            if ($discoveryPhaseMetrics.Count -gt 0) {
                $discoveryDurationText = "$($scanEfficiency.LatestDiscoveryDurationSeconds)s"
                New-UDElement -Tag 'div' -Id 'dashboardDiscoveryPhaseTiming' -Attributes @{
                    style = @{
                        display = 'grid'
                        gap = '8px'
                        marginTop = '12px'
                    }
                } -Content {
                    New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                        New-UDTypography -Text 'Discovery Phase Timing' -Variant 'subtitle1' -Style @{ fontWeight = '600' }
                        New-UDChip -Label "Run #$($scanEfficiency.LatestDiscoveryRunId)" -Size 'small' -Variant 'outlined'
                        New-UDChip -Label "Total Discovery Duration: $discoveryDurationText" -Size 'small' -Variant 'outlined'
                    }
                    foreach ($phase in $discoveryPhaseMetrics) {
                        $phaseStatusLabel = if ($phase.Succeeded) { 'Succeeded' } else { 'Failed' }
                        $phaseStatusColor = if ($phase.Succeeded) { '#2e7d32' } else { '#d32f2f' }
                        New-UDElement -Tag 'div' -Attributes @{
                            'data-ciem-discovery-phase-metric' = 'true'
                            style = @{
                                display = 'grid'
                                gap = '6px'
                                padding = '10px 12px'
                                border = '1px solid #d0d7de'
                                borderRadius = '6px'
                                backgroundColor = '#ffffff'
                            }
                        } -Content {
                            New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                                New-UDChip -Label $phaseStatusLabel -Size 'small' -Style @{ backgroundColor = $phaseStatusColor; color = 'white' }
                                New-UDTypography -Text $phase.PhaseName -Variant 'subtitle2' -Style @{ fontWeight = '600'; overflowWrap = 'anywhere' }
                            }
                            New-UDTypography -Text "Duration: $($phase.ElapsedSeconds)s; Evidence: $($phase.Evidence)" -Variant 'caption' -Style @{ color = '#666'; overflowWrap = 'anywhere' }
                        }
                    }
                }
            }
        }

        New-UDElement -Tag 'section' -Id 'dashboardScanSection' -Attributes @{ style = @{ marginBottom = '28px' } } -Content {
            New-UDTypography -Text 'Checks & Scans' -Variant 'h5' -Style @{ marginBottom = '6px' }
            New-UDTypography -Text 'Cloud checks, scan results, and finding evidence.' -Variant 'body2' -Style @{ marginBottom = '16px'; color = '#666' }

            if ($scanRuns -and $scanRuns.Count -gt 0) {
                # Initialize selected scan run to most recent if not already set
                if (-not $Page:SelectedScanRunId) {
                    $Page:SelectedScanRunId = $scanRuns[0].Id
                }

                # Scan Run Selector + Run New Scan button
                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                        New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '400px' } } -Content {
                            New-UDSelect -Id 'scanRunSelector' -Label 'Select Scan Run' -Option {
                                $runs = @(Devolutions.CIEM\Get-CIEMScanRun | Where-Object { $_.TotalResults -gt 0 })
                                foreach ($run in $runs) {
                                    $statusIcon = switch ([string]$run.Status) { 'Completed' { '✓' } 'Failed' { '✗' } default { '…' } }
                                    $label = "$statusIcon $(([datetime]$run.StartTime).ToString('yyyy-MM-dd HH:mm')) - $($run.Providers -join ', ') ($($run.TotalResults) results, $($run.FailedResults) failed)"
                                    New-UDSelectOption -Name $label -Value $run.Id
                                }
                            } -DefaultValue $Page:SelectedScanRunId -OnChange {
                                $Page:SelectedScanRunId = $EventData
                                Sync-UDElement -Id 'dashboardContent'
                            } -FullWidth
                        }
                        New-UDButton -Text 'Run New Scan' -Variant 'outlined' -Size 'small' -OnClick {
                            Invoke-UDRedirect '/ciem/scan'
                        }
                    }
                }

                # Dynamic dashboard content that refreshes when scan run selection changes
                New-UDDynamic -Id 'dashboardContent' -Content {
                    $scanRunId = $Page:SelectedScanRunId
                    if (-not $scanRunId) { return }

                    $scanRun = Devolutions.CIEM\Get-CIEMScanRun -Id $scanRunId -IncludeResults
                    if (-not $scanRun) {
                        New-UDTypography -Text 'Scan run not found.' -Style @{ color = '#666'; padding = '20px' }
                        return
                    }

                    $rawResults = $scanRun.ScanResults
                    $scanTimestamp = $scanRun.EndTime

                    if ($rawResults -and @($rawResults).Count -gt 0) {
                        $ScanResults = $rawResults | ForEach-Object {
                            [PSCustomObject]@{
                                Id = $_.Check.Id
                                CheckId = $_.Check.Id
                                Title = $_.Check.Title
                                Severity = ([string]$_.Check.Severity -replace '^(.)', { $_.Groups[1].Value.ToUpper() })
                                Status = $_.Status
                                Provider = if ($_.Check.Provider) { [string]$_.Check.Provider } else { 'Azure' }
                                Service = [string]$_.Check.Service
                                ResourceName = $_.ResourceName
                            }
                        }

                        $FailedResults = @($ScanResults | Where-Object { $_.Status -eq 'FAIL' })
                        $PassedResults = @($ScanResults | Where-Object { $_.Status -eq 'PASS' })
                        $CriticalCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'CRITICAL' }).Count
                        $HighCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'HIGH' }).Count
                        $MediumCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'MEDIUM' }).Count
                        $LowCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'LOW' }).Count

                        New-UDGrid -Container -Content {
                            New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                                New-UDCard -Title 'Total Results' -Content {
                                    New-UDTypography -Text @($ScanResults).Count -Variant 'h3' -Style @{ color = '#1976d2'; textAlign = 'center' }
                                } -Style @{ textAlign = 'center' }
                            }
                            New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                                New-UDCard -Title 'Failed Checks' -Content {
                                    New-UDTypography -Text $FailedResults.Count -Variant 'h3' -Style @{ color = '#f44336'; textAlign = 'center' }
                                } -Style @{ textAlign = 'center' }
                            }
                            New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                                New-UDCard -Title 'Passed Checks' -Content {
                                    New-UDTypography -Text $PassedResults.Count -Variant 'h3' -Style @{ color = '#4caf50'; textAlign = 'center' }
                                } -Style @{ textAlign = 'center' }
                            }
                            New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                                New-UDCard -Title 'Critical Issues' -Content {
                                    New-UDTypography -Text $CriticalCount -Variant 'h3' -Style @{ color = '#9c27b0'; textAlign = 'center' }
                                } -Style @{ textAlign = 'center' }
                            }
                        }

                        # Chart panels: one pair per provider when multi-provider, single pair otherwise
                        $chartProviders = @($scanRun.Providers | Where-Object { $_ })
                        if (-not $chartProviders -or $chartProviders.Count -eq 0) { $chartProviders = @('Azure') }

                        foreach ($chartProvider in $chartProviders) {
                            $providerResults  = @($ScanResults | Where-Object { $_.Provider -eq $chartProvider })
                            $providerFailed   = @($providerResults | Where-Object { $_.Status -eq 'FAIL' })
                            $pCritical = @($providerFailed | Where-Object { $_.Severity.ToUpper() -eq 'CRITICAL' }).Count
                            $pHigh     = @($providerFailed | Where-Object { $_.Severity.ToUpper() -eq 'HIGH' }).Count
                            $pMedium   = @($providerFailed | Where-Object { $_.Severity.ToUpper() -eq 'MEDIUM' }).Count
                            $pLow      = @($providerFailed | Where-Object { $_.Severity.ToUpper() -eq 'LOW' }).Count

                            if ($chartProviders.Count -gt 1) {
                                New-UDTypography -Text $chartProvider -Variant 'h6' -Style @{ marginTop = '16px'; marginBottom = '4px'; color = '#555' }
                            }

                            New-UDGrid -Container -Content {
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    New-UDCard -Title "Results by Severity$(if ($chartProviders.Count -gt 1) { " - $chartProvider" })" -Content {
                                        $SeverityData = @(
                                            @{ Name = 'Critical'; Count = $pCritical; color = (Devolutions.CIEM\Get-SeverityColor -Severity 'critical') }
                                            @{ Name = 'High';     Count = $pHigh;     color = (Devolutions.CIEM\Get-SeverityColor -Severity 'high') }
                                            @{ Name = 'Medium';   Count = $pMedium;   color = (Devolutions.CIEM\Get-SeverityColor -Severity 'medium') }
                                            @{ Name = 'Low';      Count = $pLow;      color = (Devolutions.CIEM\Get-SeverityColor -Severity 'low') }
                                        ) | Where-Object { $_.Count -gt 0 }
                                        if ($SeverityData.Count -gt 0) {
                                            New-UDChartJS -Type 'doughnut' -Data $SeverityData -DataProperty Count -LabelProperty Name -BackgroundColor @($SeverityData.ForEach({ $_.color }))
                                        } else {
                                            New-UDTypography -Text 'No failed results' -Style @{ textAlign = 'center'; padding = '40px' }
                                        }
                                    }
                                }
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    New-UDCard -Title "Results by Service$(if ($chartProviders.Count -gt 1) { " - $chartProvider" })" -Content {
                                        $ServiceData = $providerFailed | Group-Object -Property Service | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
                                        if ($ServiceData.Count -gt 0) {
                                            New-UDChartJS -Type 'bar' -Data $ServiceData -DataProperty Count -LabelProperty Name -BackgroundColor '#1976d2'
                                        } else {
                                            New-UDTypography -Text 'No failed results' -Style @{ textAlign = 'center'; padding = '40px' }
                                        }
                                    }
                                }
                            }
                        }

                        New-UDCard -Title 'Critical & High Results' -Style @{ marginTop = '20px' } -Content {
                            $CriticalHighResults = $FailedResults | Where-Object { $_.Severity.ToUpper() -in @('CRITICAL', 'HIGH') } | Select-Object -First 5
                            if (@($CriticalHighResults).Count -gt 0) {
                                New-UDTable -Data $CriticalHighResults -Columns @(
                                    New-UDTableColumn -Property 'CheckId' -Title 'Check ID'
                                    New-UDTableColumn -Property 'Title' -Title 'Result'
                                    New-UDTableColumn -Property 'Severity' -Title 'Severity' -Render {
                                        $sev = $EventData.Severity.ToUpper()
                                        $color = Devolutions.CIEM\Get-SeverityColor -Severity $sev
                                        New-UDChip -Label $sev -Style @{ backgroundColor = $color; color = 'white' }
                                    }
                                    New-UDTableColumn -Property 'Service' -Title 'Service'
                                    New-UDTableColumn -Property 'ResourceName' -Title 'Resource'
                                )
                                New-UDButton -Text 'View All Results' -Variant 'outlined' -OnClick {
                                    Invoke-UDRedirect '/ciem/history'
                                } -Style @{ marginTop = '12px' }
                            } else {
                                New-UDStack -Direction 'column' -AlignItems 'center' -Content {
                                    New-UDIcon -Icon 'CheckCircle' -Size '3x' -Style @{ color = '#4caf50'; marginBottom = '12px' }
                                    New-UDTypography -Text 'No critical or high severity results!' -Style @{ color = '#4caf50' }
                                }
                            }
                        }
                    }
                    else {
                        New-UDTypography -Text 'No results for this scan run.' -Style @{ color = '#666'; padding = '20px' }
                    }
                } -LoadingComponent {
                    New-UDProgress -Circular
                }
            }
            else {
                # No scan data - show empty state with call to action
                New-UDCard -Style @{ marginTop = '20px'; textAlign = 'center'; padding = '40px' } -Content {
                    New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 3 -Content {
                        New-UDIcon -Icon 'Search' -Size '4x' -Style @{ color = '#1976d2'; marginBottom = '16px' }
                        New-UDTypography -Text 'No Scan Data Available' -Variant 'h5' -Style @{ marginBottom = '8px' }
                        New-UDTypography -Text 'Run a security scan to see results and insights about your cloud environment.' -Variant 'body1' -Style @{ color = '#666'; marginBottom = '24px' }
                        New-UDButton -Text 'Run Your First Scan' -Variant 'contained' -Color 'primary' -Size 'large' -OnClick {
                            Invoke-UDRedirect '/ciem/scan'
                        }
                    }
                }
            }
        }

                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
