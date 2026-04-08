function New-CIEMScanHistoryPage {
    <#
    .SYNOPSIS
        Creates the Scan History page with a data grid of past scan runs.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    New-UDPage -Name 'Scan History' -Url '/ciem/history' -Content {
        New-UDTypography -Text 'Scan History' -Variant 'h4' -Style @{ marginBottom = '10px'; marginTop = '10px' }
        New-UDTypography -Text 'Click on a scan to expand and view detailed results' -Variant 'subtitle1' -Style @{ marginBottom = '20px'; color = '#666' }

        New-UDCard -Content {
            New-UDDynamic -Id 'scanHistoryPanel' -Content {

                try {
                    $scanRuns = @(Devolutions.CIEM\Get-CIEMScanRun)

                    if ($scanRuns -and $scanRuns.Count -gt 0) {
                        New-UDDataGrid -LoadRows {
            
                            $runs = @(Devolutions.CIEM\Get-CIEMScanRun)
                            $historyData = $runs | ForEach-Object {
                                @{
                                    id       = $_.Id
                                    date     = ([datetime]$_.StartTime).ToString('yyyy-MM-dd HH:mm')
                                    providers = ($_.Providers -join ', ')
                                    services = ($_.Services -join ', ')
                                    status   = [string]$_.Status
                                    failed   = $_.FailedResults
                                    passed   = $_.PassedResults
                                    manual   = $_.ManualResults
                                    skipped  = $_.SkippedResults
                                    duration = $_.Duration
                                }
                            }
                            @($historyData) | Out-UDDataGridData -Context $EventData -TotalRows @($historyData).Count
                        } -Columns @(
                            New-UDDataGridColumn -Field 'date' -HeaderName 'Scan Date' -Width 150
                            New-UDDataGridColumn -Field 'providers' -HeaderName 'Providers' -Width 150
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
            
                            $runs = @(Devolutions.CIEM\Get-CIEMScanRun -IncludeResults)

                            if ($EventData.Type -eq 'CSV') {
                                $csvData = $runs | ForEach-Object {
                                    [PSCustomObject]@{
                                        Id        = $_.Id
                                        Providers = ($_.Providers -join ', ')
                                        Services  = ($_.Services -join ', ')
                                        Status    = [string]$_.Status
                                        StartTime = ([datetime]$_.StartTime).ToString('yyyy-MM-dd HH:mm:ss')
                                        EndTime   = if ($_.EndTime) { ([datetime]$_.EndTime).ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                                        Duration  = $_.Duration
                                        Failed    = $_.FailedResults
                                        Passed    = $_.PassedResults
                                        Manual    = $_.ManualResults
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
                                        providers    = @($_.Providers)
                                        services     = $_.Services
                                        status       = [string]$_.Status
                                        startTime    = ([datetime]$_.StartTime).ToString('o')
                                        endTime      = if ($_.EndTime) { ([datetime]$_.EndTime).ToString('o') } else { $null }
                                        duration     = $_.Duration
                                        failedCount  = $_.FailedResults
                                        passedCount  = $_.PassedResults
                                        manualCount  = $_.ManualResults
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
            
                            $scanRunId = $EventData.row.id

                            try {
                                $scanRun = Devolutions.CIEM\Get-CIEMScanRun -Id $scanRunId -IncludeResults
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
                                            provider = if ($result.Check.Provider) { [string]$result.Check.Provider } else { 'Azure' }
                                            remediation = if ($result.Check.Remediation -and $result.Check.Remediation.Text) { $result.Check.Remediation.Text } else { 'See Devolutions PAM for remediation guidance.' }
                                            relatedUrl = $result.Check.RelatedUrl
                                        }
                                    }

                                    New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '16px'; backgroundColor = '#fafafa' } } -Content {
                                        # Summary chips
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

                                        # Results DataGrid
                                        $resultsData = $enrichedResults
                                        New-UDDataGrid -LoadRows {
                                            $resultsData | Out-UDDataGridData -Context $EventData -TotalRows @($resultsData).Count
                                        } -Columns @(
                                            New-UDDataGridColumn -Field 'checkId' -HeaderName 'Check ID' -Width 200
                                            New-UDDataGridColumn -Field 'title' -HeaderName 'Finding' -Flex 1
                                            New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 110 -Render {
                                                $sev = $EventData.severity.ToUpper()
                                                $color = Devolutions.CIEM\Get-SeverityColor -Severity $sev
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
                                            New-UDDataGridColumn -Field 'provider' -HeaderName 'Provider' -Width 100
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
                        New-UDTypography -Text 'No scan history available yet. Run a scan from the Scan page to see results here.' -Variant 'body2' -Style @{ color = '#666'; fontStyle = 'italic'; padding = '16px' }
                    }
                }
                catch {
                    New-UDTypography -Text 'Unable to load scan history.' -Variant 'body2' -Style @{ color = '#666'; fontStyle = 'italic'; padding = '16px' }
                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
