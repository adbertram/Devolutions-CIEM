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

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Scan' -Url '/ciem/scan' -Content {
        New-UDTypography -Text 'Run CIEM Scan' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
        New-UDTypography -Text 'Configure and execute a CIEM security scan against your cloud environment' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

        $Page:SelectedCheckIds = @()

        # Check Selection Card
        New-UDCard -Title 'Check Selection' -Content {
            # Check selection data grid with checkboxes
            New-UDDynamic -Id 'checkSelectionGrid' -Content {

                $allChecks = @(Devolutions.CIEM\Get-CIEMCheck)

                # Initialize session state on first load
                if ($null -eq $Page:CheckStatusFilter) {
                    $Page:CheckStatusFilter = 'enabled'
                }

                # Selection summary
                New-UDDynamic -Id 'selectionSummary' -Content {
    
                    $checks = @(Devolutions.CIEM\Get-CIEMCheck)
                    $enabledCount = @($checks | Where-Object { -not $_.Disabled }).Count
                    $disabledCount = @($checks | Where-Object { $_.Disabled }).Count
                    $selectedCount = @($Page:SelectedCheckIds).Count
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
                            New-UDSelect -Id 'checkStatusFilter' -DefaultValue $Page:CheckStatusFilter -OnChange {
                                $Page:CheckStatusFilter = $EventData
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
    
                    $checks = @(Devolutions.CIEM\Get-CIEMCheck)

                    # Apply status filter
                    $statusFilter = $Page:CheckStatusFilter
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
                    $Page:SelectedCheckIds = @($EventData)
                    Sync-UDElement -Id 'selectionSummary'
                } -Columns @(
                    New-UDDataGridColumn -Field 'info' -HeaderName 'Info' -Width 60 -Render {
                        $checkTitle = [string]$EventData.title
                        $checkSeverity = [string]$EventData.severity
                        $checkProvider = [string]$EventData.provider
                        $checkService = [string]$EventData.service
                        $checkDescription = [string]$EventData.description
                        $checkRisk = [string]$EventData.risk
                        $checkId = [string]$EventData.checkId
                        $checkRelatedUrl = [string]$EventData.relatedUrl
                        $checkRemediationText = [string]$EventData.remediationText
                        $checkRemediationUrl = [string]$EventData.remediationUrl

                        foreach ($requiredInfoField in @(
                            @{ Name = 'title'; Value = $checkTitle },
                            @{ Name = 'severity'; Value = $checkSeverity },
                            @{ Name = 'provider'; Value = $checkProvider },
                            @{ Name = 'service'; Value = $checkService },
                            @{ Name = 'description'; Value = $checkDescription },
                            @{ Name = 'risk'; Value = $checkRisk },
                            @{ Name = 'checkId'; Value = $checkId }
                        )) {
                        if ([string]::IsNullOrWhiteSpace($requiredInfoField.Value)) {
                            throw "Cannot render Scan check info button because row field '$($requiredInfoField.Name)' is empty."
                        }
                    }

                        $infoButtonId = 'scanCheckInfo_' + ($checkId -replace '[^A-Za-z0-9_-]', '_')
                        New-UDIconButton -Id $infoButtonId -Icon (New-UDIcon -Icon 'InfoCircle') -Size 'small' -OnClick {
                            Show-UDModal -Header {
                                New-UDTypography -Text $checkTitle -Variant 'h6'
                            } -Content {
                                $sev = $checkSeverity.ToUpper()
                                $sevColor = Devolutions.CIEM\Get-SeverityColor -Severity $sev
                                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '16px' } } -Content {
                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                        New-UDChip -Label $sev -Style @{ backgroundColor = $sevColor; color = 'white' }
                                        New-UDChip -Label $checkProvider -Variant 'outlined'
                                        New-UDChip -Label $checkService -Variant 'outlined'
                                    }
                                }
                                New-UDTypography -Text 'Description' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                New-UDTypography -Text $checkDescription -Variant 'body2' -Style @{ marginBottom = '16px' }
                                New-UDTypography -Text 'Risk' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                New-UDTypography -Text $checkRisk -Variant 'body2' -Style @{ marginBottom = '16px' }
                                if ($checkRemediationText) {
                                    New-UDTypography -Text 'Remediation' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                    New-UDTypography -Text $checkRemediationText -Variant 'body2' -Style @{ marginBottom = '16px' }
                                }
                                New-UDTypography -Text 'Check ID' -Variant 'subtitle2' -Style @{ fontWeight = 'bold'; marginBottom = '4px' }
                                New-UDTypography -Text $checkId -Variant 'body2' -Style @{ marginBottom = '16px'; fontFamily = 'monospace' }
                            } -Footer {
                                New-UDStack -Direction 'row' -Spacing 2 -Content {
                                    if ($checkRelatedUrl) {
                                        New-UDButton -Text 'Documentation' -Variant 'outlined' -OnClick { Invoke-UDRedirect -Url $checkRelatedUrl -OpenInNewWindow }
                                    }
                                    if ($checkRemediationUrl) {
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
                            $color = Devolutions.CIEM\Get-SeverityColor -Severity $sev
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

            # Check if discovery has been run — disable scan if not
            $hasDiscoveryData = @(Devolutions.CIEM\Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 1).Count -gt 0

            if (-not $hasDiscoveryData) {
                New-UDAlert -Severity 'warning' -Text 'Run Azure Discovery from the Environment page before scanning. Checks require collected resource data to evaluate.' -Style @{ marginTop = '16px' }
            }

            # Action Buttons
            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '16px' } } -Content {
                $scanBtnParams = @{
                    Id = 'startScanBtn'
                    Text = 'Start Scan'
                    Variant = 'contained'
                    Color = 'primary'
                    ShowLoading = $true
                }
                if (-not $hasDiscoveryData) {
                    $scanBtnParams['Disabled'] = $true
                }
                New-UDButton @scanBtnParams -OnClick {
                    try {
                        Devolutions.CIEM\Write-CIEMLog -Message "Start Scan button clicked" -Severity INFO -Component 'PSU-ScanPage'

                        # Read selected check IDs from session state (synced by OnSelectionChange)
                        $selectedCheckIds = @($Page:SelectedCheckIds | Where-Object { $_ })

                        if ($selectedCheckIds.Count -eq 0) {
                            Show-UDToast -Message 'Please select at least one check.' -Duration 5000 -BackgroundColor '#ff9800'
                            return
                        }

                        # Query only the selected checks to get provider/service metadata
                        $selectedChecks = @(Devolutions.CIEM\Get-CIEMCheck -CheckId $selectedCheckIds | Where-Object { -not $_.Disabled })

                        if ($selectedChecks.Count -eq 0) {
                            Show-UDToast -Message 'All selected checks are disabled.' -Duration 5000 -BackgroundColor '#ff9800'
                            return
                        }

                        $selectedCheckIds = @($selectedChecks | Select-Object -ExpandProperty Id)
                        $selectedProviders = @($selectedChecks | Select-Object -ExpandProperty Provider -Unique)
                        $selectedServices = @($selectedChecks | Select-Object -ExpandProperty Service -Unique)
                        Devolutions.CIEM\Write-CIEMLog -Message "Scan config: Checks=$($selectedCheckIds.Count), Providers=$($selectedProviders -join ','), Services=$($selectedServices -join ',')" -Severity INFO -Component 'PSU-ScanPage'

                        Show-UDToast -Message "Starting CIEM scan: $($selectedCheckIds.Count) checks across $($selectedServices -join ', ')" -Duration 3000

                        # PSU doesn't pass -Parameters to module command scripts, so use cache
                        $scanConfig = @{
                            Provider      = $selectedProviders
                            Service       = $selectedServices
                            CheckId       = $selectedCheckIds
                            IncludePassed = $true
                        }
                        Set-PSUCache -Key 'CIEM:ScanConfig' -Value $scanConfig -Integrated

                        Devolutions.CIEM\Write-CIEMLog -Message "Launching CIEM Scan job for providers: $($selectedProviders -join ', ')..." -Severity INFO -Component 'PSU-ScanPage'

                        $scanRun = Devolutions.CIEM\Invoke-CIEMJobWithProgress `
                            -ScriptName 'Checks/New-CIEMScanRun' `
                            -ProgressElementId 'scanProgressArea' `
                            -DisableElementIds @('startScanBtn') `
                            -MaxPollSeconds 1800

                        if (-not $scanRun) {
                            throw "Scan job completed but returned no pipeline output."
                        }

                        $allResults = @($scanRun.ScanResults)
                        $failedCount = $scanRun.FailedResults
                        $passedCount = $scanRun.PassedResults
                        $manualCount = $scanRun.ManualResults
                        $skippedCount = $scanRun.SkippedResults
                        $totalCount = $scanRun.TotalResults
                        $durationStr = $scanRun.Duration

                        Devolutions.CIEM\Write-CIEMLog -Message "Scan complete. Results: $($allResults.Count), Duration: $durationStr" -Severity INFO -Component 'PSU-ScanPage'

                        # Store in session for quick page access
                        $Page:CIEMScanResults = $allResults
                        $Page:CIEMScanTimestamp = $scanRun.EndTime
                        $Page:CIEMIncludePassed = $true

                        Devolutions.CIEM\Write-CIEMLog -Message "Persisted $($allResults.Count) scan results (ScanRunId: $($scanRun.Id))" -Severity INFO -Component 'PSU-ScanPage'

                        # Update progress area with results summary
                        $summaryParts = @("Duration: $durationStr", "Total: $totalCount", "Failed: $failedCount", "Passed: $passedCount")
                        if ($manualCount -gt 0) { $summaryParts += "Manual: $manualCount" }
                        if ($skippedCount -gt 0) { $summaryParts += "Skipped: $skippedCount" }
                        $summaryText = $summaryParts -join ' | '

                        Set-UDElement -Id 'scanProgressArea' -Content {
                            Devolutions.CIEM\New-CIEMSuccessContent -Text 'Scan Complete!' -Details "$summaryText`nView detailed results on the Scan History page."
                        }

                        # Toast notifications
                        $toastParts = @("Scan complete!")
                        if ($failedCount -gt 0) { $toastParts += "$failedCount failed" }
                        if ($passedCount -gt 0) { $toastParts += "$passedCount passed" }
                        if ($manualCount -gt 0) { $toastParts += "$manualCount manual review" }
                        Show-UDToast -Message ($toastParts -join ' | ') -Duration 5000 -BackgroundColor '#4caf50'
                        Show-UDToast -Message 'View detailed results on the Scan History page.' -Duration 5000
                    }
                    catch {
                        Devolutions.CIEM\Write-CIEMLog -Message "Scan failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ScanPage'
                        Devolutions.CIEM\Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ScanPage'

                        Set-UDElement -Id 'scanProgressArea' -Content {
                            Devolutions.CIEM\New-CIEMErrorContent -Text 'Scan Failed' -Details $_.Exception.Message
                        }

                        Show-UDToast -Message "Scan failed: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                    }
                }
            }
        }

    } -Navigation $Navigation -NavigationLayout permanent
}
