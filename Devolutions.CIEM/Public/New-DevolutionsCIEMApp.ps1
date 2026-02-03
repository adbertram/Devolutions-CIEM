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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', 'Get-SampleFindings', Justification = 'Returns a collection of sample findings')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'SampleFindings', Justification = 'Parameter is used inside PSU script blocks which PSScriptAnalyzer does not analyze')]
    param()

    begin {
        # Helper function to get sample findings data for PoC demonstration
        function Get-SampleFindings {
            @(
                [PSCustomObject]@{
                    Id = 'ENTRA-001'; CheckId = 'entra_id_mfa_not_enabled_for_users'; Title = 'MFA Not Enabled for Users'
                    Severity = 'CRITICAL'; Status = 'FAIL'; Provider = 'Azure'; Service = 'Entra ID'
                    ResourceId = 'user@contoso.com'; ResourceName = 'John Doe'
                    Description = 'Multi-factor authentication is not enabled for this user account'
                    Remediation = 'Enable MFA for all user accounts through Azure AD > Security > MFA'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
                [PSCustomObject]@{
                    Id = 'ENTRA-002'; CheckId = 'entra_id_no_conditional_access_policy'; Title = 'No Conditional Access Policies'
                    Severity = 'HIGH'; Status = 'FAIL'; Provider = 'Azure'; Service = 'Entra ID'
                    ResourceId = 'tenant-12345'; ResourceName = 'Contoso Tenant'
                    Description = 'No conditional access policies are configured for the tenant'
                    Remediation = 'Configure conditional access policies in Azure AD'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
                [PSCustomObject]@{
                    Id = 'IAM-001'; CheckId = 'iam_custom_role_excessive_permissions'; Title = 'Custom Role with Excessive Permissions'
                    Severity = 'HIGH'; Status = 'FAIL'; Provider = 'Azure'; Service = 'IAM'
                    ResourceId = '/subscriptions/sub-123/providers/Microsoft.Authorization/roleDefinitions/role-456'
                    ResourceName = 'Custom Admin Role'
                    Description = 'Custom role has wildcard (*) permissions'
                    Remediation = 'Review and restrict permissions to least privilege'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
                [PSCustomObject]@{
                    Id = 'KV-001'; CheckId = 'keyvault_secrets_expiration_not_set'; Title = 'KeyVault Secrets Without Expiration'
                    Severity = 'MEDIUM'; Status = 'FAIL'; Provider = 'Azure'; Service = 'KeyVault'
                    ResourceId = '/subscriptions/sub-123/resourceGroups/rg-prod/providers/Microsoft.KeyVault/vaults/kv-prod'
                    ResourceName = 'kv-prod'
                    Description = 'Secrets in this KeyVault do not have expiration dates set'
                    Remediation = 'Set expiration dates on all secrets'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
                [PSCustomObject]@{
                    Id = 'STORAGE-001'; CheckId = 'storage_blob_public_access_enabled'; Title = 'Blob Public Access Enabled'
                    Severity = 'CRITICAL'; Status = 'FAIL'; Provider = 'Azure'; Service = 'Storage'
                    ResourceId = '/subscriptions/sub-123/resourceGroups/rg-prod/providers/Microsoft.Storage/storageAccounts/stprod123'
                    ResourceName = 'stprod123'
                    Description = 'Storage account allows public blob access'
                    Remediation = 'Disable public blob access on the storage account'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
                [PSCustomObject]@{
                    Id = 'ENTRA-003'; CheckId = 'entra_id_security_defaults_disabled'; Title = 'Security Defaults Disabled'
                    Severity = 'MEDIUM'; Status = 'FAIL'; Provider = 'Azure'; Service = 'Entra ID'
                    ResourceId = 'tenant-12345'; ResourceName = 'Contoso Tenant'
                    Description = 'Security defaults are disabled and no conditional access policies exist'
                    Remediation = 'Enable security defaults or configure conditional access'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
                [PSCustomObject]@{
                    Id = 'KV-002'; CheckId = 'keyvault_rbac_enabled'; Title = 'KeyVault RBAC Enabled'
                    Severity = 'INFO'; Status = 'PASS'; Provider = 'Azure'; Service = 'KeyVault'
                    ResourceId = '/subscriptions/sub-123/resourceGroups/rg-prod/providers/Microsoft.KeyVault/vaults/kv-secure'
                    ResourceName = 'kv-secure'
                    Description = 'RBAC is properly enabled for KeyVault access'
                    Remediation = 'N/A - Check passed'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
                [PSCustomObject]@{
                    Id = 'STORAGE-002'; CheckId = 'storage_encryption_at_rest'; Title = 'Encryption at Rest Enabled'
                    Severity = 'INFO'; Status = 'PASS'; Provider = 'Azure'; Service = 'Storage'
                    ResourceId = '/subscriptions/sub-123/resourceGroups/rg-prod/providers/Microsoft.Storage/storageAccounts/stprod456'
                    ResourceName = 'stprod456'
                    Description = 'Storage account has encryption at rest enabled'
                    Remediation = 'N/A - Check passed'
                    ComplianceFramework = 'CIS Azure 1.4'
                }
            )
        }

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

        # Helper function to create navigation items
        function New-CIEMNavigation {
            @(
                New-UDListItem -Label 'Dashboard' -Icon (New-UDIcon -Icon 'Home') -Href '/ciem'
                New-UDListItem -Label 'Findings' -Icon (New-UDIcon -Icon 'ExclamationTriangle') -Href '/ciem/findings'
                New-UDListItem -Label 'Scan' -Icon (New-UDIcon -Icon 'Play') -Href '/ciem/scan'
                New-UDListItem -Label 'Configuration' -Icon (New-UDIcon -Icon 'Cog') -Href '/ciem/config'
                New-UDListItem -Label 'About' -Icon (New-UDIcon -Icon 'InfoCircle') -Href '/ciem/about'
            )
        }

        # Helper function to create the Dashboard page
        function New-CIEMDashboardPage {
            param($Navigation, $SampleFindings)

            New-UDPage -Name 'Dashboard' -Url '/ciem' -Content {
                $Findings = $SampleFindings
                $FailedFindings = $Findings | Where-Object { $_.Status -eq 'FAIL' }
                $PassedFindings = $Findings | Where-Object { $_.Status -eq 'PASS' }
                $CriticalCount = ($FailedFindings | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
                $HighCount = ($FailedFindings | Where-Object { $_.Severity -eq 'HIGH' }).Count
                $MediumCount = ($FailedFindings | Where-Object { $_.Severity -eq 'MEDIUM' }).Count
                $LowCount = ($FailedFindings | Where-Object { $_.Severity -eq 'LOW' }).Count

                New-UDTypography -Text 'Devolutions CIEM Dashboard' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
                New-UDTypography -Text 'Cloud Infrastructure Entitlement Management - Security Findings Overview' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

                New-UDGrid -Container -Content {
                    New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                        New-UDCard -Title 'Total Findings' -Content {
                            New-UDTypography -Text $Findings.Count -Variant 'h3' -Style @{ color = '#1976d2'; textAlign = 'center' }
                        } -Style @{ textAlign = 'center' }
                    }
                    New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                        New-UDCard -Title 'Failed Checks' -Content {
                            New-UDTypography -Text $FailedFindings.Count -Variant 'h3' -Style @{ color = '#f44336'; textAlign = 'center' }
                        } -Style @{ textAlign = 'center' }
                    }
                    New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
                        New-UDCard -Title 'Passed Checks' -Content {
                            New-UDTypography -Text $PassedFindings.Count -Variant 'h3' -Style @{ color = '#4caf50'; textAlign = 'center' }
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
                        New-UDCard -Title 'Findings by Severity' -Content {
                            $SeverityData = @(
                                @{ Name = 'Critical'; Count = $CriticalCount; color = '#9c27b0' }
                                @{ Name = 'High'; Count = $HighCount; color = '#f44336' }
                                @{ Name = 'Medium'; Count = $MediumCount; color = '#ff9800' }
                                @{ Name = 'Low'; Count = $LowCount; color = '#2196f3' }
                            ) | Where-Object { $_.Count -gt 0 }
                            if ($SeverityData.Count -gt 0) {
                                New-UDChartJS -Type 'doughnut' -Data $SeverityData -DataProperty Count -LabelProperty Name -BackgroundColor @('#9c27b0', '#f44336', '#ff9800', '#2196f3')
                            } else {
                                New-UDTypography -Text 'No failed findings' -Style @{ textAlign = 'center'; padding = '40px' }
                            }
                        }
                    }
                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                        New-UDCard -Title 'Findings by Service' -Content {
                            $ServiceData = $FailedFindings | Group-Object -Property Service | ForEach-Object { @{ Name = $_.Name; Count = $_.Count } }
                            if ($ServiceData.Count -gt 0) {
                                New-UDChartJS -Type 'bar' -Data $ServiceData -DataProperty Count -LabelProperty Name -BackgroundColor '#1976d2'
                            } else {
                                New-UDTypography -Text 'No failed findings' -Style @{ textAlign = 'center'; padding = '40px' }
                            }
                        }
                    }
                }

                New-UDCard -Title 'Recent Critical & High Findings' -Style @{ marginTop = '20px' } -Content {
                    $CriticalHighFindings = $FailedFindings | Where-Object { $_.Severity -in @('CRITICAL', 'HIGH') } | Select-Object -First 5
                    if ($CriticalHighFindings.Count -gt 0) {
                        New-UDTable -Data $CriticalHighFindings -Columns @(
                            New-UDTableColumn -Property 'Id' -Title 'ID'
                            New-UDTableColumn -Property 'Title' -Title 'Finding'
                            New-UDTableColumn -Property 'Severity' -Title 'Severity' -Render {
                                $color = switch ($EventData.Severity) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } default { '#666' } }
                                New-UDChip -Label $EventData.Severity -Style @{ backgroundColor = $color; color = 'white' }
                            }
                            New-UDTableColumn -Property 'Service' -Title 'Service'
                            New-UDTableColumn -Property 'ResourceName' -Title 'Resource'
                        )
                    } else {
                        New-UDTypography -Text 'No critical or high severity findings!' -Style @{ padding = '20px'; color = '#4caf50' }
                    }
                }
            } -Navigation $Navigation -NavigationLayout permanent
        }

        # Helper function to create the Findings page
        function New-CIEMFindingsPage {
            param($Navigation, $SampleFindings)

            New-UDPage -Name 'Findings' -Url '/ciem/findings' -Content {
                New-UDTypography -Text 'Security Findings' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
                New-UDTypography -Text 'Detailed view of all CIEM security findings' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

                New-UDDataGrid -LoadRows {
                    $Data = $SampleFindings | ForEach-Object {
                        @{ id = $_.Id; checkId = $_.CheckId; title = $_.Title; severity = $_.Severity; status = $_.Status
                           provider = $_.Provider; service = $_.Service; resourceName = $_.ResourceName
                           description = $_.Description; remediation = $_.Remediation }
                    }
                    $Data | Out-UDDataGridData -Context $EventData -TotalRows $Data.Count
                } -Columns @(
                    New-UDDataGridColumn -Field 'id' -HeaderName 'ID' -Width 120
                    New-UDDataGridColumn -Field 'title' -HeaderName 'Finding' -Flex 1
                    New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 120 -Render {
                        $color = switch ($EventData.severity) { 'CRITICAL' { '#9c27b0' } 'HIGH' { '#f44336' } 'MEDIUM' { '#ff9800' } 'LOW' { '#2196f3' } 'INFO' { '#4caf50' } default { '#666' } }
                        New-UDChip -Label $EventData.severity -Style @{ backgroundColor = $color; color = 'white' }
                    }
                    New-UDDataGridColumn -Field 'status' -HeaderName 'Status' -Width 100 -Render {
                        $color = if ($EventData.status -eq 'FAIL') { '#f44336' } else { '#4caf50' }
                        New-UDChip -Label $EventData.status -Style @{ backgroundColor = $color; color = 'white' }
                    }
                    New-UDDataGridColumn -Field 'service' -HeaderName 'Service' -Width 120
                    New-UDDataGridColumn -Field 'resourceName' -HeaderName 'Resource' -Width 150
                ) -AutoHeight $true -Pagination -ShowQuickFilter -LoadDetailContent {
                    New-UDCard -Content {
                        New-UDTypography -Text "Description" -Variant 'h6'
                        New-UDTypography -Text $EventData.row.description -Style @{ marginBottom = '15px' }
                        New-UDTypography -Text "Remediation" -Variant 'h6'
                        New-UDTypography -Text $EventData.row.remediation -Style @{ marginBottom = '15px' }
                        New-UDButton -Text 'View in Devolutions PAM' -Variant 'contained' -OnClick {
                            Show-UDToast -Message 'Redirecting to Devolutions PAM for remediation...' -Duration 3000
                        }
                    }
                } -OnExport {
                    if ($EventData.Type -eq 'JSON') {
                        # Build hierarchical structure: providers -> services -> findings
                        $providers = @{}
                        $severityCounts = @{ CRITICAL = 0; HIGH = 0; MEDIUM = 0; LOW = 0; INFO = 0 }

                        foreach ($finding in $SampleFindings) {
                            $provider = $finding.Provider
                            $service = $finding.Service

                            # Initialize provider if not exists
                            if (-not $providers.ContainsKey($provider)) {
                                $providers[$provider] = @{}
                            }

                            # Initialize service if not exists
                            if (-not $providers[$provider].ContainsKey($service)) {
                                $providers[$provider][$service] = @{
                                    findings = @()
                                    summary = @{ total = 0; failed = 0; passed = 0 }
                                }
                            }

                            # Add finding to service
                            $providers[$provider][$service].findings += @{
                                id = $finding.Id
                                checkId = $finding.CheckId
                                title = $finding.Title
                                severity = $finding.Severity
                                status = $finding.Status
                                resourceName = $finding.ResourceName
                                description = $finding.Description
                                remediation = $finding.Remediation
                            }

                            # Update service summary
                            $providers[$provider][$service].summary.total++
                            if ($finding.Status -eq 'FAIL') {
                                $providers[$provider][$service].summary.failed++
                            } else {
                                $providers[$provider][$service].summary.passed++
                            }

                            # Update severity counts
                            if ($severityCounts.ContainsKey($finding.Severity)) {
                                $severityCounts[$finding.Severity]++
                            }
                        }

                        # Build final export structure
                        $ExportData = @{
                            metadata = @{
                                exportedAt = (Get-Date).ToString('o')
                                totalFindings = $SampleFindings.Count
                                summary = $severityCounts
                            }
                            providers = $providers
                        }

                        $JsonContent = $ExportData | ConvertTo-Json -Depth 10
                        Out-UDDataGridExport -Data $JsonContent -FileName 'ciem-findings.json'
                    }
                    elseif ($EventData.Type -eq 'CSV') {
                        # CSV remains flat for spreadsheet compatibility
                        $CsvData = $SampleFindings | ForEach-Object {
                            @{
                                id = $_.Id
                                checkId = $_.CheckId
                                title = $_.Title
                                severity = $_.Severity
                                status = $_.Status
                                provider = $_.Provider
                                service = $_.Service
                                resourceName = $_.ResourceName
                                description = $_.Description
                                remediation = $_.Remediation
                            }
                        }
                        $CsvContent = $CsvData | ConvertTo-Csv -NoTypeInformation | Out-String
                        Out-UDDataGridExport -Data $CsvContent -FileName 'ciem-findings.csv'
                    }
                } -ExportOptions @('CSV', 'JSON')
            } -Navigation $Navigation -NavigationLayout permanent
        }

        # Helper function to create the Scan page
        function New-CIEMScanPage {
            param($Navigation)

            New-UDPage -Name 'Scan' -Url '/ciem/scan' -Content {
                New-UDTypography -Text 'Run CIEM Scan' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
                New-UDTypography -Text 'Configure and execute a CIEM security scan against your cloud environment' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

                New-UDCard -Title 'Scan Configuration' -Content {
                    New-UDElement -Tag 'div' -Content {
                        New-UDSelect -Id 'provider' -Label 'Cloud Provider' -Option {
                            New-UDSelectOption -Name 'Azure' -Value 'azure'
                            New-UDSelectOption -Name 'AWS' -Value 'aws'
                        } -DefaultValue 'azure' -FullWidth
                    } -Attributes @{ style = @{ marginBottom = '16px'; marginTop = '16px' } }

                    New-UDElement -Tag 'div' -Content {
                        New-UDTextbox -Id 'subscriptionId' -Label 'Subscription ID (Optional)' -Placeholder 'Leave empty to scan all accessible subscriptions' -FullWidth
                    } -Attributes @{ style = @{ marginBottom = '16px' } }

                    New-UDElement -Tag 'div' -Content {
                        New-UDCheckbox -Id 'includePassedChecks' -Label 'Include Passed Checks in Results' -Checked $true
                    } -Attributes @{ style = @{ marginBottom = '16px' } }

                    New-UDButton -Text 'Start Scan' -Variant 'contained' -Color 'primary' -OnClick {
                        $Provider = (Get-UDElement -Id 'provider').value
                        Show-UDToast -Message "Scan initiated for $Provider provider..." -Duration 5000
                        Show-UDToast -Message "PoC Mode: Displaying sample findings data" -Duration 5000 -BackgroundColor '#ff9800'
                        Start-Sleep -Seconds 2
                        Invoke-UDRedirect '/ciem/findings'
                    }
                }

                New-UDCard -Title 'Recent Scan History' -Style @{ marginTop = '20px' } -Content {
                    $ScanHistory = @(
                        @{ Id = 1; Date = (Get-Date).AddHours(-2).ToString('yyyy-MM-dd HH:mm'); Provider = 'Azure'; Findings = 6; Duration = '45s' }
                        @{ Id = 2; Date = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd HH:mm'); Provider = 'Azure'; Findings = 8; Duration = '52s' }
                        @{ Id = 3; Date = (Get-Date).AddDays(-3).ToString('yyyy-MM-dd HH:mm'); Provider = 'Azure'; Findings = 12; Duration = '1m 10s' }
                    )
                    New-UDTable -Data $ScanHistory -Columns @(
                        New-UDTableColumn -Property 'Date' -Title 'Scan Date'
                        New-UDTableColumn -Property 'Provider' -Title 'Provider'
                        New-UDTableColumn -Property 'Findings' -Title 'Failed Findings'
                        New-UDTableColumn -Property 'Duration' -Title 'Duration'
                    )
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
                    $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
                    $Session:OriginalAuthValues = @{
                        Provider = $currentProvider
                        Method = if ($CurrentConfig.azure.authentication.method) { $CurrentConfig.azure.authentication.method } else { 'ServicePrincipalSecret' }
                        TenantId = if ($inPSUContext) { $Secret:CIEM_Azure_TenantId } else { $null }
                        ClientId = if ($inPSUContext) { $Secret:CIEM_Azure_ClientId } else { $null }
                        CertThumbprint = if ($inPSUContext) { $Secret:CIEM_Azure_CertThumbprint } else { $null }
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
                        if ($inPSUContext) {
                            # Only secrets come from PSU secrets (not TenantId/ClientId which are in cache)
                            $storedCreds.ClientSecretExists = -not [string]::IsNullOrEmpty($Secret:CIEM_Azure_ClientSecret)
                            $storedCreds.CertThumbprint = $Secret:CIEM_Azure_CertThumbprint
                            $storedCreds.CertPasswordExists = -not [string]::IsNullOrEmpty($Secret:CIEM_Azure_CertPassword)
                            $storedCreds.ManagedIdentityClientId = $Secret:CIEM_Azure_ManagedIdentityClientId
                        }

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

                            New-UDButton -Text 'Test Authentication' -Variant 'outlined' -Color 'secondary' -OnClick {
                                try {
                                    Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                    Write-CIEMLog -Message "Test Authentication button clicked" -Severity INFO -Component 'PSU-ConfigPage'
                                    Show-UDToast -Message 'Testing authentication...' -Duration 2000

                                    # First check if already authenticated
                                    Write-CIEMLog -Message "Checking existing authentication..." -Severity DEBUG -Component 'PSU-ConfigPage'
                                    $results = Test-CIEMAuthenticated
                                    $azureResult = $results | Where-Object { $_.Provider -eq 'Azure' }
                                    Write-CIEMLog -Message "Current auth state - Authenticated: $($azureResult.Authenticated)" -Severity DEBUG -Component 'PSU-ConfigPage'

                                    # If not authenticated, try to connect using saved credentials
                                    if (-not $azureResult -or -not $azureResult.Authenticated) {
                                        Write-CIEMLog -Message "Not authenticated - attempting Connect-CIEM..." -Severity INFO -Component 'PSU-ConfigPage'
                                        Show-UDToast -Message 'Connecting to Azure...' -Duration 3000
                                        try {
                                            $connectResult = Connect-CIEM -Provider Azure -Force
                                            $connectAzure = $connectResult.Providers | Where-Object { $_.Provider -eq 'Azure' }
                                            Write-CIEMLog -Message "Connect-CIEM result: Status=$($connectAzure.Status), Account=$($connectAzure.Account), Message=$($connectAzure.Message)" -Severity INFO -Component 'PSU-ConfigPage'

                                            if ($connectAzure.Status -eq 'Connected') {
                                                Write-CIEMLog -Message "Authentication test PASSED - Account: $($connectAzure.Account)" -Severity INFO -Component 'PSU-ConfigPage'
                                                Show-UDToast -Message "Successfully connected to Azure as $($connectAzure.Account)" -Duration 5000 -BackgroundColor '#4caf50'
                                            } else {
                                                Write-CIEMLog -Message "Authentication FAILED: $($connectAzure.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                                Show-UDToast -Message "Authentication failed: $($connectAzure.Message)" -Duration 8000 -BackgroundColor '#f44336'
                                            }
                                        } catch {
                                            Write-CIEMLog -Message "Connect-CIEM exception: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                            Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                            Show-UDToast -Message "Authentication failed: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                                        }
                                    } else {
                                        # Already authenticated - show current account
                                        $context = Get-AzContext -ErrorAction SilentlyContinue
                                        $accountInfo = if ($context.Account) { $context.Account.Id } else { 'Unknown' }
                                        Write-CIEMLog -Message "Already authenticated - Account: $accountInfo" -Severity INFO -Component 'PSU-ConfigPage'
                                        Show-UDToast -Message "Already connected to Azure as $accountInfo" -Duration 5000 -BackgroundColor '#4caf50'
                                    }
                                } catch {
                                    Write-CIEMLog -Message "Test Authentication exception: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                    Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                    Show-UDToast -Message "Authentication test failed: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                                }
                            }
                        }
                    } -Attributes @{ style = @{ marginTop = '16px' } }
                }

                New-UDElement -Tag 'div' -Content {
                    New-UDStack -Direction 'row' -Spacing 2 -Content {
                        New-UDButton -Text 'Save Configuration' -Variant 'contained' -Color 'primary' -OnClick {
                            try {
                                Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
                                Write-CIEMLog -Message "Save Configuration button clicked" -Severity INFO -Component 'PSU-ConfigPage'
                                $provider = (Get-UDElement -Id 'cloudProvider').value
                                $authMethod = (Get-UDElement -Id 'authMethod').value
                                Write-CIEMLog -Message "Form values - Provider: $provider, AuthMethod: $authMethod" -Severity DEBUG -Component 'PSU-ConfigPage'

                                # Validate AWS is not selected (coming soon)
                                if ($provider -eq 'AWS') {
                                    Write-CIEMLog -Message "AWS provider selected but not supported - rejecting" -Severity WARNING -Component 'PSU-ConfigPage'
                                    Show-UDToast -Message 'AWS support is coming soon. Please select Azure as your cloud provider.' -Duration 5000 -BackgroundColor '#ff9800'
                                    return
                                }

                                # Validate ManagedIdentity is only saved when supported
                                $envInfo = Get-PSUInstalledEnvironment
                                Write-CIEMLog -Message "Environment: $($envInfo.Environment), SupportsManagedIdentity: $($envInfo.SupportsManagedIdentity)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                if ($authMethod -eq 'ManagedIdentity' -and -not $envInfo.SupportsManagedIdentity) {
                                    Write-CIEMLog -Message "ManagedIdentity selected but not supported in this environment" -Severity WARNING -Component 'PSU-ConfigPage'
                                    Show-UDToast -Message 'Managed Identity is not available in on-premises deployments. Please choose a different authentication method.' -Duration 8000 -BackgroundColor '#f44336'
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
                                    Show-UDToast -Message 'Not running in PSU context. ClientSecret was not saved (requires PSU secret storage).' -Duration 8000 -BackgroundColor '#ff9800'
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
                                    Show-UDToast -Message 'Authentication settings changed. Testing connection...' -Duration 3000
                                    try {
                                        # Config already updated by Save-CIEMConfig above
                                        $result = Connect-CIEM -Provider Azure -Force
                                        $azureResult = $result.Providers | Where-Object { $_.Provider -eq 'Azure' }
                                        Write-CIEMLog -Message "Connect-CIEM result: Status=$($azureResult.Status), Account=$($azureResult.Account), Message=$($azureResult.Message)" -Severity INFO -Component 'PSU-ConfigPage'
                                        if ($azureResult.Status -eq 'Connected') {
                                            Show-UDToast -Message "Configuration saved and authentication successful! Connected as $($azureResult.Account)" -Duration 5000 -BackgroundColor '#4caf50'
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
                                            Show-UDToast -Message "Configuration saved but authentication failed: $($azureResult.Message)" -Duration 8000 -BackgroundColor '#ff9800'
                                        }
                                    } catch {
                                        Write-CIEMLog -Message "Connect-CIEM exception: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                        Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                        Show-UDToast -Message "Configuration saved but authentication test failed: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#ff9800'
                                    }
                                } else {
                                    Write-CIEMLog -Message "No auth change detected or not Azure - skipping Connect-CIEM" -Severity DEBUG -Component 'PSU-ConfigPage'
                                    Show-UDToast -Message 'Configuration saved successfully!' -Duration 5000 -BackgroundColor '#4caf50'
                                }
                                Write-CIEMLog -Message "Save Configuration completed successfully" -Severity INFO -Component 'PSU-ConfigPage'
                            } catch {
                                Write-CIEMLog -Message "Save Configuration failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ConfigPage'
                                Show-UDToast -Message "Failed to save configuration: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                            }
                        }

                        New-UDButton -Text 'Reset to Defaults' -Variant 'outlined' -Color 'secondary' -OnClick {
                            try {
                                Set-UDElement -Id 'cloudProvider' -Properties @{ value = 'Azure' }
                                Set-UDElement -Id 'authMethod' -Properties @{ value = 'ServicePrincipalSecret' }
                                Sync-UDElement -Id 'authMethodContainer'
                                Sync-UDElement -Id 'authFieldsContainer'
                                Show-UDToast -Message 'Form reset to default values. Click Save to apply.' -Duration 5000 -BackgroundColor '#ff9800'
                            } catch {
                                Show-UDToast -Message "Failed to reset: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                            }
                        }
                    }
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

        # Get sample findings data and navigation
        $SampleFindings = Get-SampleFindings
        $Navigation = New-CIEMNavigation

        # Create pages
        $DashboardPage = New-CIEMDashboardPage -Navigation $Navigation -SampleFindings $SampleFindings
        $FindingsPage = New-CIEMFindingsPage -Navigation $Navigation -SampleFindings $SampleFindings
        $ScanPage = New-CIEMScanPage -Navigation $Navigation
        $ConfigPage = New-CIEMConfigPage -Navigation $Navigation
        $AboutPage = New-CIEMAboutPage -Navigation $Navigation

        # Return the App
        New-UDApp -Title 'Devolutions CIEM' -Pages @(
            $DashboardPage
            $FindingsPage
            $ScanPage
            $ConfigPage
            $AboutPage
        ) -DefaultTheme 'Light'
    }
}
