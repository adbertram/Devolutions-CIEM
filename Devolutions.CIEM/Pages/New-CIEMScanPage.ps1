function New-CIEMScanPage {
    <#
    .SYNOPSIS
        Creates the Scan page for selecting and executing CIEM checks.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    New-UDPage -Name 'Scan' -Url '/ciem/scan' -Content {
        Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue

        New-UDTypography -Text 'Run CIEM Scan' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
        New-UDTypography -Text 'Configure and execute a CIEM security scan against your cloud environment' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

        # Check Selection Card
        New-UDCard -Title 'Check Selection' -Content {
            # Check selection data grid with checkboxes
            New-UDDynamic -Id 'checkSelectionGrid' -Content {
                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                $allChecks = @(Get-CIEMCheck)

                # Initialize session state on first load
                if ($null -eq $Session:CheckStatusFilter) {
                    $Session:CheckStatusFilter = 'enabled'
                }

                # Selection summary
                New-UDDynamic -Id 'selectionSummary' -Content {
                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                    $checks = @(Get-CIEMCheck)
                    $enabledCount = @($checks | Where-Object { -not $_.Disabled }).Count
                    $disabledCount = @($checks | Where-Object { $_.Disabled }).Count
                    $selectedCount = @($Session:SelectedCheckIds).Count
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                            New-UDTypography -Text "$selectedCount / $enabledCount enabled checks selected ($disabledCount disabled)" -Variant 'body2' -Style @{ color = '#666' }
                        }
                    }
                }

                # Status filter
                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '12px' } } -Content {
                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                        New-UDTypography -Text 'Status:' -Variant 'body2' -Style @{ color = '#666'; marginRight = '4px' }
                        New-UDElement -Tag 'div' -Attributes @{ style = @{ minWidth = '140px' } } -Content {
                            New-UDSelect -Id 'checkStatusFilter' -DefaultValue $Session:CheckStatusFilter -OnChange {
                                $Session:CheckStatusFilter = $EventData
                                Sync-UDElement -Id 'checkSelectionGrid'
                            } -Option {
                                New-UDSelectOption -Name 'Enabled' -Value 'enabled'
                                New-UDSelectOption -Name 'Disabled' -Value 'disabled'
                                New-UDSelectOption -Name 'All' -Value 'all'
                            }
                        }
                    }
                }

                New-UDDataGrid -Id 'checkSelector' -LoadRows {
                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                    $checks = @(Get-CIEMCheck)

                    # Apply status filter
                    $statusFilter = $Session:CheckStatusFilter
                    if ($statusFilter -eq 'enabled') {
                        $checks = @($checks | Where-Object { -not $_.Disabled })
                    } elseif ($statusFilter -eq 'disabled') {
                        $checks = @($checks | Where-Object { $_.Disabled })
                    }

                    $checksData = $checks | ForEach-Object {
                        @{
                            id              = $_.Id
                            checkId         = $_.Id
                            title           = $_.Title
                            description     = $_.Description
                            risk            = $_.Risk
                            provider        = [string]$_.Provider
                            service         = [string]$_.Service
                            severity        = ([string]$_.Severity -replace '^(.)', { $_.Groups[1].Value.ToUpper() })
                            relatedUrl      = $_.RelatedUrl
                            remediationText = $_.Remediation.Text
                            remediationUrl  = $_.Remediation.Url
                            disabled        = [bool]$_.Disabled
                        }
                    }
                    @($checksData) | Out-UDDataGridData -Context $EventData -TotalRows @($checksData).Count
                } -CheckboxSelection -CheckboxSelectionVisibleOnly -OnSelectionChange {
                    $Session:SelectedCheckIds = @($EventData)
                    Sync-UDElement -Id 'selectionSummary'
                } -Columns @(
                    New-UDDataGridColumn -Field 'info' -HeaderName 'Info' -Width 60 -Render {
                        New-UDIconButton -Icon (New-UDIcon -Icon 'InfoCircle') -Size 'small' -OnClick {
                            Show-UDModal -Header {
                                New-UDTypography -Text $EventData.title -Variant 'h6'
                            } -Content {
                                $sev = $EventData.severity.ToUpper()
                                $sevColor = switch ($sev) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } 'MEDIUM' { '#ff9800' } 'LOW' { '#2196f3' } default { '#666' } }
                                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '16px' } } -Content {
                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                        New-UDChip -Label $sev -Style @{ backgroundColor = $sevColor; color = 'white' }
                                        New-UDChip -Label $EventData.provider -Variant 'outlined'
                                        New-UDChip -Label $EventData.service -Variant 'outlined'
                                    }
                                }
                                New-UDTypography -Text 'Description' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                New-UDTypography -Text $EventData.description -Variant 'body2' -Style @{ marginBottom = '16px' }
                                New-UDTypography -Text 'Risk' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                New-UDTypography -Text $EventData.risk -Variant 'body2' -Style @{ marginBottom = '16px' }
                                if ($EventData.remediationText) {
                                    New-UDTypography -Text 'Remediation' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                    New-UDTypography -Text $EventData.remediationText -Variant 'body2' -Style @{ marginBottom = '16px' }
                                }
                                New-UDTypography -Text 'Check ID' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                New-UDTypography -Text $EventData.checkId -Variant 'body2' -Style @{ marginBottom = '16px'; fontFamily = 'monospace' }
                            } -Footer {
                                New-UDStack -Direction 'row' -Spacing 2 -Content {
                                    if ($EventData.relatedUrl) {
                                        New-UDButton -Text 'Documentation' -Variant 'outlined' -OnClick { Invoke-UDRedirect -Url $EventData.relatedUrl -OpenInNewWindow }
                                    }
                                    if ($EventData.remediationUrl) {
                                        New-UDButton -Text 'Remediation' -Variant 'outlined' -OnClick { Show-UDToast -Message 'This is where we could link to Devolutions PAM articles on how PAM remediates this.' -Duration 5000 }
                                    }
                                    New-UDButton -Text 'Close' -OnClick { Hide-UDModal }
                                }
                            } -FullWidth -MaxWidth 'md' -Dividers
                        }
                    }
                    New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 110 -Render {
                        $sev = $EventData.severity.ToUpper()
                        if ($EventData.disabled) {
                            New-UDChip -Label $sev -Style @{ backgroundColor = '#e0e0e0'; color = '#bbb' }
                        } else {
                            $color = switch ($sev) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } 'MEDIUM' { '#ff9800' } 'LOW' { '#2196f3' } default { '#666' } }
                            New-UDChip -Label $sev -Style @{ backgroundColor = $color; color = 'white' }
                        }
                    }
                    New-UDDataGridColumn -Field 'provider' -HeaderName 'Provider' -Width 100 -Render {
                        $textColor = if ($EventData.disabled) { '#bbb' } else { 'inherit' }
                        New-UDElement -Tag 'span' -Attributes @{ style = @{ color = $textColor } } -Content { $EventData.provider }
                    }
                    New-UDDataGridColumn -Field 'service' -HeaderName 'Service' -Width 130 -Render {
                        $textColor = if ($EventData.disabled) { '#bbb' } else { 'inherit' }
                        New-UDElement -Tag 'span' -Attributes @{ style = @{ color = $textColor } } -Content { $EventData.service }
                    }
                    New-UDDataGridColumn -Field 'title' -HeaderName 'Title' -Flex 1 -Render {
                        $textColor = if ($EventData.disabled) { '#bbb' } else { 'inherit' }
                        New-UDElement -Tag 'span' -Attributes @{ style = @{ color = $textColor } } -Content { $EventData.title }
                    }
                    New-UDDataGridColumn -Field 'checkId' -HeaderName 'Check ID' -Width 280 -Render {
                        $textColor = if ($EventData.disabled) { '#bbb' } else { 'inherit' }
                        New-UDElement -Tag 'span' -Attributes @{ style = @{ color = $textColor } } -Content { $EventData.checkId }
                    }
                ) -DisableRowSelectionOnClick -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -Density 'compact'
            }

            # Scan Progress Area - stores scan state and results
            New-UDElement -Tag 'div' -Id 'scanProgressArea' -Content {
                # Initially empty - populated during scan via Set-UDElement
            }

            # Action Buttons
            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '16px' } } -Content {
                New-UDButton -Id 'startScanBtn' -Text 'Start Scan' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                    try {
                        Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                        Write-CIEMLog -Message "Start Scan button clicked" -Severity INFO -Component 'PSU-ScanPage'

                        # Read selected check IDs from session state (synced by OnSelectionChange), strip any disabled checks
                        $allChecks = @(Get-CIEMCheck)
                        $enabledCheckIds = @($allChecks | Where-Object { -not $_.Disabled } | Select-Object -ExpandProperty Id)
                        $selectedCheckIds = @(@($Session:SelectedCheckIds) | Where-Object { $enabledCheckIds -contains $_ })

                        if ($selectedCheckIds.Count -eq 0) {
                            Show-UDToast -Message 'Please select at least one check.' -Duration 5000 -BackgroundColor '#ff9800'
                            return
                        }

                        # Derive selected providers and services from selected checks
                        $selectedChecks = @($allChecks | Where-Object { $selectedCheckIds -contains $_.Id })
                        $selectedProviders = @($selectedChecks | Select-Object -ExpandProperty Provider -Unique)
                        $selectedServices = @($selectedChecks | Select-Object -ExpandProperty Service -Unique)
                        Write-CIEMLog -Message "Scan config: Checks=$($selectedCheckIds.Count)/$($allChecks.Count), Providers=$($selectedProviders -join ','), Services=$($selectedServices -join ',')" -Severity INFO -Component 'PSU-ScanPage'

                        # Show progress area
                        Set-UDElement -Id 'scanProgressArea' -Content {
                            New-UDCard -Style @{ backgroundColor = '#f5f5f5'; marginTop = '16px'; marginBottom = '16px' } -Content {
                                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                    New-UDProgress -Circular -Size 'small'
                                    New-UDTypography -Id 'scanStatusText' -Text 'Initializing scan...' -Variant 'body1'
                                }
                            }
                        }

                        # Disable scan button
                        Set-UDElement -Id 'startScanBtn' -Properties @{ disabled = $true }

                        $scanStart = Get-Date

                        # Update status
                        Set-UDElement -Id 'scanStatusText' -Properties @{ children = "Scanning $($selectedCheckIds.Count) checks across $($selectedProviders -join ', ')..." }
                        Show-UDToast -Message "Starting CIEM scan: $($selectedCheckIds.Count) checks across $($selectedServices -join ', ')" -Duration 3000

                        # Single Invoke-CIEMScan call — handles connection and per-provider looping internally
                        Write-CIEMLog -Message "Calling Invoke-CIEMScan for providers: $($selectedProviders -join ', ')..." -Severity INFO -Component 'PSU-ScanPage'
                        try {
                            $scanParams = @{
                                Provider      = $selectedProviders
                                Service       = $selectedServices
                                IncludePassed = $true
                            }
                            # Only pass CheckId if a subset of checks is selected
                            $totalProviderChecks = @($allChecks | Where-Object { $selectedProviders -contains [string]$_.Provider }).Count
                            if ($selectedCheckIds.Count -lt $totalProviderChecks) {
                                $scanParams['CheckId'] = $selectedCheckIds
                            }
                            $scanResults = @(Invoke-CIEMScan @scanParams -Verbose 4>&1 | ForEach-Object {
                                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                                    Write-CIEMLog -Message $_.Message -Severity DEBUG -Component 'PSU-ScanPage'
                                }
                                else {
                                    $_
                                }
                            })

                            # Get the completed ScanRun from cache (Invoke-CIEMScan persists it)
                            $scanRuns = @(Get-CIEMScanRun)
                            $scanRun = $scanRuns[0]  # Most recent

                            # Process scan results (extract all status counts at top level for uniform access)
                            $allResults = @($scanResults)
                            $failedCount = $scanRun.FailedResults
                            $passedCount = $scanRun.PassedResults
                            $manualCount = $scanRun.ManualResults
                            $skippedCount = $scanRun.SkippedResults
                            $totalCount = $scanRun.TotalResults
                            $durationStr = $scanRun.Duration

                            Write-CIEMLog -Message "Scan complete. Results: $($allResults.Count), Duration: $durationStr" -Severity INFO -Component 'PSU-ScanPage'

                            # Store in session for quick page access
                            $Session:CIEMScanResults = $allResults
                            $Session:CIEMScanTimestamp = $scanRun.EndTime
                            $Session:CIEMIncludePassed = $true

                            Write-CIEMLog -Message "Persisted $($allResults.Count) scan results (ScanRunId: $($scanRun.Id))" -Severity INFO -Component 'PSU-ScanPage'

                            # Update progress area with results summary
                            Set-UDElement -Id 'scanProgressArea' -Content {
                                New-UDCard -Style @{ backgroundColor = '#e8f5e9'; marginTop = '16px'; marginBottom = '16px' } -Content {
                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                        New-UDIcon -Icon 'CheckCircle' -Size 'lg' -Style @{ color = '#4caf50' }
                                        New-UDElement -Tag 'div' -Content {
                                            New-UDTypography -Text 'Scan Complete!' -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#2e7d32' }
                                            # Show all status counts uniformly (provider-agnostic; vars set in parent scope)
                                            $summaryParts = @("Duration: $durationStr", "Total: $totalCount", "Failed: $failedCount", "Passed: $passedCount")
                                            if ($manualCount -gt 0) { $summaryParts += "Manual: $manualCount" }
                                            if ($skippedCount -gt 0) { $summaryParts += "Skipped: $skippedCount" }
                                            New-UDTypography -Text ($summaryParts -join ' | ') -Variant 'body2' -Style @{ color = '#666' }
                                            New-UDTypography -Text 'View detailed results on the Scan History page.' -Variant 'caption' -Style @{ color = '#666'; marginTop = '4px' }
                                        }
                                    }
                                }
                            }

                            # Toast with meaningful summary regardless of provider (includes all statuses)
                            $toastParts = @("Scan complete!")
                            if ($failedCount -gt 0) { $toastParts += "$failedCount failed" }
                            if ($passedCount -gt 0) { $toastParts += "$passedCount passed" }
                            if ($manualCount -gt 0) { $toastParts += "$manualCount manual review" }
                            Show-UDToast -Message ($toastParts -join ' | ') -Duration 5000 -BackgroundColor '#4caf50'

                            # Redirect to scan history page to view results
                            Show-UDToast -Message 'View detailed results on the Scan History page.' -Duration 5000
                        }
                        catch {
                            Write-CIEMLog -Message "Scan failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ScanPage'
                            Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ScanPage'

                            Set-UDElement -Id 'scanProgressArea' -Content {
                                New-CIEMErrorContent -Text 'Scan Failed' -Details $_.Exception.Message
                            }

                            Show-UDToast -Message "Scan failed: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                        }
                        finally {
                            # Re-enable scan button
                            Set-UDElement -Id 'startScanBtn' -Properties @{ disabled = $false }
                        }
                    }
                    catch {
                        Write-CIEMLog -Message "Scan button handler error: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ScanPage'
                        Show-UDToast -Message "Error: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                        Set-UDElement -Id 'startScanBtn' -Properties @{ disabled = $false }
                    }
                }
            }
        }

    } -Navigation $Navigation -NavigationLayout permanent
}
