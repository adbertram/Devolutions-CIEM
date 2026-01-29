#Requires -Version 5.1

Set-StrictMode -Version Latest

# Module root path for use by all functions
$script:ModuleRoot = $PSScriptRoot

# ============================================================================
# Auto-install Az.Accounts if not present
# ============================================================================
# Az.Accounts is required for Azure authentication and API calls (Invoke-AzRestMethod).
# Auto-installing here ensures the module works when installed from PSU Gallery,
# which does not auto-install RequiredModules dependencies.

if (-not (Get-Module -ListAvailable -Name 'Az.Accounts')) {
    Write-Verbose 'Devolutions.CIEM: Az.Accounts module not found. Installing...'
    try {
        Install-Module -Name 'Az.Accounts' -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
        Write-Verbose 'Devolutions.CIEM: Az.Accounts installed successfully.'
    }
    catch {
        throw "Az.Accounts is required but could not be installed: $($_.Exception.Message). Install manually: Install-Module Az.Accounts"
    }
}

# Load configuration into script-scoped variable
$script:configFilePath = Join-Path -Path $PSScriptRoot -ChildPath 'config.json'
if (Test-Path $script:configFilePath) {
    try {
        $script:Config = Get-Content $script:configFilePath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Failed to load config.json: $_"
        $script:Config = $null
    }
}

# Apply default configuration if not loaded
if (-not $script:Config) {
    $script:Config = [PSCustomObject]@{
        cloudProvider = 'Azure'
        azure = [PSCustomObject]@{
            authentication = [PSCustomObject]@{
                method = 'ServicePrincipalSecret'
                tenantId = $null
                servicePrincipal = [PSCustomObject]@{ clientId = $null; clientSecret = $null }
                certificate = [PSCustomObject]@{ clientId = $null; thumbprint = $null; path = $null; password = $null }
                managedIdentity = [PSCustomObject]@{ clientId = $null }
            }
            subscriptionFilter = @()
            endpoints = [PSCustomObject]@{
                graphApi = 'https://graph.microsoft.com/v1.0'
                armApi   = 'https://management.azure.com'
            }
        }
        aws = [PSCustomObject]@{
            authentication = [PSCustomObject]@{
                method = 'CurrentProfile'
                profile = $null
                region = $null
            }
            accountFilter = @()
        }
        scan = [PSCustomObject]@{
            throttleLimit    = 10
            timeoutSeconds   = 300
            continueOnError  = $true
        }
        output = [PSCustomObject]@{
            verboseLogging = $false
        }
        pam = [PSCustomObject]@{
            remediationUrl = 'https://devolutions.net/pam'
        }
    }
}

# Initialize script-scoped service variables (populated during scan)
$script:EntraService = @{}
$script:IAMService = @{}
$script:KeyVaultService = @{}

# Initialize authentication context (populated by Connect-CIEM)
$script:AuthContext = @{}
$script:StorageService = @{}

# Initialize PSU environment detection (populated on first access)
$script:PSUEnvironment = $null

# Get public, private, and check function definition files
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue)
$Checks = @(Get-ChildItem -Path $PSScriptRoot\Checks\*\*.ps1 -ErrorAction SilentlyContinue)

# Dot source the files
foreach ($import in @($Private + $Checks + $Public)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
    }
}

# Export public functions
foreach ($file in $Public) {
    Export-ModuleMember -Function $file.BaseName
}

