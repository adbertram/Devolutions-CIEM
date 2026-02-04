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
        # Helper function to get severity color
        function Get-SeverityColor {
            param([string]$Severity)
            switch ($Severity) {
                'CRITICAL' { '#9c27b0' }
                'HIGH' { '#f44336' }
                'MEDIUM' { '#ff9800' }
                'LOW' { '#2196f3' }
                'INFO' { '#4caf50' }
                default { '#666' }
            }
        }

        # Helper function to get status color
        function Get-StatusColor {
            param([string]$Status)
            if ($Status -eq 'FAIL') { '#f44336' } else { '#4caf50' }
        }

        # Helper functions for async button progress states
        function New-CIEMProgressContent {
            param(
                [string]$Text = 'Processing...'
            )
            New-UDCard -Style @{ backgroundColor = '#f5f5f5'; marginTop = '12px'; marginBottom = '12px' } -Content {
                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                    New-UDProgress -Circular -Size 'small'
                    New-UDTypography -Text $Text -Variant 'body2'
                }
            }
        }

        function New-CIEMSuccessContent {
            param(
                [string]$Text = 'Complete!',
                [string]$Details,
                [scriptblock]$ActionButton
            )
            New-UDCard -Style @{ backgroundColor = '#e8f5e9'; marginTop = '12px'; marginBottom = '12px' } -Content {
                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                    New-UDIcon -Icon 'CheckCircle' -Size 'lg' -Style @{ color = '#4caf50' }
                    New-UDElement -Tag 'div' -Content {
                        New-UDTypography -Text $Text -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#2e7d32' }
                        if ($Details) {
                            New-UDTypography -Text $Details -Variant 'body2' -Style @{ color = '#666' }
                        }
                    }
                }
                if ($ActionButton) {
                    & $ActionButton
                }
            }
        }

        function New-CIEMErrorContent {
            param(
                [string]$Text = 'Failed',
                [string]$Details
            )
            New-UDCard -Style @{ backgroundColor = '#ffebee'; marginTop = '12px'; marginBottom = '12px' } -Content {
                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                    New-UDIcon -Icon 'TimesCircle' -Size 'lg' -Style @{ color = '#f44336' }
                    New-UDElement -Tag 'div' -Content {
                        New-UDTypography -Text $Text -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#c62828' }
                        if ($Details) {
                            New-UDTypography -Text $Details -Variant 'body2' -Style @{ color = '#666' }
                        }
                    }
                }
            }
        }

        # Helper function to create navigation items
        function New-CIEMNavigation {
            @(
                New-UDListItem -Label 'Dashboard' -Icon (New-UDIcon -Icon 'Home') -Href '/ciem'
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
                    # Enrich scan results with check metadata for display
                    $checkMetadata = Get-CIEMCheck
                    $checkLookup = @{}
                    foreach ($check in $checkMetadata) {
                        $checkLookup[$check.id] = $check
                    }

                    $ScanResults = $rawResults | ForEach-Object {
                        $result = $_
                        $meta = $checkLookup[$result.CheckId]
                        [PSCustomObject]@{
                            Id = $result.CheckId
                            CheckId = $result.CheckId
                            Title = if ($meta) { $meta.title } else { $result.CheckId }
                            Severity = ($result.Severity -replace '^(.)', { $_.Groups[1].Value.ToUpper() })
                            Status = $result.Status
                            Provider = 'Azure'
                            Service = if ($meta) { $meta.service } else { 'Unknown' }
                            ResourceName = $result.ResourceName
                        }
                    }

                    $FailedResults = @($ScanResults | Where-Object { $_.Status -eq 'FAIL' })
                    $PassedResults = @($ScanResults | Where-Object { $_.Status -eq 'PASS' })
                    $CriticalCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'CRITICAL' }).Count
                    $HighCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'HIGH' }).Count
                    $MediumCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'MEDIUM' }).Count
                    $LowCount = @($FailedResults | Where-Object { $_.Severity.ToUpper() -eq 'LOW' }).Count

                    # Show scan timestamp
                    $timestampStr = if ($scanTimestamp) { $scanTimestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Unknown' }
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

                # Authentication Status Card
                New-UDCard -Title 'Authentication Status' -Style @{ marginBottom = '20px' } -Content {
                    New-UDDynamic -Id 'authStatusPanel' -Content {
                        Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                        try {
                            # Check current auth status using Test-CIEMAuthenticated (reads Az context)
                            $authStatus = Test-CIEMAuthenticated -Provider Azure

                            # Auto-connect if not authenticated but credentials are configured
                            if (-not $authStatus.Authenticated) {
                                $config = Get-CIEMConfig
                                $authMethod = $config.azure.authentication.method
                                $hasCredentials = $false

                                # Check if credentials are configured based on auth method
                                switch ($authMethod) {
                                    'ServicePrincipalSecret' {
                                        $tenantId = $config.azure.authentication.tenantId
                                        $clientId = $config.azure.authentication.servicePrincipal.clientId
                                        $clientSecret = Get-CIEMSecret 'CIEM_Azure_ClientSecret'
                                        $hasCredentials = $tenantId -and $clientId -and $clientSecret
                                    }
                                    'ServicePrincipalCertificate' {
                                        $tenantId = $config.azure.authentication.tenantId
                                        $clientId = $config.azure.authentication.servicePrincipal.clientId
                                        $thumbprint = Get-CIEMSecret 'CIEM_Azure_CertThumbprint'
                                        $hasCredentials = $tenantId -and $clientId -and $thumbprint
                                    }
                                    'ManagedIdentity' {
                                        # Managed identity doesn't need explicit credentials
                                        $hasCredentials = $true
                                    }
                                }

                                if ($hasCredentials) {
                                    Write-CIEMLog -Message "Auto-connecting on scan page load (method: $authMethod)" -Severity INFO -Component 'PSU-ScanPage'
                                    try {
                                        $connectResult = Connect-CIEM -Provider Azure
                                        $connectAzure = $connectResult.Providers | Where-Object { $_.Provider -eq 'Azure' }
                                        if ($connectAzure.Status -eq 'Connected') {
                                            # Re-check auth status after connect
                                            $authStatus = Test-CIEMAuthenticated -Provider Azure
                                            Write-CIEMLog -Message "Auto-connect successful: $($authStatus.Account)" -Severity INFO -Component 'PSU-ScanPage'
                                        }
                                    }
                                    catch {
                                        Write-CIEMLog -Message "Auto-connect failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ScanPage'
                                    }
                                }
                            }

                            if ($authStatus.Authenticated) {
                                $accountInfo = $authStatus.Account
                                $tenantInfo = $authStatus.TenantId

                                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                    New-UDIcon -Icon 'CheckCircle' -Size 'lg' -Style @{ color = '#4caf50' }
                                    New-UDElement -Tag 'div' -Content {
                                        New-UDTypography -Text 'Connected to Azure' -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#4caf50' }
                                        New-UDTypography -Text "Account: $accountInfo" -Variant 'body2' -Style @{ color = '#666' }
                                        New-UDTypography -Text "Tenant: $tenantInfo" -Variant 'caption' -Style @{ color = '#999' }
                                    }
                                }
                            }
                            else {
                                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                    New-UDIcon -Icon 'ExclamationTriangle' -Size 'lg' -Style @{ color = '#ff9800' }
                                    New-UDElement -Tag 'div' -Content {
                                        New-UDTypography -Text 'Not Connected' -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#ff9800' }
                                        New-UDTypography -Text 'Configure authentication on the Configuration page, then refresh.' -Variant 'body2' -Style @{ color = '#666' }
                                    }
                                }
                            }
                        }
                        catch {
                            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                New-UDIcon -Icon 'TimesCircle' -Size 'lg' -Style @{ color = '#f44336' }
                                New-UDTypography -Text "Error checking auth: $($_.Exception.Message)" -Variant 'body2' -Style @{ color = '#f44336' }
                            }
                        }
                    }

                    New-UDButton -Id 'refreshStatusBtn' -Text 'Refresh Status' -Variant 'text' -Size 'small' -ShowLoading -OnClick {
                        Sync-UDElement -Id 'authStatusPanel'
                    } -Style @{ marginTop = '8px' }
                }

                # Scan Configuration Card
                New-UDCard -Title 'Scan Configuration' -Content {
                    # Load available checks to show counts
                    $allChecks = Get-CIEMCheck
                    $entraCount = @($allChecks | Where-Object { $_.service -eq 'Entra' }).Count
                    $iamCount = @($allChecks | Where-Object { $_.service -eq 'IAM' }).Count
                    $kvCount = @($allChecks | Where-Object { $_.service -eq 'KeyVault' }).Count
                    $storageCount = @($allChecks | Where-Object { $_.service -eq 'Storage' }).Count

                    New-UDTypography -Text 'Select Services to Scan' -Variant 'subtitle2' -Style @{ marginBottom = '8px'; marginTop = '8px' }

                    New-UDGrid -Container -Spacing 2 -Content {
                        New-UDGrid -Item -ExtraSmallSize 6 -SmallSize 3 -Content {
                            New-UDCheckbox -Id 'scanEntra' -Label "Entra ID ($entraCount checks)" -Checked $true
                        }
                        New-UDGrid -Item -ExtraSmallSize 6 -SmallSize 3 -Content {
                            New-UDCheckbox -Id 'scanIAM' -Label "IAM ($iamCount checks)" -Checked $true
                        }
                        New-UDGrid -Item -ExtraSmallSize 6 -SmallSize 3 -Content {
                            New-UDCheckbox -Id 'scanKeyVault' -Label "KeyVault ($kvCount checks)" -Checked $true
                        }
                        New-UDGrid -Item -ExtraSmallSize 6 -SmallSize 3 -Content {
                            New-UDCheckbox -Id 'scanStorage' -Label "Storage ($storageCount checks)" -Checked $true
                        }
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

                                # Connect to Azure (handles all auth internally)
                                Write-CIEMLog -Message "Connecting to Azure..." -Severity INFO -Component 'PSU-ScanPage'
                                $connectResult = Connect-CIEM -Provider Azure -Force
                                $connectAzure = $connectResult.Providers | Where-Object { $_.Provider -eq 'Azure' }

                                if ($connectAzure.Status -ne 'Connected') {
                                    Write-CIEMLog -Message "Connect failed: $($connectAzure.Message)" -Severity ERROR -Component 'PSU-ScanPage'
                                    Show-UDToast -Message "Connection failed: $($connectAzure.Message)" -Duration 8000 -BackgroundColor '#f44336'
                                    Sync-UDElement -Id 'authStatusPanel'
                                    return
                                }
                                Write-CIEMLog -Message "Connected: $($connectAzure.Account)" -Severity INFO -Component 'PSU-ScanPage'
                                Sync-UDElement -Id 'authStatusPanel'

                                # Get selected services
                                $selectedServices = @()
                                if ((Get-UDElement -Id 'scanEntra').checked) { $selectedServices += 'Entra' }
                                if ((Get-UDElement -Id 'scanIAM').checked) { $selectedServices += 'IAM' }
                                if ((Get-UDElement -Id 'scanKeyVault').checked) { $selectedServices += 'KeyVault' }
                                if ((Get-UDElement -Id 'scanStorage').checked) { $selectedServices += 'Storage' }

                                if ($selectedServices.Count -eq 0) {
                                    Show-UDToast -Message 'Please select at least one service to scan.' -Duration 5000 -BackgroundColor '#ff9800'
                                    return
                                }

                                $includePassedChecks = (Get-UDElement -Id 'includePassedChecks').checked
                                Write-CIEMLog -Message "Scan config: Services=$($selectedServices -join ','), IncludePassed=$includePassedChecks" -Severity INFO -Component 'PSU-ScanPage'

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
                                Set-UDElement -Id 'scanStatusText' -Properties @{ children = "Scanning $($selectedServices.Count) services..." }
                                Show-UDToast -Message "Starting CIEM scan for: $($selectedServices -join ', ')" -Duration 3000

                                # Run the actual scan
                                Write-CIEMLog -Message "Calling Invoke-CIEMScan..." -Severity INFO -Component 'PSU-ScanPage'
                                try {
                                    $scanResults = Invoke-CIEMScan -Provider Azure -Service $selectedServices -IncludePassed:$includePassedChecks -Verbose 4>&1 | ForEach-Object {
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

                                    # Process scan results
                                    $allResults = @($scanResults)
                                    $failedCount = $scanRun.FailedResults
                                    $passedCount = $scanRun.PassedResults
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
                                                    New-UDTypography -Text "Duration: $durationStr | Total: $($allResults.Count) | Failed: $failedCount | Passed: $passedCount" -Variant 'body2' -Style @{ color = '#666' }
                                                    New-UDTypography -Text 'Expand the scan in the history below to view detailed results.' -Variant 'caption' -Style @{ color = '#666'; marginTop = '4px' }
                                                }
                                            }
                                        }
                                    }

                                    Show-UDToast -Message "Scan complete! Found $failedCount failed checks." -Duration 5000 -BackgroundColor '#4caf50'

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

                    New-UDDynamic -Id 'scanHistoryPanel' -LoadingComponent {
                        New-UDElement -Tag 'div' -Content {
                            New-UDProgress -Circular
                            New-UDTypography -Text 'Loading scan history...' -Variant 'body2' -Style @{ marginTop = '10px'; color = '#666' }
                        } -Attributes @{ style = @{ display = 'flex'; flexDirection = 'column'; alignItems = 'center'; padding = '30px' } }
                    } -Content {
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
                                            date     = $_.StartTime.ToString('yyyy-MM-dd HH:mm')
                                            provider = $_.Provider
                                            services = ($_.Services -join ', ')
                                            status   = $_.Status.ToString()
                                            failed   = $_.FailedResults
                                            passed   = $_.PassedResults
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
                                    New-UDDataGridColumn -Field 'duration' -HeaderName 'Duration' -Width 100
                                ) -AutoHeight $true -Pagination -PageSize 10 -LoadDetailContent {
                                    # Load scan results for this specific scan run
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    $scanRunId = $EventData.row.id

                                    try {
                                        $scanRun = Get-CIEMScanRun -Id $scanRunId -IncludeResults
                                        $rawResults = $scanRun.ScanResults

                                        if ($rawResults -and $rawResults.Count -gt 0) {
                                            # Enrich with check metadata
                                            $checkMetadata = Get-CIEMCheck
                                            $checkLookup = @{}
                                            foreach ($check in $checkMetadata) {
                                                $checkLookup[$check.id] = $check
                                            }

                                            $enrichedResults = $rawResults | ForEach-Object {
                                                $result = $_
                                                $meta = $checkLookup[$result.CheckId]
                                                @{
                                                    id = $result.CheckId + '_' + ($result.ResourceId -replace '[^\w]', '_')
                                                    checkId = $result.CheckId
                                                    title = if ($meta) { $meta.title } else { $result.CheckId }
                                                    severity = ($result.Severity -replace '^(.)', { $_.Groups[1].Value.ToUpper() })
                                                    status = $result.Status
                                                    service = if ($meta) { $meta.service } else { 'Unknown' }
                                                    resourceId = $result.ResourceId
                                                    resourceName = $result.ResourceName
                                                    location = $result.Location
                                                    description = if ($meta) { $meta.description } else { $result.StatusExtended }
                                                    statusExtended = $result.StatusExtended
                                                    remediation = if ($meta -and $meta.remediation) { $meta.remediation.text } else { 'See Devolutions PAM for remediation guidance.' }
                                                    relatedUrl = if ($meta) { $meta.relatedUrl } else { $null }
                                                }
                                            }

                                            # Apply passed filter if not included
                                            if (-not $scanRun.IncludePassed) {
                                                $enrichedResults = $enrichedResults | Where-Object { $_.status -ne 'PASS' }
                                            }

                                            New-UDElement -Tag 'div' -Attributes @{ style = @{ padding = '16px'; backgroundColor = '#fafafa' } } -Content {
                                                # Summary chips
                                                $failedCount = @($enrichedResults | Where-Object { $_.status -eq 'FAIL' }).Count
                                                $passedCount = @($enrichedResults | Where-Object { $_.status -eq 'PASS' }).Count
                                                New-UDElement -Tag 'div' -Attributes @{ style = @{ marginBottom = '16px' } } -Content {
                                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                        New-UDTypography -Text 'Scan Results' -Variant 'h6'
                                                        New-UDChip -Label "Failed: $failedCount" -Size 'small' -Style @{ backgroundColor = '#ffebee'; color = '#c62828' }
                                                        New-UDChip -Label "Passed: $passedCount" -Size 'small' -Style @{ backgroundColor = '#e8f5e9'; color = '#2e7d32' }
                                                    }
                                                }

                                                # Results DataGrid - use pre-loaded data from parent scope
                                                New-UDDataGrid -Data $enrichedResults -Columns @(
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
                                                    New-UDDataGridColumn -Field 'service' -HeaderName 'Service' -Width 100
                                                    New-UDDataGridColumn -Field 'resourceName' -HeaderName 'Resource' -Width 180
                                                ) -AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -LoadDetailContent {
                                                    New-UDCard -Content {
                                                        New-UDTypography -Text "Check Details" -Variant 'h6' -Style @{ marginBottom = '12px' }

                                                        New-UDGrid -Container -Spacing 2 -Content {
                                                            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                                                New-UDTypography -Text "Resource ID" -Variant 'subtitle2' -Style @{ fontWeight = 'bold' }
                                                                New-UDTypography -Text $EventData.row.resourceId -Variant 'body2' -Style @{ wordBreak = 'break-all'; marginBottom = '12px' }
                                                            }
                                                            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                                                New-UDTypography -Text "Location" -Variant 'subtitle2' -Style @{ fontWeight = 'bold' }
                                                                New-UDTypography -Text $(if ($EventData.row.location) { $EventData.row.location } else { 'N/A' }) -Variant 'body2' -Style @{ marginBottom = '12px' }
                                                            }
                                                        }

                                                        New-UDTypography -Text "Status Details" -Variant 'subtitle2' -Style @{ fontWeight = 'bold' }
                                                        New-UDTypography -Text $EventData.row.statusExtended -Style @{ marginBottom = '15px'; backgroundColor = '#f5f5f5'; padding = '8px'; borderRadius = '4px' }

                                                        New-UDTypography -Text "Description" -Variant 'subtitle2' -Style @{ fontWeight = 'bold' }
                                                        New-UDTypography -Text $EventData.row.description -Style @{ marginBottom = '15px' }

                                                        New-UDTypography -Text "Remediation" -Variant 'subtitle2' -Style @{ fontWeight = 'bold' }
                                                        New-UDTypography -Text $EventData.row.remediation -Style @{ marginBottom = '15px' }

                                                        New-UDStack -Direction 'row' -Spacing 2 -Content {
                                                            New-UDButton -Text 'View in Devolutions PAM' -Variant 'contained' -OnClick {
                                                                Show-UDToast -Message 'Redirecting to Devolutions PAM for remediation...' -Duration 3000
                                                            }
                                                            if ($EventData.row.relatedUrl) {
                                                                New-UDButton -Text 'Microsoft Docs' -Variant 'outlined' -Href $EventData.row.relatedUrl -OpenInNewWindow
                                                            }
                                                        }
                                                    }
                                                }
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
                            New-UDSelectOption -Name 'AWS (Coming Soon)' -Value 'AWS'
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
                            # AWS is disabled - show coming soon message
                            New-UDAlert -Severity 'info' -Text 'AWS support is coming soon. Please select Azure as your cloud provider.' -Style @{ marginBottom = '16px' }
                            New-UDSelect -Id 'authMethod' -Label 'Authentication Method' -Option {
                                New-UDSelectOption -Name 'Current Profile (AWS CLI)' -Value 'CurrentProfile'
                            } -DefaultValue 'CurrentProfile' -FullWidth -Disabled
                            # Sync auth fields after AWS dropdown is rendered
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

                    # Warning when on-prem and ManagedIdentity might be selected
                    if (-not $envInfo.SupportsManagedIdentity) {
                        New-UDAlert -Severity 'info' -Text 'Managed Identity is only available in Azure App Service deployments.' -Dense -Style @{ marginBottom = '8px' }
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
                            # AWS fields (disabled for now)
                            New-UDTypography -Text 'AWS authentication configuration will be available in a future release.' -Variant 'body2' -Style @{ color = '#666'; fontStyle = 'italic' }
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

                                    # Show progress
                                    Set-UDElement -Id 'testAuthProgress' -Content {
                                        New-CIEMProgressContent -Text 'Connecting to Azure...'
                                    }
                                    Set-UDElement -Id 'testAuthBtn' -Properties @{ disabled = $true }

                                    # Connect handles all auth logic internally
                                    $connectResult = Connect-CIEM -Provider Azure -Force
                                    $connectAzure = $connectResult.Providers | Where-Object { $_.Provider -eq 'Azure' }
                                    Write-CIEMLog -Message "Connect-CIEM result: Status=$($connectAzure.Status), Account=$($connectAzure.Account)" -Severity INFO -Component 'PSU-ConfigPage'

                                    if ($connectAzure.Status -eq 'Connected') {
                                        Set-UDElement -Id 'testAuthProgress' -Content {
                                            New-CIEMSuccessContent -Text 'Authentication Successful' -Details "Connected as $($connectAzure.Account)"
                                        }
                                    } else {
                                        Write-CIEMLog -Message "Authentication FAILED: $($connectAzure.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                        Set-UDElement -Id 'testAuthProgress' -Content {
                                            New-CIEMErrorContent -Text 'Authentication Failed' -Details $connectAzure.Message
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

                                # Validate AWS is not selected (coming soon)
                                if ($provider -eq 'AWS') {
                                    Write-CIEMLog -Message "AWS provider selected but not supported - rejecting" -Severity WARNING -Component 'PSU-ConfigPage'
                                    Set-UDElement -Id 'saveConfigProgress' -Content {
                                        New-CIEMErrorContent -Text 'Not Supported' -Details 'AWS support is coming soon. Please select Azure as your cloud provider.'
                                    }
                                    return
                                }

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

                                # Check if running in PSU context (Secret: drive available)
                                $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
                                Write-CIEMLog -Message "PSU context detected: $inPSUContext" -Severity INFO -Component 'PSU-ConfigPage'

                                # Non-sensitive settings go to PSU cache
                                $configSettings = @{
                                    'cloudProvider' = $provider
                                    'azure.authentication.method' = $authMethod
                                }
                                Write-CIEMLog -Message "Config settings to save: $($configSettings.Keys -join ', ')" -Severity DEBUG -Component 'PSU-ConfigPage'

                                # Collect credentials based on auth method
                                $credentials = @{}
                                # TenantId goes to PSU cache (not secrets)
                                $tenantIdElement = Get-UDElement -Id 'azTenantId' -ErrorAction SilentlyContinue
                                if ($tenantIdElement -and $tenantIdElement.value) {
                                    $configSettings['azure.authentication.tenantId'] = $tenantIdElement.value
                                    Write-CIEMLog -Message "TenantId collected from form: $($tenantIdElement.value.Substring(0,8))... (saving to PSU cache)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                }

                                switch ($authMethod) {
                                    'ServicePrincipalSecret' {
                                        $clientId = (Get-UDElement -Id 'azSpClientId').value
                                        $clientSecret = (Get-UDElement -Id 'azSpClientSecret').value
                                        Write-CIEMLog -Message "ServicePrincipalSecret - ClientId: $(if($clientId){'found'}else{'empty'}), ClientSecret: $(if($clientSecret -and $clientSecret -ne '********'){'new value'}elseif($clientSecret -eq '********'){'placeholder'}else{'empty'})" -Severity DEBUG -Component 'PSU-ConfigPage'
                                        # ClientId goes to PSU cache (not secrets)
                                        if ($clientId) { $configSettings['azure.authentication.servicePrincipal.clientId'] = $clientId }
                                        # Only ClientSecret goes to PSU secrets (it's the only sensitive value)
                                        if ($clientSecret -and $clientSecret -ne '********') { $credentials['ClientSecret'] = $clientSecret }
                                    }
                                    'ServicePrincipalCertificate' {
                                        $clientId = (Get-UDElement -Id 'azCertClientId').value
                                        $thumbprint = (Get-UDElement -Id 'azCertThumbprint').value
                                        Write-CIEMLog -Message "ServicePrincipalCertificate - ClientId: $(if($clientId){'found'}else{'empty'}), Thumbprint: $(if($thumbprint){'found'}else{'empty'})" -Severity DEBUG -Component 'PSU-ConfigPage'
                                        if ($clientId) { $credentials['ClientId'] = $clientId }
                                        if ($thumbprint) { $credentials['CertThumbprint'] = $thumbprint }
                                    }
                                    # ManagedIdentity requires no credentials - uses system-assigned identity
                                }
                                Write-CIEMLog -Message "Credentials collected: $($credentials.Keys -join ', ')" -Severity INFO -Component 'PSU-ConfigPage'

                                # Save credentials to PSU secrets (if in PSU context)
                                if ($inPSUContext -and $credentials.Count -gt 0) {
                                    Write-CIEMLog -Message "Saving credentials to PSU secrets..." -Severity INFO -Component 'PSU-ConfigPage'
                                    $secretsCreated = @()
                                    foreach ($key in $credentials.Keys) {
                                        $secretName = "CIEM_Azure_$key"
                                        $secretValue = $credentials[$key]
                                        if (-not [string]::IsNullOrEmpty($secretValue)) {
                                            Write-CIEMLog -Message "Processing secret: $secretName" -Severity DEBUG -Component 'PSU-ConfigPage'
                                            # Check if secret exists
                                            $existingVar = Get-PSUVariable -Name $secretName -ErrorAction SilentlyContinue
                                            if ($existingVar) {
                                                Write-CIEMLog -Message "Updating existing secret: $secretName" -Severity DEBUG -Component 'PSU-ConfigPage'
                                                Set-PSUVariable -Variable $existingVar -Value $secretValue
                                            } else {
                                                Write-CIEMLog -Message "Creating new secret: $secretName (Vault: Database)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                                New-PSUVariable -Name $secretName -Value $secretValue -Vault 'Database'
                                            }
                                            $secretsCreated += $secretName
                                        }
                                    }
                                    Write-CIEMLog -Message "Secrets saved: $($secretsCreated -join ', ')" -Severity INFO -Component 'PSU-ConfigPage'
                                } elseif (-not $inPSUContext -and $credentials.Count -gt 0) {
                                    Write-CIEMLog -Message "Not in PSU context - credentials not saved" -Severity WARNING -Component 'PSU-ConfigPage'
                                }

                                # Save non-sensitive config to PSU cache and update in-memory config
                                Write-CIEMLog -Message "Calling Set-CIEMConfig..." -Severity INFO -Component 'PSU-ConfigPage'
                                Set-CIEMConfig -Settings $configSettings
                                Write-CIEMLog -Message "Set-CIEMConfig completed" -Severity INFO -Component 'PSU-ConfigPage'

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
                                    # Check for changes in credentials
                                    elseif ($credentials.Count -gt 0) {
                                        if ($credentials['TenantId'] -and $credentials['TenantId'] -ne $originalAuth.TenantId) { $authChanged = $true }
                                        if ($credentials['ClientId'] -and $credentials['ClientId'] -ne $originalAuth.ClientId) { $authChanged = $true }
                                        if ($credentials['ClientSecret'] -and $credentials['ClientSecret'] -ne '********') { $authChanged = $true }
                                        if ($credentials['CertThumbprint'] -and $credentials['CertThumbprint'] -ne $originalAuth.CertThumbprint) { $authChanged = $true }
                                        if ($authChanged) { Write-CIEMLog -Message "Auth changed: credentials differ" -Severity DEBUG -Component 'PSU-ConfigPage' }
                                    }
                                } else {
                                    # No original values stored (first save), consider it a change if credentials provided
                                    $authChanged = $credentials.Count -gt 0
                                    Write-CIEMLog -Message "No original auth values stored, authChanged=$authChanged" -Severity DEBUG -Component 'PSU-ConfigPage'
                                }

                                # Test authentication if settings changed
                                Write-CIEMLog -Message "Auth changed: $authChanged, Provider: $provider" -Severity INFO -Component 'PSU-ConfigPage'
                                if ($authChanged -and $provider -eq 'Azure') {
                                    Write-CIEMLog -Message "Auth settings changed - initiating Connect-CIEM..." -Severity INFO -Component 'PSU-ConfigPage'
                                    Set-UDElement -Id 'saveConfigProgress' -Content {
                                        New-CIEMProgressContent -Text 'Testing authentication...'
                                    }
                                    try {
                                        # Config already updated by Save-CIEMConfig above
                                        $result = Connect-CIEM -Provider Azure -Force
                                        $azureResult = $result.Providers | Where-Object { $_.Provider -eq 'Azure' }
                                        Write-CIEMLog -Message "Connect-CIEM result: Status=$($azureResult.Status), Account=$($azureResult.Account), Message=$($azureResult.Message)" -Severity INFO -Component 'PSU-ConfigPage'
                                        if ($azureResult.Status -eq 'Connected') {
                                            Set-UDElement -Id 'saveConfigProgress' -Content {
                                                New-CIEMSuccessContent -Text 'Configuration Saved' -Details "Connected as $($azureResult.Account)"
                                            }
                                            # Update session state with new values
                                            $Session:OriginalAuthValues = @{
                                                Provider = $provider
                                                Method = $authMethod
                                                TenantId = $credentials['TenantId']
                                                ClientId = $credentials['ClientId']
                                                CertThumbprint = $credentials['CertThumbprint']
                                            }
                                            Write-CIEMLog -Message "Session:OriginalAuthValues updated" -Severity DEBUG -Component 'PSU-ConfigPage'
                                        } else {
                                            Write-CIEMLog -Message "Authentication failed: $($azureResult.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                            Set-UDElement -Id 'saveConfigProgress' -Content {
                                                New-UDCard -Style @{ backgroundColor = '#fff3e0'; marginTop = '12px'; marginBottom = '12px' } -Content {
                                                    New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                        New-UDIcon -Icon 'ExclamationTriangle' -Size 'lg' -Style @{ color = '#ff9800' }
                                                        New-UDElement -Tag 'div' -Content {
                                                            New-UDTypography -Text 'Configuration Saved (Auth Failed)' -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#e65100' }
                                                            New-UDTypography -Text $azureResult.Message -Variant 'body2' -Style @{ color = '#666' }
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

        # Helper function to create the About page
        function New-CIEMAboutPage {
            param($Navigation)

            New-UDPage -Name 'About' -Url '/ciem/about' -Content {
                New-UDTypography -Text 'About Devolutions CIEM' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }

                New-UDCard -Title 'Cloud Infrastructure Entitlement Management' -Content {
                    New-UDTypography -Text 'Devolutions CIEM is a security scanning solution that helps identify identity and access management issues across your cloud infrastructure.' -Variant 'body1' -Style @{ marginBottom = '20px' }

                    New-UDTypography -Text 'Key Features:' -Variant 'h6' -Style @{ marginTop = '20px' }
                    New-UDList -Content {
                        New-UDListItem -Label '46 Azure identity-focused security checks'
                        New-UDListItem -Label 'Entra ID (Azure AD) security validation'
                        New-UDListItem -Label 'IAM/RBAC permissions analysis'
                        New-UDListItem -Label 'KeyVault access and configuration checks'
                        New-UDListItem -Label 'Storage account security validation'
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
        $ScanPage = New-CIEMScanPage -Navigation $Navigation
        $ConfigPage = New-CIEMConfigPage -Navigation $Navigation
        $AboutPage = New-CIEMAboutPage -Navigation $Navigation

        # Return the App
        New-UDApp -Title 'Devolutions CIEM' -Pages @(
            $DashboardPage
            $ScanPage
            $ConfigPage
            $AboutPage
        ) -DefaultTheme 'Light'
    }
}
