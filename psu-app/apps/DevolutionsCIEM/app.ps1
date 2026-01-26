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

        New-UDForm -Content {
            New-UDSelect -Id 'provider' -Label 'Cloud Provider' -Option {
                New-UDSelectOption -Name 'Azure' -Value 'azure'
                New-UDSelectOption -Name 'AWS (Coming Soon)' -Value 'aws' -Disabled
            } -DefaultValue 'azure' -FullWidth

            New-UDTextbox -Id 'subscriptionId' -Label 'Subscription ID (Optional)' -Placeholder 'Leave empty to scan all accessible subscriptions' -FullWidth

            New-UDCheckbox -Id 'includePassedChecks' -Label 'Include Passed Checks in Results' -Checked $true

            New-UDSelect -Id 'outputFormat' -Label 'Output Format' -Option {
                New-UDSelectOption -Name 'Dashboard (Default)' -Value 'dashboard'
                New-UDSelectOption -Name 'JSON Export' -Value 'json'
                New-UDSelectOption -Name 'CSV Export' -Value 'csv'
            } -DefaultValue 'dashboard' -FullWidth
        } -OnSubmit {
            Show-UDToast -Message "Scan initiated for $($EventData.provider) provider..." -Duration 5000
            Show-UDToast -Message "PoC Mode: Displaying sample findings data" -Duration 5000 -BackgroundColor '#ff9800'

            # In production, this would call:
            # $results = Invoke-CIEMScan -Provider $EventData.provider -SubscriptionId $EventData.subscriptionId

            Start-Sleep -Seconds 2
            Invoke-UDRedirect '/ciem/findings'
        } -SubmitText 'Start Scan'
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
# Create the App
# ============================================================================
New-UDApp -Title 'Devolutions CIEM' -Pages @(
    $DashboardPage
    $FindingsPage
    $ScanPage
    $AboutPage
) -DefaultTheme 'Light'