# ============================================================================
# PSU App Function - Returns the CIEM dashboard for PowerShell Universal
# ============================================================================
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

    # Note: Get-CIEMConfigPath is a private module function (see Private/Get-CIEMConfigPath.ps1)
    # It's available at dashboard runtime because private functions are dot-sourced at module load.

    # Sample findings data for PoC demonstration
    $SampleFindings = @(
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

    # Define navigation
    $Navigation = @(
        New-UDListItem -Label 'Dashboard' -Icon (New-UDIcon -Icon 'Home') -Href '/ciem'
        New-UDListItem -Label 'Findings' -Icon (New-UDIcon -Icon 'ExclamationTriangle') -Href '/ciem/findings'
        New-UDListItem -Label 'Scan' -Icon (New-UDIcon -Icon 'Play') -Href '/ciem/scan'
        New-UDListItem -Label 'Configuration' -Icon (New-UDIcon -Icon 'Cog') -Href '/ciem/config'
        New-UDListItem -Label 'About' -Icon (New-UDIcon -Icon 'InfoCircle') -Href '/ciem/about'
    )

    # Page: Dashboard
    $DashboardPage = New-UDPage -Name 'Dashboard' -Url '/ciem' -Content {
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

    # Page: Findings
    $FindingsPage = New-UDPage -Name 'Findings' -Url '/ciem/findings' -Content {
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

    # Page: Scan
    $ScanPage = New-UDPage -Name 'Scan' -Url '/ciem/scan' -Content {
        New-UDTypography -Text 'Run CIEM Scan' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
        New-UDTypography -Text 'Configure and execute a CIEM security scan against your cloud environment' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

        New-UDCard -Title 'Scan Configuration' -Content {
            New-UDAlert -Severity 'info' -Text 'This is a PoC demonstration. In production, this would connect to actual Azure subscriptions using the Devolutions.CIEM module.'

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

            New-UDElement -Tag 'div' -Content {
                New-UDSelect -Id 'outputFormat' -Label 'Output Format' -Option {
                    New-UDSelectOption -Name 'Dashboard (Default)' -Value 'dashboard'
                    New-UDSelectOption -Name 'JSON Export' -Value 'json'
                    New-UDSelectOption -Name 'CSV Export' -Value 'csv'
                } -DefaultValue 'dashboard' -FullWidth
            } -Attributes @{ style = @{ marginBottom = '24px' } }

            New-UDStack -Direction 'row' -Spacing 2 -Content {
                New-UDButton -Text 'Start Scan' -Variant 'contained' -Color 'primary' -OnClick {
                    $Provider = (Get-UDElement -Id 'provider').value
                    Show-UDToast -Message "Scan initiated for $Provider provider..." -Duration 5000
                    Show-UDToast -Message "PoC Mode: Displaying sample findings data" -Duration 5000 -BackgroundColor '#ff9800'
                    Start-Sleep -Seconds 2
                    Invoke-UDRedirect '/ciem/findings'
                }

                New-UDButton -Text 'Test Authentication' -Variant 'outlined' -Color 'primary' -OnClick {
                    $Provider = (Get-UDElement -Id 'provider').value
                    Show-UDToast -Message "Testing $Provider authentication..." -Duration 3000
                    try {
                        switch ($Provider) {
                            'azure' {
                                $context = Get-AzContext -ErrorAction Stop
                                if ($context) {
                                    $message = "Azure authentication successful!`nAccount: $($context.Account.Id)`nSubscription: $($context.Subscription.Name)`nTenant: $($context.Tenant.Id)"
                                    Show-UDToast -Message $message -Duration 8000 -BackgroundColor '#4caf50'
                                } else {
                                    Show-UDToast -Message "Azure: Not authenticated. Run Connect-AzAccount first." -Duration 5000 -BackgroundColor '#f44336'
                                }
                            }
                            'aws' {
                                $identity = Get-STSCallerIdentity -ErrorAction Stop
                                if ($identity) {
                                    $message = "AWS authentication successful!`nAccount: $($identity.Account)`nARN: $($identity.Arn)`nUserId: $($identity.UserId)"
                                    Show-UDToast -Message $message -Duration 8000 -BackgroundColor '#4caf50'
                                } else {
                                    Show-UDToast -Message "AWS: Not authenticated. Configure AWS credentials first." -Duration 5000 -BackgroundColor '#f44336'
                                }
                            }
                            default {
                                Show-UDToast -Message "Provider '$Provider' is not yet supported for authentication testing." -Duration 5000 -BackgroundColor '#ff9800'
                            }
                        }
                    } catch {
                        $errorMsg = $_.Exception.Message
                        Show-UDToast -Message "Authentication failed for $Provider`: $errorMsg" -Duration 8000 -BackgroundColor '#f44336'
                    }
                }
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

    # Page: Configuration
    # Page: Configuration
    $ConfigPage = New-UDPage -Name 'Configuration' -Url '/ciem/config' -Content {
        $ConfigPath = Get-CIEMConfigPath
        $CurrentConfig = if ($ConfigPath -and (Test-Path $ConfigPath)) {
            Get-Content $ConfigPath -Raw | ConvertFrom-Json
        } else {
            [PSCustomObject]@{
                cloudProvider = 'Azure'
                azure = @{
                    authentication = @{
                        method = 'ServicePrincipalSecret'
                        tenantId = $null
                        servicePrincipal = @{ clientId = $null; clientSecret = $null }
                        certificate = @{ clientId = $null; thumbprint = $null; path = $null; password = $null }
                        managedIdentity = @{ clientId = $null }
                    }
                    subscriptionFilter = @()
                }
                aws = @{
                    authentication = @{ method = 'CurrentProfile'; profile = $null; region = $null }
                    accountFilter = @()
                }
                scan = @{ throttleLimit = 10; timeoutSeconds = 300; continueOnError = $true }
                output = @{ verboseLogging = $false }
                pam = @{ remediationUrl = 'https://devolutions.net/pam' }
            }
        }

        # Get PSU environment
        $envInfo = Get-PSUInstalledEnvironment

        # Get current provider (default to Azure)
        $currentProvider = if ($CurrentConfig.cloudProvider) { $CurrentConfig.cloudProvider } else { 'Azure' }

        New-UDTypography -Text 'Configuration' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
        New-UDTypography -Text 'Configure CIEM scan settings, authentication, and integrations' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

        # Deployment Environment section
        New-UDCard -Title 'Deployment Environment' -Style @{ marginBottom = '20px' } -Content {
            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                if ($envInfo.Environment -eq 'AzureWebApp') {
                    New-UDChip -Label 'Azure Web App' -Icon (New-UDIcon -Icon 'Cloud') -Style @{
                        backgroundColor = '#1976d2'
                        color = 'white'
                    }
                }
                else {
                    New-UDChip -Label 'On-Premises' -Icon (New-UDIcon -Icon 'Server') -Style @{
                        backgroundColor = '#4caf50'
                        color = 'white'
                    }
                }
                New-UDTypography -Text $envInfo.Description -Variant 'body2' -Style @{ marginLeft = '16px' }
            }
            if ($envInfo.WebsiteName) {
                New-UDTypography -Text "Site: $($envInfo.WebsiteName)" -Variant 'caption' -Style @{ color = '#666'; marginTop = '8px' }
            }
        }

        New-UDGrid -Container -Spacing 3 -Content {
            # Cloud Provider Authentication Card (full width)
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDCard -Title 'Cloud Provider Authentication' -Content {
                    # Provider Selection
                    New-UDElement -Tag 'div' -Content {
                        New-UDSelect -Id 'cloudProvider' -Label 'Cloud Provider' -Option {
                            New-UDSelectOption -Name 'Azure' -Value 'Azure'
                            New-UDSelectOption -Name 'AWS (Coming Soon)' -Value 'AWS'
                        } -DefaultValue $currentProvider -FullWidth -OnChange {
                            Sync-UDElement -Id 'authMethodContainer'
                            Sync-UDElement -Id 'authFieldsContainer'
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
                        }
                    }

                    # Warning when on-prem and ManagedIdentity might be selected
                    if (-not $envInfo.SupportsManagedIdentity) {
                        New-UDAlert -Severity 'info' -Text 'Managed Identity is only available in Azure App Service deployments.' -Dense -Style @{ marginBottom = '8px' }
                    }

                    # Dynamic fields based on selected authentication method
                    New-UDDynamic -Id 'authFieldsContainer' -Content {
                        $selectedProvider = (Get-UDElement -Id 'cloudProvider').value
                        if (-not $selectedProvider) { $selectedProvider = 'Azure' }
                        $selectedMethod = (Get-UDElement -Id 'authMethod').value
                        if (-not $selectedMethod) { $selectedMethod = 'ServicePrincipalSecret' }

                        # Check for ManagedIdentity warning
                        $envCheck = Get-PSUInstalledEnvironment
                        if ($selectedMethod -eq 'ManagedIdentity' -and -not $envCheck.SupportsManagedIdentity) {
                            New-UDAlert -Severity 'warning' -Text 'Managed Identity will not work in on-premises deployments. Please choose a different authentication method.' -Style @{ marginBottom = '16px' }
                        }

                        if ($selectedProvider -eq 'Azure') {
                            switch ($selectedMethod) {
                                'ServicePrincipalSecret' {
                                    New-UDGrid -Container -Spacing 2 -Content {
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID' -Value $CurrentConfig.azure.authentication.tenantId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azSpClientId' -Label 'Client ID (Application ID)' -Value $CurrentConfig.azure.authentication.servicePrincipal.clientId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                            New-UDTextbox -Id 'azSpClientSecret' -Label 'Client Secret' -Type 'password' -FullWidth -Placeholder 'Enter service principal client secret'
                                        }
                                    }
                                }
                                'ServicePrincipalCertificate' {
                                    New-UDGrid -Container -Spacing 2 -Content {
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID' -Value $CurrentConfig.azure.authentication.tenantId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azCertClientId' -Label 'Client ID (Application ID)' -Value $CurrentConfig.azure.authentication.certificate.clientId -FullWidth -Placeholder 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                            New-UDTypography -Text 'Provide either a certificate thumbprint (for certificates in the local store) or a certificate file path:' -Variant 'caption' -Style @{ color = '#666'; marginTop = '8px'; marginBottom = '8px' }
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azCertThumbprint' -Label 'Certificate Thumbprint' -Value $CurrentConfig.azure.authentication.certificate.thumbprint -FullWidth -Placeholder 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azCertPath' -Label 'Certificate File Path (.pfx)' -Value $CurrentConfig.azure.authentication.certificate.path -FullWidth -Placeholder '/path/to/certificate.pfx'
                                        }
                                        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                            New-UDTextbox -Id 'azCertPassword' -Label 'Certificate Password (if applicable)' -Type 'password' -FullWidth -Placeholder 'Certificate file password'
                                        }
                                    }
                                }
                                'ManagedIdentity' {
                                    New-UDAlert -Severity 'info' -Text 'System-assigned managed identity requires no additional configuration. For user-assigned identity, provide the Client ID below.' -Dense -Style @{ marginBottom = '16px' }
                                    New-UDTextbox -Id 'azMiClientId' -Label 'User-Assigned Identity Client ID (Optional)' -Value $CurrentConfig.azure.authentication.managedIdentity.clientId -FullWidth -Placeholder 'Leave empty for system-assigned identity'
                                }
                                'DeviceCode' {
                                    New-UDAlert -Severity 'info' -Text 'Device Code authentication will prompt you to visit microsoft.com/devicelogin and enter a code. Useful for environments with strict MFA policies or where browser-based login is restricted.' -Dense -Style @{ marginBottom = '16px' }
                                    New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID (Optional)' -Value $CurrentConfig.azure.authentication.tenantId -FullWidth -Placeholder 'Leave empty for default tenant'
                                }
                                'Interactive' {
                                    New-UDAlert -Severity 'info' -Text 'Interactive authentication opens a browser window for you to sign in. Supports MFA and all authentication policies.' -Dense -Style @{ marginBottom = '16px' }
                                    New-UDTextbox -Id 'azTenantId' -Label 'Tenant ID (Optional)' -Value $CurrentConfig.azure.authentication.tenantId -FullWidth -Placeholder 'Leave empty for default tenant'
                                }
                            }

                            # Subscription filter (shown for all Azure auth methods)
                            New-UDElement -Tag 'div' -Content {
                                $filterValue = if ($CurrentConfig.azure.subscriptionFilter -is [array]) { $CurrentConfig.azure.subscriptionFilter -join ', ' } else { '' }
                                New-UDTextbox -Id 'subscriptionFilter' -Label 'Subscription Filter' -Value $filterValue -FullWidth -Placeholder 'Comma-separated subscription IDs (leave empty for all)'
                            } -Attributes @{ style = @{ marginTop = '16px' } }
                        }
                        elseif ($selectedProvider -eq 'AWS') {
                            # AWS fields (disabled for now)
                            New-UDTypography -Text 'AWS authentication configuration will be available in a future release.' -Variant 'body2' -Style @{ color = '#666'; fontStyle = 'italic' }
                        }
                    }

                    # Required Permissions Button
                    New-UDElement -Tag 'div' -Content {
                        New-UDButton -Text 'Get Required Permissions' -Variant 'outlined' -Color 'primary' -OnClick {
                            try {
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
                    } -Attributes @{ style = @{ marginTop = '16px' } }
                }
            }

            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Scan Settings' -Content {
                    New-UDElement -Tag 'div' -Content { New-UDTextbox -Id 'throttleLimit' -Label 'Throttle Limit' -Value $CurrentConfig.scan.throttleLimit -FullWidth -Placeholder '1-100' -Type 'number' } -Attributes @{ style = @{ marginBottom = '16px' } }
                    New-UDElement -Tag 'div' -Content { New-UDTextbox -Id 'timeoutSeconds' -Label 'Timeout (Seconds)' -Value $CurrentConfig.scan.timeoutSeconds -FullWidth -Placeholder 'Scan timeout in seconds' -Type 'number' } -Attributes @{ style = @{ marginBottom = '16px' } }
                    New-UDElement -Tag 'div' -Content { New-UDCheckbox -Id 'continueOnError' -Label 'Continue on Error' -Checked $CurrentConfig.scan.continueOnError }
                }
            }

            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'PAM Integration' -Content {
                    New-UDElement -Tag 'div' -Content { New-UDTextbox -Id 'pamUrl' -Label 'Remediation URL' -Value $CurrentConfig.pam.remediationUrl -FullWidth -Placeholder 'URL for Devolutions PAM integration' }
                }
            }

            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                New-UDCard -Title 'Output Settings' -Content {
                    New-UDElement -Tag 'div' -Content { New-UDCheckbox -Id 'verboseLogging' -Label 'Verbose Logging' -Checked $CurrentConfig.output.verboseLogging }
                }
            }
        }

        New-UDElement -Tag 'div' -Content {
            New-UDStack -Direction 'row' -Spacing 2 -Content {
                New-UDButton -Text 'Save Configuration' -Variant 'contained' -Color 'primary' -OnClick {
                    try {
                        $provider = (Get-UDElement -Id 'cloudProvider').value
                        $authMethod = (Get-UDElement -Id 'authMethod').value

                        # Validate AWS is not selected (coming soon)
                        if ($provider -eq 'AWS') {
                            Show-UDToast -Message 'AWS support is coming soon. Please select Azure as your cloud provider.' -Duration 5000 -BackgroundColor '#ff9800'
                            return
                        }

                        # Validate ManagedIdentity is only saved when supported
                        $envInfo = Get-PSUInstalledEnvironment
                        if ($authMethod -eq 'ManagedIdentity' -and -not $envInfo.SupportsManagedIdentity) {
                            Show-UDToast -Message 'Managed Identity is not available in on-premises deployments. Please choose a different authentication method.' -Duration 8000 -BackgroundColor '#f44336'
                            return
                        }

                        $subscriptionFilterRaw = (Get-UDElement -Id 'subscriptionFilter').value
                        $throttleLimit = [int](Get-UDElement -Id 'throttleLimit').value
                        $timeoutSeconds = [int](Get-UDElement -Id 'timeoutSeconds').value
                        $continueOnError = (Get-UDElement -Id 'continueOnError').checked
                        $verboseLogging = (Get-UDElement -Id 'verboseLogging').checked
                        $pamUrl = (Get-UDElement -Id 'pamUrl').value

                        $subscriptionFilter = if ([string]::IsNullOrWhiteSpace($subscriptionFilterRaw)) { @() } else { $subscriptionFilterRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

                        $settings = @{
                            'cloudProvider' = $provider
                            'azure.authentication.method' = $authMethod
                            'azure.subscriptionFilter' = $subscriptionFilter
                            'scan.throttleLimit' = $throttleLimit
                            'scan.timeoutSeconds' = $timeoutSeconds
                            'scan.continueOnError' = $continueOnError
                            'output.verboseLogging' = $verboseLogging
                            'pam.remediationUrl' = $pamUrl
                        }

                        # Get tenant ID if available (used by multiple methods)
                        $tenantIdElement = Get-UDElement -Id 'azTenantId' -ErrorAction SilentlyContinue
                        if ($tenantIdElement) {
                            $settings['azure.authentication.tenantId'] = $tenantIdElement.value
                        }

                        # Add auth-method-specific settings
                        switch ($authMethod) {
                            'ServicePrincipalSecret' {
                                $settings['azure.authentication.servicePrincipal.clientId'] = (Get-UDElement -Id 'azSpClientId').value
                                $spClientSecret = (Get-UDElement -Id 'azSpClientSecret').value
                                if (-not [string]::IsNullOrEmpty($spClientSecret)) {
                                    $settings['azure.authentication.servicePrincipal.clientSecret'] = $spClientSecret
                                }
                            }
                            'ServicePrincipalCertificate' {
                                $settings['azure.authentication.certificate.clientId'] = (Get-UDElement -Id 'azCertClientId').value
                                $settings['azure.authentication.certificate.thumbprint'] = (Get-UDElement -Id 'azCertThumbprint').value
                                $settings['azure.authentication.certificate.path'] = (Get-UDElement -Id 'azCertPath').value
                                $certPassword = (Get-UDElement -Id 'azCertPassword').value
                                if (-not [string]::IsNullOrEmpty($certPassword)) {
                                    $settings['azure.authentication.certificate.password'] = $certPassword
                                }
                            }
                            'ManagedIdentity' {
                                $miClientId = (Get-UDElement -Id 'azMiClientId').value
                                $settings['azure.authentication.managedIdentity.clientId'] = $miClientId
                            }
                        }

                        $ConfigPath = Get-CIEMConfigPath
                        if (-not $ConfigPath) { throw 'Configuration file not found. Ensure the Devolutions.CIEM module is installed.' }
                        $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable

                        function Set-NestedValue { param([hashtable]$Hashtable, [string]$Path, $Value)
                            $parts = $Path -split '\.'; $current = $Hashtable
                            for ($i = 0; $i -lt $parts.Count - 1; $i++) { $part = $parts[$i]; if (-not $current.ContainsKey($part)) { $current[$part] = @{} }; $current = $current[$part] }
                            $current[$parts[-1]] = $Value
                        }

                        foreach ($key in $settings.Keys) { Set-NestedValue -Hashtable $config -Path $key -Value $settings[$key] }

                        $jsonContent = $config | ConvertTo-Json -Depth 10
                        Set-Content -Path $ConfigPath -Value $jsonContent -Encoding UTF8
                        Show-UDToast -Message 'Configuration saved successfully!' -Duration 5000 -BackgroundColor '#4caf50'
                    } catch {
                        Show-UDToast -Message "Failed to save configuration: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                    }
                }

                New-UDButton -Text 'Reset to Defaults' -Variant 'outlined' -Color 'secondary' -OnClick {
                    try {
                        Set-UDElement -Id 'cloudProvider' -Properties @{ value = 'Azure' }
                        Set-UDElement -Id 'authMethod' -Properties @{ value = 'ServicePrincipalSecret' }
                        Set-UDElement -Id 'subscriptionFilter' -Properties @{ value = '' }
                        Set-UDElement -Id 'throttleLimit' -Properties @{ value = '10' }
                        Set-UDElement -Id 'timeoutSeconds' -Properties @{ value = '300' }
                        Set-UDElement -Id 'continueOnError' -Properties @{ checked = $true }
                        Set-UDElement -Id 'verboseLogging' -Properties @{ checked = $false }
                        Set-UDElement -Id 'pamUrl' -Properties @{ value = 'https://devolutions.net/pam' }
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

    # Page: About
    $AboutPage = New-UDPage -Name 'About' -Url '/ciem/about' -Content {
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

    # Return the App
    New-UDApp -Title 'Devolutions CIEM' -Pages @(
        $DashboardPage
        $FindingsPage
        $ScanPage
        $ConfigPage
        $AboutPage
    ) -DefaultTheme 'Light'
}

Export-ModuleMember -Function New-DevolutionsCIEMApp
