function New-DevolutionsCIEMApp {
    <#
    .SYNOPSIS
        Creates the Devolutions CIEM PowerShell Universal App.
    .DESCRIPTION
        Returns a PSU dashboard for Cloud Infrastructure Entitlement Management.
        This function is called by PSU when the app is loaded via the -Module/-Command pattern.
    .EXAMPLE
        New-DevolutionsCIEMApp
    .NOTES
        This function is exported for PSU to invoke via New-PSUApp -Module -Command.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates in-memory PSU dashboard object, no system state change')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidReturnStatement', '', Justification = 'Return statements required for early exit in PSU OnClick handlers')]
    param()

    begin {
        # UI helper functions (Get-SeverityColor, Get-StatusColor, New-CIEMProgressContent,
        # New-CIEMSuccessContent, New-CIEMErrorContent) are in Private/New-CIEMUIContent.ps1
        # They must be module-level functions to be accessible in PSU page scopes.

        # Helper function to create navigation items
        function New-CIEMNavigation {
            @(
                New-UDListItem -Label 'Dashboard' -Icon (New-UDIcon -Icon 'Home') -Href '/ciem'
                New-UDListItem -Label 'Cloud Checks' -Icon (New-UDIcon -Icon 'ListCheck') -Href '/ciem/checks'
                New-UDListItem -Label 'Scan' -Icon (New-UDIcon -Icon 'Play') -Href '/ciem/scan'
                New-UDListItem -Label 'Configuration' -Icon (New-UDIcon -Icon 'Cog') -Href '/ciem/config'
                New-UDListItem -Label 'About' -Icon (New-UDIcon -Icon 'InfoCircle') -Href '/ciem/about'
            )
        }

        # Helper function to create the Dashboard page
        function New-CIEMDashboardPage {
            param($Navigation)

            New-UDPage -Name 'Dashboard' -Url '/ciem' -Content {
                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue

                # Load scan results from: 1) session, 2) ScanRun cache
                $rawResults = $null
                $scanTimestamp = $null

                # Priority 1: Session storage
                if ($Session:CIEMScanResults -and $Session:CIEMScanResults.Count -gt 0) {
                    $rawResults = $Session:CIEMScanResults
                    $scanTimestamp = $Session:CIEMScanTimestamp
                }
                # Priority 2: Get most recent ScanRun from cache
                else {
                    try {
                        $scanRuns = @(Get-CIEMScanRun -IncludeResults)
                        if ($scanRuns -and $scanRuns.Count -gt 0) {
                            $currentRun = $scanRuns[0]
                            if ($currentRun.ScanResults -and $currentRun.ScanResults.Count -gt 0) {
                                $rawResults = $currentRun.ScanResults
                                $scanTimestamp = $currentRun.EndTime

                                # Restore to session for faster subsequent access
                                $Session:CIEMScanResults = $rawResults
                                $Session:CIEMScanTimestamp = $scanTimestamp
                                $Session:CIEMIncludePassed = $currentRun.IncludePassed
                            }
                        }
                    }
                    catch { }
                }

                New-UDTypography -Text 'Devolutions CIEM Dashboard' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
                New-UDTypography -Text 'Cloud Infrastructure Entitlement Management - Scan Results Overview' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

                if ($rawResults -and $rawResults.Count -gt 0) {
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

                    # Show scan timestamp
                    $timestampStr = if ($scanTimestamp) { ([datetime]$scanTimestamp).ToString('yyyy-MM-dd HH:mm:ss') } else { 'Unknown' }
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
                        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                            New-UDChip -Label "Last Scan: $timestampStr" -Icon (New-UDIcon -Icon 'Clock') -Size 'small' -Style @{ backgroundColor = '#e3f2fd' }
                            New-UDButton -Text 'Run New Scan' -Variant 'outlined' -Size 'small' -OnClick {
                                Invoke-UDRedirect '/ciem/scan'
                            }
                        }
                    }

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

                    New-UDGrid -Container -Content {
                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                            New-UDCard -Title 'Results by Severity' -Content {
                                $SeverityData = @(
                                    @{ Name = 'Critical'; Count = $CriticalCount; color = '#9c27b0' }
                                    @{ Name = 'High'; Count = $HighCount; color = '#f44336' }
                                    @{ Name = 'Medium'; Count = $MediumCount; color = '#ff9800' }
                                    @{ Name = 'Low'; Count = $LowCount; color = '#2196f3' }
                                ) | Where-Object { $_.Count -gt 0 }
                                if ($SeverityData.Count -gt 0) {
                                    New-UDChartJS -Type 'doughnut' -Data $SeverityData -DataProperty Count -LabelProperty Name -BackgroundColor @('#9c27b0', '#f44336', '#ff9800', '#2196f3')
                                } else {
                                    New-UDTypography -Text 'No failed results' -Style @{ textAlign = 'center'; padding = '40px' }
                                }
                            }
                        }
                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                            New-UDCard -Title 'Results by Service' -Content {
                                $ServiceData = $FailedResults | Group-Object -Property Service | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
                                if ($ServiceData.Count -gt 0) {
                                    New-UDChartJS -Type 'bar' -Data $ServiceData -DataProperty Count -LabelProperty Name -BackgroundColor '#1976d2'
                                } else {
                                    New-UDTypography -Text 'No failed results' -Style @{ textAlign = 'center'; padding = '40px' }
                                }
                            }
                        }
                    }

                    New-UDCard -Title 'Recent Critical & High Results' -Style @{ marginTop = '20px' } -Content {
                        $CriticalHighResults = $FailedResults | Where-Object { $_.Severity.ToUpper() -in @('CRITICAL', 'HIGH') } | Select-Object -First 5
                        if (@($CriticalHighResults).Count -gt 0) {
                            New-UDTable -Data $CriticalHighResults -Columns @(
                                New-UDTableColumn -Property 'CheckId' -Title 'Check ID'
                                New-UDTableColumn -Property 'Title' -Title 'Result'
                                New-UDTableColumn -Property 'Severity' -Title 'Severity' -Render {
                                    $sev = $EventData.Severity.ToUpper()
                                    $color = switch ($sev) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } default { '#666' } }
                                    New-UDChip -Label $sev -Style @{ backgroundColor = $color; color = 'white' }
                                }
                                New-UDTableColumn -Property 'Service' -Title 'Service'
                                New-UDTableColumn -Property 'ResourceName' -Title 'Resource'
                            )
                            New-UDButton -Text 'View All Results' -Variant 'outlined' -OnClick {
                                Invoke-UDRedirect '/ciem/scan'
                            } -Style @{ marginTop = '12px' }
                        } else {
                            New-UDStack -Direction 'column' -AlignItems 'center' -Content {
                                New-UDIcon -Icon 'CheckCircle' -Size '3x' -Style @{ color = '#4caf50'; marginBottom = '12px' }
                                New-UDTypography -Text 'No critical or high severity results!' -Style @{ color = '#4caf50' }
                            } -Style @{ padding = '20px' }
                        }
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

        # Helper function to create the Scan page
        function New-CIEMScanPage {
            param($Navigation)

            New-UDPage -Name 'Scan' -Url '/ciem/scan' -Content {
                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue

                New-UDTypography -Text 'Run CIEM Scan' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
                New-UDTypography -Text 'Configure and execute a CIEM security scan against your cloud environment' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

                # Provider Selector
                $enabledProviders = @(Get-CIEMProvider | Where-Object Enabled)
                if ($enabledProviders.Count -gt 1) {
                    New-UDCard -Style @{ marginBottom = '20px' } -Content {
                        New-UDSelect -Id 'scanProvider' -Label 'Cloud Provider' -Option {
                            foreach ($ep in $enabledProviders) {
                                New-UDSelectOption -Name $ep.Name -Value $ep.Name
                            }
                        } -DefaultValue $enabledProviders[0].Name -FullWidth -OnChange {
                            $Session:SelectedProvider = $EventData
                            $Session:SelectedCheckIds = $null
                            Sync-UDElement -Id 'checkSelectionGrid'
                        }
                    }
                }
                else {
                    # Single provider - show as chip, set session
                    $singleProvider = if ($enabledProviders.Count -eq 1) { $enabledProviders[0].Name } else { 'Azure' }
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '20px' } } -Content {
                        New-UDChip -Label "Provider: $singleProvider" -Icon (New-UDIcon -Icon 'Cloud') -Style @{ backgroundColor = '#1976d2'; color = 'white' }
                    }
                    # Hidden element to hold provider value
                    New-UDElement -Tag 'input' -Id 'scanProvider' -Attributes @{ type = 'hidden'; value = $singleProvider }
                }
                $Session:SelectedProvider = if ($enabledProviders.Count -ge 1) { $enabledProviders[0].Name } else { 'Azure' }

                # Scan Configuration Card
                New-UDCard -Title 'Scan Configuration' -Content {
                    # Check selection data grid with checkboxes
                    New-UDDynamic -Id 'checkSelectionGrid' -Content {
                        Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                        $selectedProvider = if ($Session:SelectedProvider) { $Session:SelectedProvider } else { 'Azure' }
                        $allChecks = @(Get-CIEMCheck -Provider $selectedProvider)

                        # Initialize selected checks (default: all) on first load
                        if ($null -eq $Session:SelectedCheckIds) {
                            $Session:SelectedCheckIds = @($allChecks | Select-Object -ExpandProperty Id)
                        }

                        # Selection summary
                        New-UDDynamic -Id 'selectionSummary' -Content {
                            Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                            $provider = if ($Session:SelectedProvider) { $Session:SelectedProvider } else { 'Azure' }
                            $checks = @(Get-CIEMCheck -Provider $provider)
                            $selectedCount = @($Session:SelectedCheckIds).Count
                            $totalCount = $checks.Count
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '8px' } } -Content {
                                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                    New-UDTypography -Text "$selectedCount / $totalCount checks selected" -Variant 'body2' -Style @{ color = '#666' }
                                    $selectedChecks = @($checks | Where-Object { $Session:SelectedCheckIds -contains $_.Id })
                                    $sevGroups = $selectedChecks | Group-Object Severity
                                    foreach ($sg in ($sevGroups | Sort-Object { switch ($_.Name) { 'CRITICAL' { 0 } 'HIGH' { 1 } 'MEDIUM' { 2 } 'LOW' { 3 } default { 4 } } })) {
                                        $sevColor = Get-SeverityColor -Severity $sg.Name
                                        New-UDChip -Label "$($sg.Name[0]):$($sg.Count)" -Size 'small' -Style @{ backgroundColor = $sevColor; color = 'white'; height = '22px'; fontSize = '11px' }
                                    }
                                }
                            }
                        }

                        New-UDDataGrid -Id 'checkSelector' -LoadRows {
                            Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                            $provider = if ($Session:SelectedProvider) { $Session:SelectedProvider } else { 'Azure' }
                            $checks = @(Get-CIEMCheck -Provider $provider)
                            $checksData = $checks | ForEach-Object {
                                @{
                                    id       = $_.Id
                                    checkId  = $_.Id
                                    title    = $_.Title
                                    service  = [string]$_.Service
                                    severity = ([string]$_.Severity -replace '^(.)', { $_.Groups[1].Value.ToUpper() })
                                }
                            }
                            @($checksData) | Out-UDDataGridData -Context $EventData -TotalRows @($checksData).Count
                        } -Columns @(
                            New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 110 -Render {
                                $sev = $EventData.severity.ToUpper()
                                $color = switch ($sev) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } 'MEDIUM' { '#ff9800' } 'LOW' { '#2196f3' } default { '#666' } }
                                New-UDChip -Label $sev -Style @{ backgroundColor = $color; color = 'white' }
                            }
                            New-UDDataGridColumn -Field 'service' -HeaderName 'Service' -Width 130
                            New-UDDataGridColumn -Field 'title' -HeaderName 'Title' -Flex 1
                            New-UDDataGridColumn -Field 'checkId' -HeaderName 'Check ID' -Width 280
                        ) -CheckboxSelection -DisableRowSelectionOnClick -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -OnSelectionChange {
                            $Session:SelectedCheckIds = @($EventData)
                            Sync-UDElement -Id 'selectionSummary'
                        } -Density 'compact'
                    }

                    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '16px'; marginBottom = '16px' } } -Content {
                        New-UDCheckbox -Id 'includePassedChecks' -Label 'Include Passed Checks in Results' -Checked $true
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

                                # Get selected provider
                                $selectedProvider = if ($Session:SelectedProvider) { $Session:SelectedProvider } else { 'Azure' }

                                # Connect to provider (handles all auth internally)
                                Write-CIEMLog -Message "Connecting to $selectedProvider..." -Severity INFO -Component 'PSU-ScanPage'
                                $connectResult = Connect-CIEM -Provider $selectedProvider -Force
                                $connectProvider = $connectResult.Providers | Where-Object { $_.Provider -eq $selectedProvider }

                                if ($connectProvider.Status -ne 'Connected') {
                                    Write-CIEMLog -Message "Connect failed: $($connectProvider.Message)" -Severity ERROR -Component 'PSU-ScanPage'
                                    Show-UDToast -Message "Connection failed: $($connectProvider.Message)" -Duration 8000 -BackgroundColor '#f44336'
                                    return
                                }
                                Write-CIEMLog -Message "Connected: $($connectProvider.Account)" -Severity INFO -Component 'PSU-ScanPage'

                                # Read selected check IDs from session state
                                $allChecks = @(Get-CIEMCheck -Provider $selectedProvider)
                                $selectedCheckIds = @($Session:SelectedCheckIds)

                                if ($selectedCheckIds.Count -eq 0) {
                                    Show-UDToast -Message 'Please select at least one check.' -Duration 5000 -BackgroundColor '#ff9800'
                                    return
                                }

                                $includePassedChecks = (Get-UDElement -Id 'includePassedChecks').checked

                                # Derive selected services for progress message
                                $selectedServices = @($allChecks | Where-Object { $selectedCheckIds -contains $_.Id } | Select-Object -ExpandProperty Service -Unique)
                                Write-CIEMLog -Message "Scan config: Checks=$($selectedCheckIds.Count)/$($allChecks.Count), Services=$($selectedServices -join ','), IncludePassed=$includePassedChecks" -Severity INFO -Component 'PSU-ScanPage'

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
                                Set-UDElement -Id 'scanStatusText' -Properties @{ children = "Scanning $($selectedCheckIds.Count) checks across $($selectedServices.Count) services..." }
                                Show-UDToast -Message "Starting CIEM scan: $($selectedCheckIds.Count) checks across $($selectedServices -join ', ')" -Duration 3000

                                # Run the actual scan — use -CheckId when subset selected, omit when all selected
                                Write-CIEMLog -Message "Calling Invoke-CIEMScan..." -Severity INFO -Component 'PSU-ScanPage'
                                try {
                                    $scanParams = @{ Provider = $selectedProvider; Service = $selectedServices; IncludePassed = $includePassedChecks }
                                    if ($selectedCheckIds.Count -lt $allChecks.Count) {
                                        $scanParams['CheckId'] = $selectedCheckIds
                                    }
                                    $scanResults = Invoke-CIEMScan @scanParams -Verbose 4>&1 | ForEach-Object {
                                        if ($_ -is [System.Management.Automation.VerboseRecord]) {
                                            Write-CIEMLog -Message $_.Message -Severity DEBUG -Component 'PSU-ScanPage'
                                        }
                                        else {
                                            $_ # Pass through scan results
                                        }
                                    }

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
                                    $Session:CIEMIncludePassed = $includePassedChecks

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
                                                    New-UDTypography -Text 'Expand the scan in the history below to view detailed results.' -Variant 'caption' -Style @{ color = '#666'; marginTop = '4px' }
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

                                    # Refresh scan history
                                    Sync-UDElement -Id 'scanHistoryPanel'
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

                # Scan History Card with expandable results
                New-UDCard -Title 'Scan History & Results' -Style @{ marginTop = '20px' } -Content {
                    New-UDTypography -Text 'Click on a scan to expand and view detailed results' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '12px' }

                    New-UDDynamic -Id 'scanHistoryPanel' -Content {
                        Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                        try {
                            $scanRuns = @(Get-CIEMScanRun)

                            if ($scanRuns -and $scanRuns.Count -gt 0) {
                                New-UDDataGrid -LoadRows {
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    $runs = @(Get-CIEMScanRun)
                                    $historyData = $runs | ForEach-Object {
                                        @{
                                            id       = $_.Id
                                            date     = ([datetime]$_.StartTime).ToString('yyyy-MM-dd HH:mm')
                                            provider = [string]$_.Provider
                                            services = ($_.Services -join ', ')
                                            status   = [string]$_.Status
                                            failed   = $_.FailedResults
                                            passed   = $_.PassedResults
                                            manual   = $_.ManualResults  # show all statuses uniformly
                                            skipped  = $_.SkippedResults
                                            duration = $_.Duration
                                        }
                                    }
                                    @($historyData) | Out-UDDataGridData -Context $EventData -TotalRows @($historyData).Count
                                } -Columns @(
                                    New-UDDataGridColumn -Field 'date' -HeaderName 'Scan Date' -Width 150
                                    New-UDDataGridColumn -Field 'provider' -HeaderName 'Provider' -Width 100
                                    New-UDDataGridColumn -Field 'services' -HeaderName 'Services' -Flex 1
                                    New-UDDataGridColumn -Field 'status' -HeaderName 'Status' -Width 110 -Render {
                                        $statusColors = @{ 'Completed' = '#4caf50'; 'Running' = '#2196f3'; 'Failed' = '#f44336' }
                                        $color = $statusColors[$EventData.status]
                                        if (-not $color) { $color = '#666' }
                                        New-UDChip -Label $EventData.status -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                                    }
                                    New-UDDataGridColumn -Field 'failed' -HeaderName 'Failed' -Width 90 -Render {
                                        $color = if ($EventData.failed -gt 0) { '#f44336' } else { '#4caf50' }
                                        New-UDChip -Label $EventData.failed -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                                    }
                                    New-UDDataGridColumn -Field 'passed' -HeaderName 'Passed' -Width 90 -Render {
                                        New-UDChip -Label $EventData.passed -Size 'small' -Style @{ backgroundColor = '#4caf50'; color = 'white' }
                                    }
                                    New-UDDataGridColumn -Field 'manual' -HeaderName 'Manual' -Width 90 -Render {
                                        $color = if ($EventData.manual -gt 0) { '#1565c0' } else { '#9e9e9e' }
                                        New-UDChip -Label $EventData.manual -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                                    }
                                    New-UDDataGridColumn -Field 'skipped' -HeaderName 'Skipped' -Width 90 -Render {
                                        $color = if ($EventData.skipped -gt 0) { '#ff9800' } else { '#9e9e9e' }
                                        New-UDChip -Label $EventData.skipped -Size 'small' -Style @{ backgroundColor = $color; color = 'white' }
                                    }
                                    New-UDDataGridColumn -Field 'duration' -HeaderName 'Duration' -Width 100
                                ) -AutoHeight $true -Pagination -PageSize 10 -ExportOptions @('CSV', 'JSON') -OnExport {
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    $runs = @(Get-CIEMScanRun -IncludeResults)

                                    if ($EventData.Type -eq 'CSV') {
                                        $csvData = $runs | ForEach-Object {
                                            [PSCustomObject]@{
                                                Id        = $_.Id
                                                Provider  = $_.Provider
                                                Services  = ($_.Services -join ', ')
                                                Status    = [string]$_.Status
                                                StartTime = ([datetime]$_.StartTime).ToString('yyyy-MM-dd HH:mm:ss')
                                                EndTime   = if ($_.EndTime) { ([datetime]$_.EndTime).ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                                                Duration  = $_.Duration
                                                Failed    = $_.FailedResults
                                                Passed    = $_.PassedResults
                                                Manual    = $_.ManualResults  # include all statuses in export
                                                Skipped   = $_.SkippedResults
                                            }
                                        }
                                        $exportContent = $csvData | ConvertTo-Csv -NoTypeInformation | Out-String
                                        Out-UDDataGridExport -Data $exportContent -FileName "ciem-scans-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
                                    }
                                    elseif ($EventData.Type -eq 'JSON') {
                                        $jsonData = $runs | ForEach-Object {
                                            [ordered]@{
                                                id           = $_.Id
                                                provider     = $_.Provider
                                                services     = $_.Services
                                                status       = [string]$_.Status
                                                startTime    = ([datetime]$_.StartTime).ToString('o')
                                                endTime      = if ($_.EndTime) { ([datetime]$_.EndTime).ToString('o') } else { $null }
                                                duration     = $_.Duration
                                                failedCount  = $_.FailedResults
                                                passedCount  = $_.PassedResults
                                                manualCount  = $_.ManualResults  # include all statuses in export
                                                skippedCount = $_.SkippedResults
                                                scan_results = @($_.ScanResults | ForEach-Object {
                                                    [ordered]@{
                                                        checkId        = $_.Check.Id
                                                        status         = $_.Status
                                                        severity       = [string]$_.Check.Severity
                                                        resourceId     = $_.ResourceId
                                                        resourceName   = $_.ResourceName
                                                        location       = $_.Location
                                                        statusExtended = $_.StatusExtended
                                                    }
                                                })
                                            }
                                        }
                                        $exportContent = $jsonData | ConvertTo-Json -Depth 10
                                        Out-UDDataGridExport -Data $exportContent -FileName "ciem-scans-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
                                    }
                                } -LoadDetailContent {
                                    # Load scan results for this specific scan run
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    $scanRunId = $EventData.row.id

                                    try {
                                        $scanRun = Get-CIEMScanRun -Id $scanRunId -IncludeResults
                                        $rawResults = $scanRun.ScanResults

                                        if ($rawResults -and $rawResults.Count -gt 0) {
                                            $enrichedResults = $rawResults | ForEach-Object {
                                                $result = $_
                                                @{
                                                    id = $result.Check.Id + '_' + ($result.ResourceId -replace '[^\w]', '_')
                                                    checkId = $result.Check.Id
                                                    title = $result.Check.Title
                                                    severity = ([string]$result.Check.Severity -replace '^(.)', { $_.Groups[1].Value.ToUpper() })
                                                    status = $result.Status
                                                    service = [string]$result.Check.Service
                                                    resourceId = $result.ResourceId
                                                    resourceName = $result.ResourceName
                                                    location = $result.Location
                                                    description = $result.Check.Description
                                                    statusExtended = $result.StatusExtended
                                                    remediation = if ($result.Check.Remediation -and $result.Check.Remediation.Text) { $result.Check.Remediation.Text } else { 'See Devolutions PAM for remediation guidance.' }
                                                    relatedUrl = $result.Check.RelatedUrl
                                                }
                                            }

                                            # Apply passed filter if not included
                                            if (-not $scanRun.IncludePassed) {
                                                $enrichedResults = $enrichedResults | Where-Object { $_.status -ne 'PASS' }
                                            }

                                            New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '16px'; backgroundColor = '#fafafa' } } -Content {
                                                # Summary chips (provider-agnostic — show all statuses uniformly)
                                                $failedCount = @($enrichedResults | Where-Object { $_.status -eq 'FAIL' }).Count
                                                $passedCount = @($enrichedResults | Where-Object { $_.status -eq 'PASS' }).Count
                                                $manualCount = @($enrichedResults | Where-Object { $_.status -eq 'MANUAL' }).Count
                                                $skippedCount = @($enrichedResults | Where-Object { $_.status -eq 'SKIPPED' }).Count
                                                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '16px' } } -Content {
                                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                        New-UDTypography -Text 'Scan Results' -Variant 'h6'
                                                        New-UDChip -Label "Failed: $failedCount" -Size 'small' -Style @{ backgroundColor = '#ffebee'; color = '#c62828' }
                                                        New-UDChip -Label "Passed: $passedCount" -Size 'small' -Style @{ backgroundColor = '#e8f5e9'; color = '#2e7d32' }
                                                        if ($manualCount -gt 0) { New-UDChip -Label "Manual: $manualCount" -Size 'small' -Style @{ backgroundColor = '#e3f2fd'; color = '#1565c0' } }
                                                        if ($skippedCount -gt 0) { New-UDChip -Label "Skipped: $skippedCount" -Size 'small' -Style @{ backgroundColor = '#fff3e0'; color = '#e65100' } }
                                                    }
                                                }

                                                # Results DataGrid - use pre-loaded data from parent scope
                                                $resultsData = $enrichedResults
                                                New-UDDataGrid -LoadRows {
                                                    $resultsData | Out-UDDataGridData -Context $EventData -TotalRows @($resultsData).Count
                                                } -Columns @(
                                                    New-UDDataGridColumn -Field 'checkId' -HeaderName 'Check ID' -Width 200
                                                    New-UDDataGridColumn -Field 'title' -HeaderName 'Finding' -Flex 1
                                                    New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 110 -Render {
                                                        $sev = $EventData.severity.ToUpper()
                                                        $color = switch ($sev) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } 'MEDIUM' { '#ff9800' } 'LOW' { '#2196f3' } 'INFO' { '#4caf50' } default { '#666' } }
                                                        New-UDChip -Label $sev -Style @{ backgroundColor = $color; color = 'white' }
                                                    }
                                                    New-UDDataGridColumn -Field 'status' -HeaderName 'Status' -Width 100 -Render {
                                                        $statusColors = @{ 'FAIL' = '#f44336'; 'PASS' = '#4caf50'; 'MANUAL' = '#ff9800'; 'SKIPPED' = '#9e9e9e' }
                                                        $color = $statusColors[$EventData.status]
                                                        if (-not $color) { $color = '#666' }
                                                        New-UDChip -Label $EventData.status -Style @{ backgroundColor = $color; color = 'white' }
                                                    }
                                                    New-UDDataGridColumn -Field 'statusExtended' -HeaderName 'Status Description' -Flex 1
                                                    New-UDDataGridColumn -Field 'service' -HeaderName 'Service' -Width 100
                                                    New-UDDataGridColumn -Field 'resourceName' -HeaderName 'Resource' -Width 180
                                                ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter
                                            }
                                        }
                                        else {
                                            New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '20px'; textAlign = 'center' } } -Content {
                                                New-UDTypography -Text 'No results available for this scan.' -Variant 'body2' -Style @{ color = '#666' }
                                            }
                                        }
                                    }
                                    catch {
                                        New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '20px'; textAlign = 'center' } } -Content {
                                            New-UDTypography -Text "Error loading results: $($_.Exception.Message)" -Variant 'body2' -Style @{ color = '#f44336' }
                                        }
                                    }
                                }
                            }
                            else {
                                New-UDTypography -Text 'No scan history available. Run your first scan above!' -Variant 'body2' -Style @{ color = '#666'; fontStyle = 'italic'; padding = '16px' }
                            }
                        }
                        catch {
                            New-UDTypography -Text 'Unable to load scan history.' -Variant 'body2' -Style @{ color = '#666'; fontStyle = 'italic'; padding = '16px' }
                        }
                    }
                }
            } -Navigation $Navigation -NavigationLayout permanent
        }

        # Helper function to create the Configuration page
        function New-CIEMConfigPage {
            param($Navigation)

            New-UDPage -Name 'Configuration' -Url '/ciem/config' -Content {
                # Ensure module functions are available in this page's runspace
                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue

                # Load configuration from PSU cache (or defaults if first run)
                $CurrentConfig = Get-CIEMConfig

                # Get PSU environment
                $envInfo = Get-PSUInstalledEnvironment

                # Get current provider (default to Azure)
                $currentProvider = if ($CurrentConfig.cloudProvider) { $CurrentConfig.cloudProvider } else { 'Azure' }

                # Store original auth values in session state for change detection on save
                # Only initialize on first page load (not on dynamic refreshes)
                if (-not $Session:OriginalAuthValues) {
                    $Session:OriginalAuthValues = @{
                        Provider = $currentProvider
                        Method = if ($CurrentConfig.azure.authentication.method) { $CurrentConfig.azure.authentication.method } else { 'ServicePrincipalSecret' }
                        TenantId = Get-CIEMSecret 'CIEM_Azure_TenantId'
                        ClientId = Get-CIEMSecret 'CIEM_Azure_ClientId'
                        CertThumbprint = Get-CIEMSecret 'CIEM_Azure_CertThumbprint'
                    }
                }

                New-UDTypography -Text 'Configuration' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
                New-UDTypography -Text 'Configure cloud provider authentication for CIEM security scans' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

                New-UDCard -Title 'Cloud Provider Authentication' -Content {
                    # Environment detection indicator (integrated into auth card)
                    New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '16px' } } -Content {
                        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                            New-UDTypography -Text 'Detected Environment:' -Variant 'body2' -Style @{ color = '#666' }
                            if ($envInfo.Environment -eq 'AzureWebApp') {
                                New-UDChip -Label 'Azure Web App' -Icon (New-UDIcon -Icon 'Cloud') -Size 'small' -Style @{
                                    backgroundColor = '#1976d2'
                                    color = 'white'
                                }
                            }
                            else {
                                New-UDChip -Label 'On-Premises' -Icon (New-UDIcon -Icon 'Server') -Size 'small' -Style @{
                                    backgroundColor = '#4caf50'
                                    color = 'white'
                                }
                            }
                        }
                    }

                    # Provider Selection
                    New-UDElement -Tag 'div' -Content {
                        New-UDSelect -Id 'cloudProvider' -Label 'Cloud Provider' -Option {
                            New-UDSelectOption -Name 'Azure' -Value 'Azure'
                            New-UDSelectOption -Name 'AWS' -Value 'AWS'
                        } -DefaultValue $currentProvider -FullWidth -OnChange {
                            # Only sync authMethodContainer - it will sync authFieldsContainer after rendering
                            Sync-UDElement -Id 'authMethodContainer'
                        }
                    } -Attributes @{ style = @{ marginBottom = '16px' } }

                    # Dynamic Authentication Method dropdown based on provider
                    New-UDDynamic -Id 'authMethodContainer' -Content {
                        $selectedProvider = (Get-UDElement -Id 'cloudProvider').value
                        if (-not $selectedProvider) { $selectedProvider = 'Azure' }

                        if ($selectedProvider -eq 'AWS') {
                            $awsAuthMethod = if ($CurrentConfig.aws.authentication.method) { $CurrentConfig.aws.authentication.method } else { 'CurrentProfile' }

                            New-UDElement -Tag 'div' -Content {
                                New-UDSelect -Id 'authMethod' -Label 'Authentication Method' -Option {
                                    New-UDSelectOption -Name 'Current Profile (AWS CLI)' -Value 'CurrentProfile'
                                    New-UDSelectOption -Name 'Access Key' -Value 'AccessKey'
                                } -DefaultValue $awsAuthMethod -FullWidth -OnChange { Sync-UDElement -Id 'authFieldsContainer' }
                            } -Attributes @{ style = @{ marginBottom = '8px' } }

                            New-UDTypography -Text 'Select the authentication method for your AWS environment.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '16px' }

                            Sync-UDElement -Id 'authFieldsContainer'
                        }
                        else {
                            # Azure authentication methods
                            $azureAuthMethod = if ($CurrentConfig.azure.authentication.method) { $CurrentConfig.azure.authentication.method } else { 'ServicePrincipalSecret' }

                            New-UDElement -Tag 'div' -Content {
                                New-UDSelect -Id 'authMethod' -Label 'Authentication Method' -Option {
                                    New-UDSelectOption -Name 'Service Principal (Client Secret)' -Value 'ServicePrincipalSecret'
                                    New-UDSelectOption -Name 'Service Principal (Certificate)' -Value 'ServicePrincipalCertificate'
                                    New-UDSelectOption -Name 'Managed Identity' -Value 'ManagedIdentity'
                                    New-UDSelectOption -Name 'Device Code' -Value 'DeviceCode'
                                    New-UDSelectOption -Name 'Interactive Browser' -Value 'Interactive'
                                } -DefaultValue $azureAuthMethod -FullWidth -OnChange { Sync-UDElement -Id 'authFieldsContainer' }
                            } -Attributes @{ style = @{ marginBottom = '8px' } }

                            # Info about authentication methods
                            New-UDTypography -Text 'Select the authentication method that matches your environment and security requirements.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '16px' }

                            # Sync auth fields after Azure dropdown is rendered (important for provider switch from AWS to Azure)
                            Sync-UDElement -Id 'authFieldsContainer'
                        }
                    }

                    # Dynamic fields based on selected authentication method
                    New-UDDynamic -Id 'authFieldsContainer' -Content {
                        Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                        # Read from UI if available (after user interaction), otherwise fall back to config
                        $uiProvider = (Get-UDElement -Id 'cloudProvider').value
                        $uiMethod = (Get-UDElement -Id 'authMethod').value
                        $selectedProvider = if ($uiProvider) { $uiProvider } elseif ($CurrentConfig.cloudProvider) { $CurrentConfig.cloudProvider } else { 'Azure' }
                        $selectedMethod = if ($uiMethod) { $uiMethod } elseif ($CurrentConfig.azure.authentication.method) { $CurrentConfig.azure.authentication.method } else { 'ServicePrincipalSecret' }

                        # Check for ManagedIdentity warning
                        $envCheck = Get-PSUInstalledEnvironment
                        if ($selectedMethod -eq 'ManagedIdentity' -and -not $envCheck.SupportsManagedIdentity) {
                            New-UDAlert -Severity 'warning' -Text 'Managed Identity will not work in on-premises deployments. Please choose a different authentication method.' -Style @{ marginBottom = '16px' }
                        }

                        # Load credentials: TenantId/ClientId from PSU cache, secrets from PSU secrets
                        $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
                        $configForCreds = Get-CIEMConfig
                        $storedCreds = @{
                            TenantId = $configForCreds.azure.authentication.tenantId
                            ClientId = $configForCreds.azure.authentication.servicePrincipal.clientId
                            ClientSecretExists = $false
                            CertThumbprint = $null
                            CertPasswordExists = $false
                            ManagedIdentityClientId = $null
                        }
                        # Only secrets come from PSU secrets (not TenantId/ClientId which are in cache)
                        $storedCreds.ClientSecretExists = -not [string]::IsNullOrEmpty((Get-CIEMSecret 'CIEM_Azure_ClientSecret'))
                        $storedCreds.CertThumbprint = Get-CIEMSecret 'CIEM_Azure_CertThumbprint'
                        $storedCreds.CertPasswordExists = -not [string]::IsNullOrEmpty((Get-CIEMSecret 'CIEM_Azure_CertPassword'))
                        $storedCreds.ManagedIdentityClientId = Get-CIEMSecret 'CIEM_Azure_ManagedIdentityClientId'

                        if ($selectedProvider -eq 'Azure') {
                            switch ($selectedMethod) {
                                'ServicePrincipalSecret' {
                                    New-UDGrid -Container -Spacing 2 -Content {
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID' -Value $storedCreds.TenantId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azSpClientId' -Label 'Client ID (Application ID)' -Value $storedCreds.ClientId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                            $secretPlaceholder = if ($storedCreds.ClientSecretExists) { 'Secret is stored. Leave empty to keep existing, or enter new value to replace.' } else { 'Enter service principal client secret' }
                                            $secretValue = if ($storedCreds.ClientSecretExists) { '********' } else { '' }
                                            New-UDTextbox -Id 'azSpClientSecret' -Label 'Client Secret' -Type 'password' -Value $secretValue -FullWidth -Placeholder $secretPlaceholder
                                        }
                                    }
                                }
                                'ServicePrincipalCertificate' {
                                    New-UDGrid -Container -Spacing 2 -Content {
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID' -Value $storedCreds.TenantId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azCertClientId' -Label 'Client ID (Application ID)' -Value $storedCreds.ClientId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                            New-UDTypography -Text 'Provide either a certificate thumbprint (for certificates in the local store) or a certificate file path:' -Variant 'caption' -Style @{ color = '#666'; marginTop = '8px'; marginBottom = '8px' }
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azCertThumbprint' -Label 'Certificate Thumbprint' -Value $storedCreds.CertThumbprint -FullWidth -Placeholder 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azCertPath' -Label 'Certificate File Path (.pfx)' -Value $CurrentConfig.azure.authentication.certificate.path -FullWidth -Placeholder '/path/to/certificate.pfx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            $certPwdPlaceholder = if ($storedCreds.CertPasswordExists) { 'Password is stored. Leave empty to keep existing.' } else { 'Certificate file password' }
                                            $certPwdValue = if ($storedCreds.CertPasswordExists) { '********' } else { '' }
                                            New-UDTextbox -Id 'azCertPassword' -Label 'Certificate Password (if applicable)' -Type 'password' -Value $certPwdValue -FullWidth -Placeholder $certPwdPlaceholder
                                        }
                                    }
                                }
                                'ManagedIdentity' {
                                    # No configuration needed - system-assigned managed identity is used automatically
                                }
                                'DeviceCode' {
                                    New-UDAlert -Severity 'info' -Text 'Device Code authentication will prompt you to visit microsoft.com/devicelogin and enter a code. Useful for environments with strict MFA policies or where browser-based login is restricted.' -Dense -Style @{ marginBottom = '16px' }
                                    New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID (Optional)' -Value $storedCreds.TenantId -FullWidth -Placeholder 'Leave empty for default tenant'
                                }
                                'Interactive' {
                                    New-UDAlert -Severity 'info' -Text 'Interactive authentication opens a browser window for you to sign in. Supports MFA and all authentication policies.' -Dense -Style @{ marginBottom = '16px' }
                                    New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID (Optional)' -Value $storedCreds.TenantId -FullWidth -Placeholder 'Leave empty for default tenant'
                                }
                            }
                        }
                        elseif ($selectedProvider -eq 'AWS') {
                            $awsConfig = Get-CIEMConfig
                            $awsStoredProfile = $awsConfig.aws.authentication.profile
                            $awsStoredRegion = $awsConfig.aws.authentication.region
                            $awsAccessKeyExists = -not [string]::IsNullOrEmpty((Get-CIEMSecret 'CIEM_AWS_AccessKeyId'))
                            $awsSecretKeyExists = -not [string]::IsNullOrEmpty((Get-CIEMSecret 'CIEM_AWS_SecretAccessKey'))

                            switch ($selectedMethod) {
                                'CurrentProfile' {
                                    New-UDAlert -Severity 'info' -Text 'Uses your existing AWS CLI configuration (~/.aws/credentials). Optionally specify a named profile and region.' -Dense -Style @{ marginBottom = '16px' }
                                    New-UDGrid -Container -Spacing 2 -Content {
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'awsProfile' -Label 'AWS Profile (Optional)' -Value $awsStoredProfile -FullWidth -Placeholder 'default'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'awsRegion' -Label 'AWS Region (Optional)' -Value $awsStoredRegion -FullWidth -Placeholder 'us-east-1'
                                        }
                                    }
                                }
                                'AccessKey' {
                                    New-UDGrid -Container -Spacing 2 -Content {
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            $akPlaceholder = if ($awsAccessKeyExists) { 'Access Key is stored. Leave empty to keep existing.' } else { 'AKIAIOSFODNN7EXAMPLE' }
                                            $akValue = if ($awsAccessKeyExists) { '********' } else { '' }
                                            New-UDTextbox -Id 'awsAccessKeyId' -Label 'Access Key ID' -Value $akValue -FullWidth -Placeholder $akPlaceholder
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            $skPlaceholder = if ($awsSecretKeyExists) { 'Secret Key is stored. Leave empty to keep existing.' } else { 'Enter AWS secret access key' }
                                            $skValue = if ($awsSecretKeyExists) { '********' } else { '' }
                                            New-UDTextbox -Id 'awsSecretAccessKey' -Label 'Secret Access Key' -Type 'password' -Value $skValue -FullWidth -Placeholder $skPlaceholder
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'awsRegion' -Label 'AWS Region (Optional)' -Value $awsStoredRegion -FullWidth -Placeholder 'us-east-1'
                                        }
                                    }
                                }
                            }
                        }
                    }

                    # Required Permissions and Test Authentication Buttons
                    New-UDElement -Tag 'div' -Content {
                        New-UDStack -Direction 'row' -Spacing 2 -Content {
                            New-UDButton -Text 'Get Required Permissions' -Variant 'outlined' -Color 'primary' -OnClick {
                                try {
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    $permissions = Get-CIEMRequiredPermission
                                    Show-UDModal -Header {
                                        New-UDTypography -Text 'Required Permissions for CIEM Scans' -Variant 'h6'
                                    } -Content {
                                        New-UDElement -Tag 'div' -Content {
                                            New-UDTypography -Text "The following permissions are required for the service principal to run all $($permissions.CheckCount) security checks:" -Variant 'body2' -Style @{ marginBottom = '16px' }

                                            if ($permissions.Graph.Count -gt 0) {
                                                New-UDTypography -Text 'Microsoft Graph API Permissions (Application)' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                                New-UDTypography -Text 'Grant these in Azure Portal > App Registrations > API Permissions > Add > Microsoft Graph > Application permissions' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                                New-UDList -Content {
                                                    foreach ($perm in $permissions.Graph) {
                                                        New-UDListItem -Label $perm -Icon (New-UDIcon -Icon 'Key' -Size 'sm')
                                                    }
                                                }
                                            }

                                            if ($permissions.ARM.Count -gt 0) {
                                                New-UDTypography -Text 'Azure Resource Manager RBAC Actions' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                                New-UDTypography -Text 'Assign the Reader role at the subscription or management group level to cover these permissions.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                                New-UDList -Content {
                                                    foreach ($perm in $permissions.ARM) {
                                                        New-UDListItem -Label $perm -Icon (New-UDIcon -Icon 'Shield' -Size 'sm')
                                                    }
                                                }
                                            }

                                            if ($permissions.KeyVaultDataPlane.Count -gt 0) {
                                                New-UDTypography -Text 'Key Vault Data Plane Permissions' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                                New-UDTypography -Text 'Configure Key Vault access policy or RBAC for data plane access.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                                New-UDList -Content {
                                                    foreach ($perm in $permissions.KeyVaultDataPlane) {
                                                        New-UDListItem -Label $perm -Icon (New-UDIcon -Icon 'Lock' -Size 'sm')
                                                    }
                                                }
                                            }
                                        } -Attributes @{ style = @{ maxHeight = '60vh'; overflowY = 'auto' } }
                                    } -Footer {
                                        New-UDButton -Text 'Close' -OnClick { Hide-UDModal }
                                    } -Persistent -FullWidth -MaxWidth 'md'
                                }
                                catch {
                                    Show-UDToast -Message "Failed to get permissions: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                                }
                            }

                            New-UDButton -Id 'testAuthBtn' -Text 'Test Authentication' -Variant 'outlined' -Color 'secondary' -ShowLoading -OnClick {
                                try {
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    Write-CIEMLog -Message "Test Authentication button clicked" -Severity INFO -Component 'PSU-ConfigPage'

                                    $testProvider = (Get-UDElement -Id 'cloudProvider').value
                                    if (-not $testProvider) { $testProvider = 'Azure' }

                                    # Show progress
                                    Set-UDElement -Id 'testAuthProgress' -Content {
                                        New-CIEMProgressContent -Text "Connecting to $testProvider..."
                                    }
                                    Set-UDElement -Id 'testAuthBtn' -Properties @{ disabled = $true }

                                    # Connect handles all auth logic internally
                                    $connectResult = Connect-CIEM -Provider $testProvider -Force
                                    $connectProvider = $connectResult.Providers | Where-Object { $_.Provider -eq $testProvider }
                                    Write-CIEMLog -Message "Connect-CIEM result: Status=$($connectProvider.Status), Account=$($connectProvider.Account)" -Severity INFO -Component 'PSU-ConfigPage'

                                    if ($connectProvider.Status -eq 'Connected') {
                                        Set-UDElement -Id 'testAuthProgress' -Content {
                                            New-CIEMSuccessContent -Text 'Authentication Successful' -Details "Connected as $($connectProvider.Account)"
                                        }
                                    } else {
                                        Write-CIEMLog -Message "Authentication FAILED: $($connectProvider.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                        Set-UDElement -Id 'testAuthProgress' -Content {
                                            New-CIEMErrorContent -Text 'Authentication Failed' -Details $connectProvider.Message
                                        }
                                    }
                                } catch {
                                    Write-CIEMLog -Message "Test Authentication exception: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                    Set-UDElement -Id 'testAuthProgress' -Content {
                                        New-CIEMErrorContent -Text 'Authentication Failed' -Details $_.Exception.Message
                                    }
                                } finally {
                                    Set-UDElement -Id 'testAuthBtn' -Properties @{ disabled = $false }
                                }
                            }
                        }
                        New-UDElement -Id 'testAuthProgress' -Tag 'div'
                    } -Attributes @{ style = @{ marginTop = '16px' } }
                }

                New-UDElement -Tag 'div' -Content {
                    New-UDStack -Direction 'row' -Spacing 2 -Content {
                        New-UDButton -Id 'saveConfigBtn' -Text 'Save Configuration' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                            try {
                                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                Write-CIEMLog -Message "Save Configuration button clicked" -Severity INFO -Component 'PSU-ConfigPage'

                                # Show progress
                                Set-UDElement -Id 'saveConfigProgress' -Content {
                                    New-CIEMProgressContent -Text 'Saving configuration...'
                                }
                                Set-UDElement -Id 'saveConfigBtn' -Properties @{ disabled = $true }

                                $provider = (Get-UDElement -Id 'cloudProvider').value
                                $authMethod = (Get-UDElement -Id 'authMethod').value
                                Write-CIEMLog -Message "Form values - Provider: $provider, AuthMethod: $authMethod" -Severity DEBUG -Component 'PSU-ConfigPage'

                                # Validate ManagedIdentity is only saved when supported
                                $envInfo = Get-PSUInstalledEnvironment
                                Write-CIEMLog -Message "Environment: $($envInfo.Environment), SupportsManagedIdentity: $($envInfo.SupportsManagedIdentity)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                if ($authMethod -eq 'ManagedIdentity' -and -not $envInfo.SupportsManagedIdentity) {
                                    Write-CIEMLog -Message "ManagedIdentity selected but not supported in this environment" -Severity WARNING -Component 'PSU-ConfigPage'
                                    Set-UDElement -Id 'saveConfigProgress' -Content {
                                        New-CIEMErrorContent -Text 'Not Available' -Details 'Managed Identity is not available in on-premises deployments.'
                                    }
                                    return
                                }

                                # Collect form values into typed auth context + secret params
                                Write-CIEMLog -Message "Provider: $provider, AuthMethod: $authMethod" -Severity DEBUG -Component 'PSU-ConfigPage'

                                # Active provider is a config concern, not an auth context concern
                                Set-CIEMConfig -Settings @{ 'cloudProvider' = $provider }

                                # Build simple save params — no typed objects needed (avoids PS class scoping in PSU runspaces)
                                $saveParams = @{
                                    Provider = $provider
                                    Method   = $authMethod
                                }

                                if ($provider -eq 'Azure') {
                                    $tenantId = (Get-UDElement -Id 'azTenantId' -ErrorAction SilentlyContinue).value
                                    $saveParams['TenantId'] = $tenantId

                                    switch ($authMethod) {
                                        'ServicePrincipalSecret' {
                                            $saveParams['ClientId'] = (Get-UDElement -Id 'azSpClientId').value
                                            $clientSecret = (Get-UDElement -Id 'azSpClientSecret').value
                                            if ($clientSecret -and $clientSecret -ne '********') {
                                                $saveParams['ClientSecret'] = $clientSecret
                                            }
                                        }
                                        'ServicePrincipalCertificate' {
                                            $saveParams['ClientId'] = (Get-UDElement -Id 'azCertClientId').value
                                            $thumbprint = (Get-UDElement -Id 'azCertThumbprint').value
                                            if ($thumbprint) {
                                                $saveParams['CertThumbprint'] = $thumbprint
                                            }
                                        }
                                        # ManagedIdentity, DeviceCode, Interactive — no extra params needed
                                    }
                                }
                                elseif ($provider -eq 'AWS') {
                                    $region = (Get-UDElement -Id 'awsRegion' -ErrorAction SilentlyContinue).value
                                    $saveParams['Region'] = $region

                                    switch ($authMethod) {
                                        'CurrentProfile' {
                                            $saveParams['Profile'] = (Get-UDElement -Id 'awsProfile' -ErrorAction SilentlyContinue).value
                                        }
                                        'AccessKey' {
                                            $accessKeyId = (Get-UDElement -Id 'awsAccessKeyId').value
                                            $secretAccessKey = (Get-UDElement -Id 'awsSecretAccessKey').value
                                            if ($accessKeyId -and $accessKeyId -ne '********') {
                                                $saveParams['AccessKeyId'] = $accessKeyId
                                            }
                                            if ($secretAccessKey -and $secretAccessKey -ne '********') {
                                                $saveParams['SecretAccessKey'] = $secretAccessKey
                                            }
                                        }
                                    }
                                }

                                # Single save path for config + secrets
                                Write-CIEMLog -Message "Calling Save-CIEMAuthenticationContext ($provider/$authMethod)..." -Severity INFO -Component 'PSU-ConfigPage'
                                Save-CIEMAuthenticationContext @saveParams
                                Write-CIEMLog -Message "Save-CIEMAuthenticationContext completed" -Severity INFO -Component 'PSU-ConfigPage'

                                # Detect if authentication settings changed
                                $authChanged = $false
                                $originalAuth = $Session:OriginalAuthValues
                                Write-CIEMLog -Message "Checking if auth changed. Original: Provider=$($originalAuth.Provider), Method=$($originalAuth.Method)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                if ($originalAuth) {
                                    # Check for changes in provider or method
                                    if ($provider -ne $originalAuth.Provider -or $authMethod -ne $originalAuth.Method) {
                                        $authChanged = $true
                                        Write-CIEMLog -Message "Auth changed: provider or method differs" -Severity DEBUG -Component 'PSU-ConfigPage'
                                    }
                                    # Check for changes in credential-related properties (use saveParams, not typed objects)
                                    else {
                                        if ($saveParams.TenantId -and $saveParams.TenantId -ne $originalAuth.TenantId) { $authChanged = $true }
                                        if ($saveParams.ClientId -and $saveParams.ClientId -ne $originalAuth.ClientId) { $authChanged = $true }
                                        if ($saveParams.ContainsKey('ClientSecret')) { $authChanged = $true }  # any new secret = changed
                                        if ($saveParams.ContainsKey('CertThumbprint') -and $saveParams['CertThumbprint'] -ne $originalAuth.CertThumbprint) { $authChanged = $true }
                                        if ($authChanged) { Write-CIEMLog -Message "Auth changed: credentials differ" -Severity DEBUG -Component 'PSU-ConfigPage' }
                                    }
                                } else {
                                    # No original values stored (first save), always try to connect
                                    $authChanged = $true
                                    Write-CIEMLog -Message "No original auth values stored, authChanged=$authChanged" -Severity DEBUG -Component 'PSU-ConfigPage'
                                }

                                # Test authentication if settings changed
                                Write-CIEMLog -Message "Auth changed: $authChanged, Provider: $provider" -Severity INFO -Component 'PSU-ConfigPage'
                                if ($authChanged) {
                                    Write-CIEMLog -Message "Auth settings changed - initiating Connect-CIEM for $provider..." -Severity INFO -Component 'PSU-ConfigPage'
                                    Set-UDElement -Id 'saveConfigProgress' -Content {
                                        New-CIEMProgressContent -Text "Testing $provider authentication..."
                                    }
                                    try {
                                        $result = Connect-CIEM -Provider $provider -Force
                                        $providerResult = $result.Providers | Where-Object { $_.Provider -eq $provider }
                                        Write-CIEMLog -Message "Connect-CIEM result: Status=$($providerResult.Status), Account=$($providerResult.Account), Message=$($providerResult.Message)" -Severity INFO -Component 'PSU-ConfigPage'
                                        if ($providerResult.Status -eq 'Connected') {
                                            Set-UDElement -Id 'saveConfigProgress' -Content {
                                                New-CIEMSuccessContent -Text 'Configuration Saved' -Details "Connected as $($providerResult.Account)"
                                            }
                                            # Track saved values to detect future changes (use $saveParams, not removed $authCtx/$secretParams)
                                            $Session:OriginalAuthValues = @{
                                                Provider       = $provider
                                                Method         = $authMethod
                                                TenantId       = $saveParams['TenantId']
                                                ClientId       = $saveParams['ClientId']
                                                CertThumbprint = $saveParams['CertThumbprint']
                                            }
                                            Write-CIEMLog -Message "Session:OriginalAuthValues updated" -Severity DEBUG -Component 'PSU-ConfigPage'
                                        } else {
                                            Write-CIEMLog -Message "Authentication failed: $($providerResult.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                            Set-UDElement -Id 'saveConfigProgress' -Content {
                                                New-UDCard -Style @{ backgroundColor = '#fff3e0'; marginTop = '12px'; marginBottom = '12px' } -Content {
                                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                        New-UDIcon -Icon 'ExclamationTriangle' -Size 'lg' -Style @{ color = '#ff9800' }
                                                        New-UDElement -Tag 'div' -Content {
                                                            New-UDTypography -Text 'Configuration Saved (Auth Failed)' -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#e65100' }
                                                            New-UDTypography -Text $providerResult.Message -Variant 'body2' -Style @{ color = '#666' }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    } catch {
                                        Write-CIEMLog -Message "Connect-CIEM exception: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                        Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                        Set-UDElement -Id 'saveConfigProgress' -Content {
                                            New-UDCard -Style @{ backgroundColor = '#fff3e0'; marginTop = '12px'; marginBottom = '12px' } -Content {
                                                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                    New-UDIcon -Icon 'ExclamationTriangle' -Size 'lg' -Style @{ color = '#ff9800' }
                                                    New-UDElement -Tag 'div' -Content {
                                                        New-UDTypography -Text 'Configuration Saved (Auth Failed)' -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#e65100' }
                                                        New-UDTypography -Text $_.Exception.Message -Variant 'body2' -Style @{ color = '#666' }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    Write-CIEMLog -Message "No auth change detected or not Azure - skipping Connect-CIEM" -Severity DEBUG -Component 'PSU-ConfigPage'
                                    Set-UDElement -Id 'saveConfigProgress' -Content {
                                        New-CIEMSuccessContent -Text 'Configuration Saved'
                                    }
                                }
                                Write-CIEMLog -Message "Save Configuration completed successfully" -Severity INFO -Component 'PSU-ConfigPage'
                            } catch {
                                Write-CIEMLog -Message "Save Configuration failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                Set-UDElement -Id 'saveConfigProgress' -Content {
                                    New-CIEMErrorContent -Text 'Save Failed' -Details $_.Exception.Message
                                }
                            } finally {
                                Set-UDElement -Id 'saveConfigBtn' -Properties @{ disabled = $false }
                            }
                        }

                        New-UDButton -Id 'resetConfigBtn' -Text 'Reset to Defaults' -Variant 'outlined' -Color 'secondary' -OnClick {
                            try {
                                Set-UDElement -Id 'cloudProvider' -Properties @{ value = 'Azure' }
                                Set-UDElement -Id 'authMethod' -Properties @{ value = 'ServicePrincipalSecret' }
                                Sync-UDElement -Id 'authMethodContainer'
                                Sync-UDElement -Id 'authFieldsContainer'
                                # Clear any previous progress messages
                                Set-UDElement -Id 'saveConfigProgress' -Content { }
                                Set-UDElement -Id 'testAuthProgress' -Content { }
                                Show-UDToast -Message 'Form reset to default values. Click Save to apply.' -Duration 5000 -BackgroundColor '#ff9800'
                            } catch {
                                Show-UDToast -Message "Failed to reset: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                            }
                        }
                    }
                    New-UDElement -Id 'saveConfigProgress' -Tag 'div'
                } -Attributes @{ style = @{ marginTop = '24px' } }
            } -Navigation $Navigation -NavigationLayout permanent
        }

        # Helper function to create the Cloud Checks page
        function New-CIEMCloudChecksPage {
            param($Navigation)

            New-UDPage -Name 'Cloud Checks' -Url '/ciem/checks' -Content {
                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue

                New-UDTypography -Text 'Cloud Checks' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
                New-UDTypography -Text 'Browse all available CIEM security checks' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

                # Checks Data Table Card
                New-UDCard -Content {
                    New-UDDynamic -Content {
                        try {
                            Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                            Write-CIEMLog -Message "Auto-loading installed checks" -Severity INFO -Component 'PSU-CloudChecksPage'

                            $warnings = @()
                            $allChecks = @(Get-CIEMCheck -WarningVariable warnings)
                            if ($warnings.Count -gt 0) {
                                Write-CIEMLog -Message "Get-CIEMCheck warnings ($($warnings.Count)): $($warnings[0])" -Severity WARNING -Component 'PSU-CloudChecksPage'
                            }
                            Write-CIEMLog -Message "Get-CIEMCheck returned $($allChecks.Count) checks" -Severity INFO -Component 'PSU-CloudChecksPage'

                            if ($allChecks.Count -gt 0) {
                                New-UDDataGrid -LoadRows {
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    $checks = @(Get-CIEMCheck)
                                    $checksData = $checks | ForEach-Object {
                                        @{
                                            id            = $_.Id
                                            checkId       = $_.Id
                                            title         = $_.Title
                                            provider      = [string]$_.Provider
                                            service       = [string]$_.Service
                                            severity      = ([string]$_.Severity -replace '^(.)', { $_.Groups[1].Value.ToUpper() })
                                        }
                                    }
                                    @($checksData) | Out-UDDataGridData -Context $EventData -TotalRows @($checksData).Count
                                } -Columns @(
                                    New-UDDataGridColumn -Field 'checkId' -HeaderName 'Check ID' -Width 280
                                    New-UDDataGridColumn -Field 'title' -HeaderName 'Title' -Flex 1
                                    New-UDDataGridColumn -Field 'provider' -HeaderName 'Provider' -Width 100
                                    New-UDDataGridColumn -Field 'service' -HeaderName 'Service' -Width 100
                                    New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 110 -Render {
                                        $sev = $EventData.severity.ToUpper()
                                        $color = switch ($sev) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } 'MEDIUM' { '#ff9800' } 'LOW' { '#2196f3' } default { '#666' } }
                                        New-UDChip -Label $sev -Style @{ backgroundColor = $color; color = 'white' }
                                    }
                                ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter
                            }
                            else {
                                New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '40px'; textAlign = 'center' } } -Content {
                                    New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 3 -Content {
                                        New-UDIcon -Icon 'Database' -Size '4x' -Style @{ color = '#1976d2'; marginBottom = '16px' }
                                        New-UDTypography -Text 'No Checks Available' -Variant 'h5' -Style @{ marginBottom = '8px' }
                                        New-UDTypography -Text 'No security checks are currently installed. Use Sync-ProwlerCheck to download checks from the Prowler repository.' -Variant 'body1' -Style @{ color = '#666' }
                                    }
                                }
                            }
                        }
                        catch {
                            Write-CIEMLog -Message "Load checks failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-CloudChecksPage'
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '20px'; textAlign = 'center' } } -Content {
                                New-UDTypography -Text "Failed to load checks: $($_.Exception.Message)" -Variant 'body1' -Style @{ color = '#f44336' }
                            }
                        }
                    } -LoadingComponent {
                        New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '40px'; textAlign = 'center' } } -Content {
                            New-UDStack -Direction 'column' -AlignItems 'center' -Spacing 3 -Content {
                                New-UDProgress -Circular
                                New-UDTypography -Text 'Loading security checks...' -Variant 'body1' -Style @{ color = '#666'; marginTop = '16px' }
                            }
                        }
                    }
                }
            } -Navigation $Navigation -NavigationLayout permanent
        }

        # Helper function to create the About page
        function New-CIEMAboutPage {
            param($Navigation)

            New-UDPage -Name 'About' -Url '/ciem/about' -Content {
                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue

                New-UDTypography -Text 'About Devolutions CIEM' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }

                New-UDCard -Title 'Cloud Infrastructure Entitlement Management' -Content {
                    New-UDTypography -Text 'Devolutions CIEM is a security scanning solution that helps identify identity and access management issues across your cloud infrastructure.' -Variant 'body1' -Style @{ marginBottom = '20px' }

                    # Dynamic provider/check info
                    $providers = @(Get-CIEMProvider)
                    $featureItems = @()
                    foreach ($p in $providers) {
                        $featureItems += "$($p.CheckCount) $($p.Name) security checks"
                    }

                    New-UDTypography -Text 'Key Features:' -Variant 'h6' -Style @{ marginTop = '20px' }
                    New-UDList -Content {
                        foreach ($item in $featureItems) {
                            New-UDListItem -Label $item
                        }
                        New-UDListItem -Label 'Multi-provider support (Azure + AWS)'
                        New-UDListItem -Label 'Identity and entitlement focused checks'
                        New-UDListItem -Label 'Integration with Devolutions PAM for remediation'
                    }

                    New-UDTypography -Text 'Version Information:' -Variant 'h6' -Style @{ marginTop = '20px' }
                    New-UDTable -Data @(
                        @{ Property = 'Module Version'; Value = '0.2.0' }
                        @{ Property = 'PSU App Version'; Value = '0.2.0' }
                        @{ Property = 'PowerShell Universal'; Value = '5.4+' }
                        @{ Property = 'Author'; Value = 'Adam Bertram' }
                        @{ Property = 'Company'; Value = 'Devolutions Inc.' }
                    ) -Columns @(
                        New-UDTableColumn -Property 'Property' -Title 'Property'
                        New-UDTableColumn -Property 'Value' -Title 'Value'
                    ) -Dense

                    New-UDTypography -Text 'Learn More:' -Variant 'h6' -Style @{ marginTop = '20px' }
                    New-UDButton -Text 'Devolutions PAM' -Href 'https://devolutions.net/pam' -Variant 'outlined' -Style @{ marginRight = '10px' }
                    New-UDButton -Text 'Documentation' -Href 'https://docs.devolutions.net' -Variant 'outlined'
                }
            } -Navigation $Navigation -NavigationLayout permanent
        }
    }

    process {
        # Note: Configuration is stored in PSU persistent cache (key: CIEM:Config)
        # Get-CIEMConfig retrieves it or initializes with defaults on first run.

        $Navigation = New-CIEMNavigation

        # Create pages
        $DashboardPage = New-CIEMDashboardPage -Navigation $Navigation
        $CloudChecksPage = New-CIEMCloudChecksPage -Navigation $Navigation
        $ScanPage = New-CIEMScanPage -Navigation $Navigation
        $ConfigPage = New-CIEMConfigPage -Navigation $Navigation
        $AboutPage = New-CIEMAboutPage -Navigation $Navigation

        # Return the App
        New-UDApp -Title 'Devolutions CIEM' -Pages @(
            $DashboardPage
            $CloudChecksPage
            $ScanPage
            $ConfigPage
            $AboutPage
        ) -DefaultTheme 'Light'
    }
}
