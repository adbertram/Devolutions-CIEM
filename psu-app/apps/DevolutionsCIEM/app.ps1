#Requires -Version 7.0
<#
.SYNOPSIS
    Devolutions CIEM - Cloud Infrastructure Entitlement Management Dashboard
.DESCRIPTION
    PowerShell Universal v5 App for CIEM security findings visualization.
    This PoC demonstrates:
    - Dashboard with summary cards
    - Data grid for findings display
    - Charts for severity visualization
    - Navigation with multiple pages
.NOTES
    Version: 0.1.0
    Author: Adam Bertram
    Company: Devolutions Inc.
#>

# Sample findings data for PoC demonstration
# In production, this would come from Invoke-CIEMScan
$script:SampleFindings = @(
    [PSCustomObject]@{
        Id = 'ENTRA-001'
        CheckId = 'entra_id_mfa_not_enabled_for_users'
        Title = 'MFA Not Enabled for Users'
        Severity = 'CRITICAL'
        Status = 'FAIL'
        Provider = 'Azure'
        Service = 'Entra ID'
        ResourceId = 'user@contoso.com'
        ResourceName = 'John Doe'
        Description = 'Multi-factor authentication is not enabled for this user account'
        Remediation = 'Enable MFA for all user accounts through Azure AD > Security > MFA'
        ComplianceFramework = 'CIS Azure 1.4'
    }
    [PSCustomObject]@{
        Id = 'ENTRA-002'
        CheckId = 'entra_id_no_conditional_access_policy'
        Title = 'No Conditional Access Policies'
        Severity = 'HIGH'
        Status = 'FAIL'
        Provider = 'Azure'
        Service = 'Entra ID'
        ResourceId = 'tenant-12345'
        ResourceName = 'Contoso Tenant'
        Description = 'No conditional access policies are configured for the tenant'
        Remediation = 'Configure conditional access policies in Azure AD'
        ComplianceFramework = 'CIS Azure 1.4'
    }
    [PSCustomObject]@{
        Id = 'IAM-001'
        CheckId = 'iam_custom_role_excessive_permissions'
        Title = 'Custom Role with Excessive Permissions'
        Severity = 'HIGH'
        Status = 'FAIL'
        Provider = 'Azure'
        Service = 'IAM'
        ResourceId = '/subscriptions/sub-123/providers/Microsoft.Authorization/roleDefinitions/role-456'
        ResourceName = 'Custom Admin Role'
        Description = 'Custom role has wildcard (*) permissions'
        Remediation = 'Review and restrict permissions to least privilege'
        ComplianceFramework = 'CIS Azure 1.4'
    }
    [PSCustomObject]@{
        Id = 'KV-001'
        CheckId = 'keyvault_secrets_expiration_not_set'
        Title = 'KeyVault Secrets Without Expiration'
        Severity = 'MEDIUM'
        Status = 'FAIL'
        Provider = 'Azure'
        Service = 'KeyVault'
        ResourceId = '/subscriptions/sub-123/resourceGroups/rg-prod/providers/Microsoft.KeyVault/vaults/kv-prod'
        ResourceName = 'kv-prod'
        Description = 'Secrets in this KeyVault do not have expiration dates set'
        Remediation = 'Set expiration dates on all secrets'
        ComplianceFramework = 'CIS Azure 1.4'
    }
    [PSCustomObject]@{
        Id = 'STORAGE-001'
        CheckId = 'storage_blob_public_access_enabled'
        Title = 'Blob Public Access Enabled'
        Severity = 'CRITICAL'
        Status = 'FAIL'
        Provider = 'Azure'
        Service = 'Storage'
        ResourceId = '/subscriptions/sub-123/resourceGroups/rg-prod/providers/Microsoft.Storage/storageAccounts/stprod123'
        ResourceName = 'stprod123'
        Description = 'Storage account allows public blob access'
        Remediation = 'Disable public blob access on the storage account'
        ComplianceFramework = 'CIS Azure 1.4'
    }
    [PSCustomObject]@{
        Id = 'ENTRA-003'
        CheckId = 'entra_id_security_defaults_disabled'
        Title = 'Security Defaults Disabled'
        Severity = 'MEDIUM'
        Status = 'FAIL'
        Provider = 'Azure'
        Service = 'Entra ID'
        ResourceId = 'tenant-12345'
        ResourceName = 'Contoso Tenant'
        Description = 'Security defaults are disabled and no conditional access policies exist'
        Remediation = 'Enable security defaults or configure conditional access'
        ComplianceFramework = 'CIS Azure 1.4'
    }
    [PSCustomObject]@{
        Id = 'KV-002'
        CheckId = 'keyvault_rbac_enabled'
        Title = 'KeyVault RBAC Enabled'
        Severity = 'INFO'
        Status = 'PASS'
        Provider = 'Azure'
        Service = 'KeyVault'
        ResourceId = '/subscriptions/sub-123/resourceGroups/rg-prod/providers/Microsoft.KeyVault/vaults/kv-secure'
        ResourceName = 'kv-secure'
        Description = 'RBAC is properly enabled for KeyVault access'
        Remediation = 'N/A - Check passed'
        ComplianceFramework = 'CIS Azure 1.4'
    }
    [PSCustomObject]@{
        Id = 'STORAGE-002'
        CheckId = 'storage_encryption_at_rest'
        Title = 'Encryption at Rest Enabled'
        Severity = 'INFO'
        Status = 'PASS'
        Provider = 'Azure'
        Service = 'Storage'
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

# Theme configuration - Devolutions brand colors
$Theme = @{
    palette = @{
        primary = @{
            main = '#1976d2'
        }
        secondary = @{
            main = '#dc004e'
        }
    }
}

# ============================================================================
# Page: Dashboard (Home)
# ============================================================================
$DashboardPage = New-UDPage -Name 'Dashboard' -Url '/ciem' -Content {
    # Get findings data
    $Findings = $script:SampleFindings
    $FailedFindings = $Findings | Where-Object { $_.Status -eq 'FAIL' }
    $PassedFindings = $Findings | Where-Object { $_.Status -eq 'PASS' }

    # Severity counts
    $CriticalCount = ($FailedFindings | Where-Object { $_.Severity -eq 'CRITICAL' }).Count
    $HighCount = ($FailedFindings | Where-Object { $_.Severity -eq 'HIGH' }).Count
    $MediumCount = ($FailedFindings | Where-Object { $_.Severity -eq 'MEDIUM' }).Count
    $LowCount = ($FailedFindings | Where-Object { $_.Severity -eq 'LOW' }).Count

    # Header
    New-UDTypography -Text 'Devolutions CIEM Dashboard' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
    New-UDTypography -Text 'Cloud Infrastructure Entitlement Management - Security Findings Overview' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

    # Summary Cards Row
    New-UDGrid -Container -Content {
        # Total Findings Card
        New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
            New-UDCard -Title 'Total Findings' -Content {
                New-UDTypography -Text $Findings.Count -Variant 'h3' -Style @{ color = '#1976d2'; textAlign = 'center' }
            } -Style @{ textAlign = 'center' }
        }

        # Failed Findings Card
        New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
            New-UDCard -Title 'Failed Checks' -Content {
                New-UDTypography -Text $FailedFindings.Count -Variant 'h3' -Style @{ color = '#f44336'; textAlign = 'center' }
            } -Style @{ textAlign = 'center' }
        }

        # Passed Findings Card
        New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
            New-UDCard -Title 'Passed Checks' -Content {
                New-UDTypography -Text $PassedFindings.Count -Variant 'h3' -Style @{ color = '#4caf50'; textAlign = 'center' }
            } -Style @{ textAlign = 'center' }
        }

        # Critical Issues Card
        New-UDGrid -Item -ExtraSmallSize 12 -SmallSize 6 -MediumSize 3 -Content {
            New-UDCard -Title 'Critical Issues' -Content {
                New-UDTypography -Text $CriticalCount -Variant 'h3' -Style @{ color = '#9c27b0'; textAlign = 'center' }
            } -Style @{ textAlign = 'center' }
        }
    }

    # Charts Row
    New-UDGrid -Container -Content {
        # Severity Distribution Pie Chart
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

        # Service Distribution Bar Chart
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDCard -Title 'Findings by Service' -Content {
                $ServiceData = $FailedFindings | Group-Object -Property Service | ForEach-Object {
                    @{ Name = $_.Name; Count = $_.Count }
                }

                if ($ServiceData.Count -gt 0) {
                    New-UDChartJS -Type 'bar' -Data $ServiceData -DataProperty Count -LabelProperty Name -BackgroundColor '#1976d2'
                } else {
                    New-UDTypography -Text 'No failed findings' -Style @{ textAlign = 'center'; padding = '40px' }
                }
            }
        }
    }

    # Recent Critical Findings
    New-UDCard -Title 'Recent Critical & High Findings' -Style @{ marginTop = '20px' } -Content {
        $CriticalHighFindings = $FailedFindings | Where-Object { $_.Severity -in @('CRITICAL', 'HIGH') } | Select-Object -First 5

        if ($CriticalHighFindings.Count -gt 0) {
            New-UDTable -Data $CriticalHighFindings -Columns @(
                New-UDTableColumn -Property 'Id' -Title 'ID'
                New-UDTableColumn -Property 'Title' -Title 'Finding'
                New-UDTableColumn -Property 'Severity' -Title 'Severity' -Render {
                    $color = switch ($EventData.Severity) {
                        'CRITICAL' { '#9c27b0' }
                        'HIGH' { '#f44336' }
                        default { '#666' }
                    }
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

# ============================================================================
# Page: Findings (Detailed View)
# ============================================================================
$FindingsPage = New-UDPage -Name 'Findings' -Url '/ciem/findings' -Content {
    New-UDTypography -Text 'Security Findings' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
    New-UDTypography -Text 'Detailed view of all CIEM security findings' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

    New-UDDataGrid -LoadRows {
        $Data = $script:SampleFindings | ForEach-Object {
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
        $Data | Out-UDDataGridData -Context $EventData -TotalRows $Data.Count
    } -Columns @(
        New-UDDataGridColumn -Field 'id' -HeaderName 'ID' -Width 120
        New-UDDataGridColumn -Field 'title' -HeaderName 'Finding' -Flex 1
        New-UDDataGridColumn -Field 'severity' -HeaderName 'Severity' -Width 120 -Render {
            $color = switch ($EventData.severity) {
                'CRITICAL' { '#9c27b0' }
                'HIGH' { '#f44336' }
                'MEDIUM' { '#ff9800' }
                'LOW' { '#2196f3' }
                'INFO' { '#4caf50' }
                default { '#666' }
            }
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
                # In production: Invoke-UDRedirect "https://devolutions.net/pam"
            }
        }
    }
} -Navigation $Navigation -NavigationLayout permanent

# ============================================================================
# Page: Scan Configuration
# ============================================================================
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

        # Action buttons
        New-UDStack -Direction 'row' -Spacing 2 -Content {
            New-UDButton -Text 'Start Scan' -Variant 'contained' -Color 'primary' -OnClick {
                $Provider = (Get-UDElement -Id 'provider').value
                Show-UDToast -Message "Scan initiated for $Provider provider..." -Duration 5000
                Show-UDToast -Message "PoC Mode: Displaying sample findings data" -Duration 5000 -BackgroundColor '#ff9800'

                # In production, this would call:
                # $results = Invoke-CIEMScan -Provider $Provider -SubscriptionId $subscriptionId

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

    # Scan History (placeholder)
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

# ============================================================================
# Page: About
# ============================================================================
$AboutPage = New-UDPage -Name 'About' -Url '/ciem/about' -Content {
    New-UDTypography -Text 'About Devolutions CIEM' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }

    New-UDCard -Title 'Cloud Infrastructure Entitlement Management' -Content {
        New-UDTypography -Text @"
Devolutions CIEM is a security scanning solution that helps identify identity and access management issues across your cloud infrastructure.
"@ -Variant 'body1' -Style @{ marginBottom = '20px' }

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
            @{ Property = 'Module Version'; Value = '0.1.0-alpha' }
            @{ Property = 'PSU App Version'; Value = '0.1.0' }
            @{ Property = 'PowerShell Universal'; Value = '5.4.4' }
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

# ============================================================================
# Page: Configuration
# ============================================================================
$ConfigPage = New-UDPage -Name 'Configuration' -Url '/ciem/config' -Content {
    # Load current configuration
    $ModuleRoot = Join-Path $PSScriptRoot '..' '..' '..' 'Devolutions.CIEM'
    $ConfigPath = Join-Path $ModuleRoot 'config.json'
    $CurrentConfig = if (Test-Path $ConfigPath) {
        Get-Content $ConfigPath -Raw | ConvertFrom-Json
    } else {
        # Defaults if config doesn't exist
        [PSCustomObject]@{
            azure = @{
                authentication = @{
                    method = 'CurrentContext'
                    servicePrincipal = @{ tenantId = $null; clientId = $null; clientSecret = $null }
                }
                subscriptionFilter = @()
            }
            scan = @{ throttleLimit = 10; timeoutSeconds = 300; continueOnError = $true }
            output = @{ verboseLogging = $false }
            pam = @{ remediationUrl = 'https://devolutions.net/pam' }
        }
    }

    New-UDTypography -Text 'Configuration' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
    New-UDTypography -Text 'Configure CIEM scan settings, authentication, and integrations' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

    New-UDGrid -Container -Spacing 3 -Content {
        # Azure Authentication Card
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDCard -Title 'Azure Authentication' -Content {
                New-UDElement -Tag 'div' -Content {
                    New-UDSelect -Id 'authMethod' -Label 'Authentication Method' -Option {
                        New-UDSelectOption -Name 'Current Context (Az PowerShell)' -Value 'CurrentContext'
                        New-UDSelectOption -Name 'Service Principal' -Value 'ServicePrincipal'
                        New-UDSelectOption -Name 'Managed Identity' -Value 'ManagedIdentity'
                        New-UDSelectOption -Name 'Interactive Browser' -Value 'Interactive'
                    } -DefaultValue $CurrentConfig.azure.authentication.method -FullWidth -OnChange {
                        Sync-UDElement -Id 'spFieldsContainer'
                    }
                } -Attributes @{ style = @{ marginBottom = '16px' } }

                # Service Principal fields - conditionally visible
                New-UDDynamic -Id 'spFieldsContainer' -Content {
                    $selectedMethod = (Get-UDElement -Id 'authMethod').value
                    if ($selectedMethod -eq 'ServicePrincipal') {
                        New-UDElement -Tag 'div' -Content {
                            New-UDTextbox -Id 'spTenantId' -Label 'Tenant ID' -Value $CurrentConfig.azure.authentication.servicePrincipal.tenantId -FullWidth -Placeholder 'Enter Azure AD Tenant ID'
                        } -Attributes @{ style = @{ marginBottom = '16px' } }

                        New-UDElement -Tag 'div' -Content {
                            New-UDTextbox -Id 'spClientId' -Label 'Client ID (App ID)' -Value $CurrentConfig.azure.authentication.servicePrincipal.clientId -FullWidth -Placeholder 'Enter Service Principal Client ID'
                        } -Attributes @{ style = @{ marginBottom = '16px' } }

                        New-UDElement -Tag 'div' -Content {
                            New-UDTextbox -Id 'spClientSecret' -Label 'Client Secret' -Type 'password' -FullWidth -Placeholder 'Enter Service Principal Secret'
                        } -Attributes @{ style = @{ marginBottom = '16px' } }
                    }
                }

                New-UDElement -Tag 'div' -Content {
                    $filterValue = if ($CurrentConfig.azure.subscriptionFilter -is [array]) {
                        $CurrentConfig.azure.subscriptionFilter -join ', '
                    } else { '' }
                    New-UDTextbox -Id 'subscriptionFilter' -Label 'Subscription Filter' -Value $filterValue -FullWidth -Placeholder 'Comma-separated subscription IDs (leave empty for all)'
                } -Attributes @{ style = @{ marginTop = '16px' } }
            }
        }

        # Scan Settings Card
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDCard -Title 'Scan Settings' -Content {
                New-UDElement -Tag 'div' -Content {
                    New-UDTextbox -Id 'throttleLimit' -Label 'Throttle Limit' -Value $CurrentConfig.scan.throttleLimit -FullWidth -Placeholder '1-100' -Type 'number'
                } -Attributes @{ style = @{ marginBottom = '16px' } }

                New-UDElement -Tag 'div' -Content {
                    New-UDTextbox -Id 'timeoutSeconds' -Label 'Timeout (Seconds)' -Value $CurrentConfig.scan.timeoutSeconds -FullWidth -Placeholder 'Scan timeout in seconds' -Type 'number'
                } -Attributes @{ style = @{ marginBottom = '16px' } }

                New-UDElement -Tag 'div' -Content {
                    New-UDCheckbox -Id 'continueOnError' -Label 'Continue on Error' -Checked $CurrentConfig.scan.continueOnError
                }
            }
        }

        # PAM Integration Card
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDCard -Title 'PAM Integration' -Content {
                New-UDElement -Tag 'div' -Content {
                    New-UDTextbox -Id 'pamUrl' -Label 'Remediation URL' -Value $CurrentConfig.pam.remediationUrl -FullWidth -Placeholder 'URL for Devolutions PAM integration'
                }
            }
        }

        # Output Settings Card
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDCard -Title 'Output Settings' -Content {
                New-UDElement -Tag 'div' -Content {
                    New-UDCheckbox -Id 'verboseLogging' -Label 'Verbose Logging' -Checked $CurrentConfig.output.verboseLogging
                }
            }
        }
    }

    # Action Buttons
    New-UDElement -Tag 'div' -Content {
        New-UDStack -Direction 'row' -Spacing 2 -Content {
            New-UDButton -Text 'Save Configuration' -Variant 'contained' -Color 'primary' -OnClick {
                try {
                    # Collect all form values
                    $authMethod = (Get-UDElement -Id 'authMethod').value
                    $subscriptionFilterRaw = (Get-UDElement -Id 'subscriptionFilter').value
                    $throttleLimit = [int](Get-UDElement -Id 'throttleLimit').value
                    $timeoutSeconds = [int](Get-UDElement -Id 'timeoutSeconds').value
                    $continueOnError = (Get-UDElement -Id 'continueOnError').checked
                    $verboseLogging = (Get-UDElement -Id 'verboseLogging').checked
                    $pamUrl = (Get-UDElement -Id 'pamUrl').value

                    # Parse subscription filter
                    $subscriptionFilter = if ([string]::IsNullOrWhiteSpace($subscriptionFilterRaw)) {
                        @()
                    } else {
                        $subscriptionFilterRaw -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                    }

                    # Build settings hashtable
                    $settings = @{
                        'azure.authentication.method' = $authMethod
                        'azure.subscriptionFilter' = $subscriptionFilter
                        'scan.throttleLimit' = $throttleLimit
                        'scan.timeoutSeconds' = $timeoutSeconds
                        'scan.continueOnError' = $continueOnError
                        'output.verboseLogging' = $verboseLogging
                        'pam.remediationUrl' = $pamUrl
                    }

                    # Add service principal settings if applicable
                    if ($authMethod -eq 'ServicePrincipal') {
                        $spTenantId = (Get-UDElement -Id 'spTenantId').value
                        $spClientId = (Get-UDElement -Id 'spClientId').value
                        $spClientSecret = (Get-UDElement -Id 'spClientSecret').value

                        $settings['azure.authentication.servicePrincipal.tenantId'] = $spTenantId
                        $settings['azure.authentication.servicePrincipal.clientId'] = $spClientId
                        if (-not [string]::IsNullOrEmpty($spClientSecret)) {
                            $settings['azure.authentication.servicePrincipal.clientSecret'] = $spClientSecret
                        }
                    }

                    # Read existing config
                    $ModuleRoot = Join-Path $PSScriptRoot '..' '..' '..' 'Devolutions.CIEM'
                    $ConfigPath = Join-Path $ModuleRoot 'config.json'
                    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json -AsHashtable

                    # Helper function to set nested values
                    function Set-NestedValue {
                        param([hashtable]$Hashtable, [string]$Path, $Value)
                        $parts = $Path -split '\.'
                        $current = $Hashtable
                        for ($i = 0; $i -lt $parts.Count - 1; $i++) {
                            $part = $parts[$i]
                            if (-not $current.ContainsKey($part)) { $current[$part] = @{} }
                            $current = $current[$part]
                        }
                        $current[$parts[-1]] = $Value
                    }

                    # Apply settings
                    foreach ($key in $settings.Keys) {
                        Set-NestedValue -Hashtable $config -Path $key -Value $settings[$key]
                    }

                    # Save config
                    $jsonContent = $config | ConvertTo-Json -Depth 10
                    Set-Content -Path $ConfigPath -Value $jsonContent -Encoding UTF8

                    Show-UDToast -Message 'Configuration saved successfully!' -Duration 5000 -BackgroundColor '#4caf50'
                } catch {
                    Show-UDToast -Message "Failed to save configuration: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                }
            }

            New-UDButton -Text 'Reset to Defaults' -Variant 'outlined' -Color 'secondary' -OnClick {
                try {
                    # Set form elements to default values
                    Set-UDElement -Id 'authMethod' -Properties @{ value = 'CurrentContext' }
                    Set-UDElement -Id 'subscriptionFilter' -Properties @{ value = '' }
                    Set-UDElement -Id 'throttleLimit' -Properties @{ value = '10' }
                    Set-UDElement -Id 'timeoutSeconds' -Properties @{ value = '300' }
                    Set-UDElement -Id 'continueOnError' -Properties @{ checked = $true }
                    Set-UDElement -Id 'verboseLogging' -Properties @{ checked = $false }
                    Set-UDElement -Id 'pamUrl' -Properties @{ value = 'https://devolutions.net/pam' }

                    # Refresh service principal fields visibility
                    Sync-UDElement -Id 'spFieldsContainer'

                    Show-UDToast -Message 'Form reset to default values. Click Save to apply.' -Duration 5000 -BackgroundColor '#ff9800'
                } catch {
                    Show-UDToast -Message "Failed to reset: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                }
            }
        }
    } -Attributes @{ style = @{ marginTop = '24px' } }
} -Navigation $Navigation -NavigationLayout permanent

# ============================================================================
# Create the App
# ============================================================================
New-UDApp -Title 'Devolutions CIEM' -Pages @(
    $DashboardPage
    $FindingsPage
    $ScanPage
    $ConfigPage
    $AboutPage
) -DefaultTheme 'Light'
