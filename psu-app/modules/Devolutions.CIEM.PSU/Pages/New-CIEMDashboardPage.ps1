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

    New-UDPage -Name 'Dashboard' -Url '/ciem' -Content {
        New-UDTypography -Text 'Devolutions CIEM Dashboard' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Cloud Infrastructure Entitlement Management - Scan Results Overview' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

        # Last Discovery status card
        New-UDDynamic -Content {
            $lastRun = @(Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 1)
            if ($lastRun.Count -gt 0) {
                $run = $lastRun[0]
                $resourceCount = $run.ArmRowCount + $run.EntraRowCount
                New-UDCard -Title 'Last Discovery' -Style @{ marginBottom = '20px' } -Content {
                    New-UDTypography -Text "Completed: $($run.CompletedAt)" -Variant body2
                    New-UDTypography -Text "Resources: $resourceCount ($($run.ArmRowCount) ARM, $($run.EntraRowCount) Entra)" -Variant body2
                    New-UDTypography -Text "Types: $($run.ArmTypeCount) ARM, $($run.EntraTypeCount) Entra" -Variant body2
                }
            } else {
                New-UDCard -Title 'Discovery' -Style @{ marginBottom = '20px' } -Content {
                    New-UDTypography -Text 'No discovery runs completed yet. Run Start-CIEMAzureDiscovery to populate resource data.' -Variant body2
                }
            }
        }

        # Load available scan runs for the selector (only those with results)
        $scanRuns = @(Get-CIEMScanRun | Where-Object { $_.TotalResults -gt 0 })

        if ($scanRuns -and $scanRuns.Count -gt 0) {
            # Initialize selected scan run to most recent if not already set
            if (-not $Session:SelectedScanRunId) {
                $Session:SelectedScanRunId = $scanRuns[0].Id
            }

            # Scan Run Selector + Run New Scan button
            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '400px' } } -Content {
                        New-UDSelect -Id 'scanRunSelector' -Label 'Select Scan Run' -Option {
                            $runs = @(Get-CIEMScanRun | Where-Object { $_.TotalResults -gt 0 })
                            foreach ($run in $runs) {
                                $statusIcon = switch ([string]$run.Status) { 'Completed' { '✓' } 'Failed' { '✗' } default { '…' } }
                                $label = "$statusIcon $(([datetime]$run.StartTime).ToString('yyyy-MM-dd HH:mm')) - $($run.Providers -join ', ') ($($run.TotalResults) results, $($run.FailedResults) failed)"
                                New-UDSelectOption -Name $label -Value $run.Id
                            }
                        } -DefaultValue $Session:SelectedScanRunId -OnChange {
                            $Session:SelectedScanRunId = $EventData
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
                $scanRunId = $Session:SelectedScanRunId
                if (-not $scanRunId) { return }

                $scanRun = Get-CIEMScanRun -Id $scanRunId -IncludeResults
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
                        $providerResults  = @($ScanResults | Where-Object { $_.Check.Provider -eq $chartProvider })
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
                                        @{ Name = 'Critical'; Count = $pCritical; color = '#9c27b0' }
                                        @{ Name = 'High';     Count = $pHigh;     color = '#f44336' }
                                        @{ Name = 'Medium';   Count = $pMedium;   color = '#ff9800' }
                                        @{ Name = 'Low';      Count = $pLow;      color = '#2196f3' }
                                    ) | Where-Object { $_.Count -gt 0 }
                                    if ($SeverityData.Count -gt 0) {
                                        New-UDChartJS -Type 'doughnut' -Data $SeverityData -DataProperty Count -LabelProperty Name -BackgroundColor @('#9c27b0', '#f44336', '#ff9800', '#2196f3')
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
                                    $color = Get-SeverityColor -Severity $sev
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
    } -Navigation $Navigation -NavigationLayout permanent
}
