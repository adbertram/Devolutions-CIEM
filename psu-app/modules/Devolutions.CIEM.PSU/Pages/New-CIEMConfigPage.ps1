function New-CIEMConfigPage {
    <#
    .SYNOPSIS
        Creates the Configuration page for cloud provider authentication settings.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Configuration' -Url '/ciem/config' -Content {
        # Load configuration from PSU cache (or defaults if first run)
        $CurrentConfig = Devolutions.CIEM\Get-CIEMConfig

        # Get PSU environment
        $envInfo = Devolutions.CIEM\Get-PSUInstalledEnvironment

        New-UDTypography -Text 'Configuration' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
        New-UDTypography -Text 'Configure cloud provider authentication for CIEM security scans' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

        # Get available providers from database
        $providers = @(Devolutions.CIEM\Get-CIEMProvider)
        $currentProvider = ($providers | Where-Object Enabled | Select-Object -First 1).Name
        if (-not $currentProvider) { $currentProvider = 'Azure' }

        New-UDElement -Tag 'style' -Content {
@'
body:has(#cloudProvider[value="Azure"]) #scheduledDiscoveryWrapper { display: block !important; }
body:has(#cloudProvider[value="AWS"]) #scheduledDiscoveryWrapper { display: none !important; }
'@
        }

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

            New-UDForm -Id 'ciemConfigForm' -SubmitText 'Save Configuration' -ButtonVariant 'contained' -Children {
            # Provider Selection
            New-UDElement -Tag 'div' -Content {
                New-UDSelect -Id 'cloudProvider' -Label 'Cloud Provider' -Option {
                    foreach ($p in $providers) {
                        New-UDSelectOption -Name $p.Name -Value $p.Name
                    }
                } -DefaultValue $currentProvider -FullWidth -OnChange {
                    # Only sync authMethodContainer - it will sync authFieldsContainer after rendering
                    Sync-UDElement -Id 'authMethodContainer'
                    Sync-UDElement -Id 'scheduledDiscoveryContainer'
                }
            } -Attributes @{ style = @{ marginBottom = '16px' } }

            # Dynamic Authentication Method dropdown based on provider
            New-UDDynamic -Id 'authMethodContainer' -Content {
                $selectedProvider = (Get-UDElement -Id 'cloudProvider').value
                if (-not $selectedProvider) { $selectedProvider = 'Azure' }

                # Get available auth methods from database
                $authMethods = @(Devolutions.CIEM\Get-CIEMProviderAuthMethod -Provider $selectedProvider)
                $uiMethod = (Get-UDElement -Id 'authMethod').value

                # Determine current default from active profile (Azure) or first method
                $defaultMethod = if ($uiMethod -and $uiMethod -in @($authMethods.Method)) {
                    $uiMethod
                } elseif ($selectedProvider -eq 'Azure') {
                    $azProfile = @(Devolutions.CIEM\Get-CIEMAzureAuthenticationProfile -ProviderId 'azure' -IsActive $true) | Select-Object -First 1
                    if ($azProfile.Method) { $azProfile.Method } else { $authMethods[0].Method }
                } else {
                    $authMethods[0].Method
                }

                New-UDElement -Tag 'div' -Content {
                    New-UDSelect -Id 'authMethod' -Label 'Authentication Method' -Option {
                        foreach ($m in $authMethods) {
                            New-UDSelectOption -Name $m.DisplayName -Value $m.Method
                        }
                    } -DefaultValue $defaultMethod -FullWidth -OnChange { Sync-UDElement -Id 'authFieldsContainer' }
                } -Attributes @{ style = @{ marginBottom = '8px' } }

                New-UDTypography -Text 'Select the authentication method that matches your environment and security requirements.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '16px' }

                Sync-UDElement -Id 'authFieldsContainer'
            }

            # Dynamic fields based on selected authentication method
            New-UDDynamic -Id 'authFieldsContainer' -Content {
                # Read from UI if available (after user interaction), otherwise fall back to config
                $uiProvider = (Get-UDElement -Id 'cloudProvider').value
                $uiMethod = (Get-UDElement -Id 'authMethod').value
                $defaultProvider = (Devolutions.CIEM\Get-CIEMProvider | Where-Object Enabled | Select-Object -First 1).Name
                $selectedProvider = if ($uiProvider) { $uiProvider } elseif ($defaultProvider) { $defaultProvider } else { 'Azure' }

                # Read auth method from profile for Azure, default for others
                $azProfileForFields = if ($selectedProvider -eq 'Azure') {
                    @(Devolutions.CIEM\Get-CIEMAzureAuthenticationProfile -ProviderId 'azure' -IsActive $true) | Select-Object -First 1
                }
                $selectedMethod = if ($uiMethod) { $uiMethod } elseif ($azProfileForFields.Method) { $azProfileForFields.Method } else { 'ServicePrincipalSecret' }

                # Check for ManagedIdentity warning
                $envCheck = Devolutions.CIEM\Get-PSUInstalledEnvironment
                if ($selectedMethod -eq 'ManagedIdentity' -and -not $envCheck.SupportsManagedIdentity) {
                    New-UDAlert -Severity 'warning' -Text 'Managed Identity will not work in on-premises deployments. Please choose a different authentication method.' -Style @{ marginBottom = '16px' }
                }

                if ($selectedProvider -eq 'Azure') {
                    # Load credentials from auth profile and PSU secrets
                    $credProfileId = $azProfileForFields.Id
                    $storedCreds = @{
                        TenantId = $azProfileForFields.TenantId
                        ClientId = $azProfileForFields.ClientId
                        ClientSecretExists = $false
                        CertPfxExists = $false
                        CertPasswordExists = $false
                        ManagedIdentityClientId = $azProfileForFields.ManagedIdentityClientId
                    }
                    if ($credProfileId) {
                        $storedCreds.ClientSecretExists = Test-Path "Secret:CIEM_Azure_${credProfileId}_ClientSecret"
                        $storedCreds.CertPfxExists = Test-Path "Secret:CIEM_Azure_${credProfileId}_CertPfx"
                        $storedCreds.CertPasswordExists = Test-Path "Secret:CIEM_Azure_${credProfileId}_CertPassword"
                    }

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
                                    New-UDElement -Tag 'div' -Content {
                                        $certExists = $storedCreds.CertPfxExists
                                        if ($certExists) {
                                            New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                                                New-UDIcon -Icon 'CheckCircle' -Size 'sm' -Style @{ color = '#4caf50' }
                                                New-UDTypography -Text 'Certificate file is stored. Upload a new file to replace it.' -Variant 'caption' -Style @{ color = '#666' }
                                            }
                                        } else {
                                            New-UDTypography -Text 'Upload a PFX certificate file for service principal authentication.' -Variant 'caption' -Style @{ color = '#666' }
                                        }
                                    } -Attributes @{ style = @{ marginTop = '8px'; marginBottom = '8px' } }
                                }
                                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                    New-UDUpload -Id 'azCertPfxUpload' -Text 'Upload Certificate' -Accept '.pfx,.p12' -Icon (New-UDIcon -Icon 'Upload') -Variant 'outlined' -OnUpload {
                                        $upload = $Body | ConvertFrom-Json -ErrorAction Stop
                                        if ([string]::IsNullOrWhiteSpace([string]$upload.data)) {
                                            throw 'Certificate upload did not include file data.'
                                        }
                                        if ([string]::IsNullOrWhiteSpace([string]$upload.name)) {
                                            throw 'Certificate upload did not include a file name.'
                                        }

                                        $Page:UploadedCertBase64 = [string]$upload.data
                                        $Page:UploadedCertFileName = [string]$upload.name
                                        Sync-UDElement -Id 'azCertFileDisplay'
                                    }
                                    # Pill showing selected file with remove button
                                    New-UDDynamic -Id 'azCertFileDisplay' -Content {
                                        if ($Page:UploadedCertFileName) {
                                            New-UDChip -Label $Page:UploadedCertFileName -Icon (New-UDIcon -Icon 'File') -OnDelete {
                                                $Page:UploadedCertBase64 = $null
                                                $Page:UploadedCertFileName = $null
                                                Sync-UDElement -Id 'azCertFileDisplay'
                                            } -Style @{ marginTop = '8px' }
                                        }
                                    }
                                }
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    $certPwdPlaceholder = if ($storedCreds.CertPasswordExists) { 'Password is stored. Leave empty to keep existing.' } else { 'Certificate file password (leave empty if none)' }
                                    $certPwdValue = if ($storedCreds.CertPasswordExists) { '********' } else { '' }
                                    New-UDTextbox -Id 'azCertPassword' -Label 'Certificate Password' -Type 'password' -Value $certPwdValue -FullWidth -Placeholder $certPwdPlaceholder
                                }
                            }
                        }
                        'ManagedIdentity' {
                            # No configuration needed - system-assigned managed identity is used automatically
                        }
                    }
                }
                elseif ($selectedProvider -eq 'AWS') {
                    $awsAccessKeyExists = Test-Path 'Secret:CIEM_AWS_AccessKeyId'
                    $awsSecretKeyExists = Test-Path 'Secret:CIEM_AWS_SecretAccessKey'

                    switch ($selectedMethod) {
                        'CurrentProfile' {
                            New-UDAlert -Severity 'info' -Text 'Uses your existing AWS CLI configuration (~/.aws/credentials). Optionally specify a named profile and region.' -Dense -Style @{ marginBottom = '16px' }
                            New-UDGrid -Container -Spacing 2 -Content {
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    New-UDTextbox -Id 'awsProfile' -Label 'AWS Profile (Optional)' -FullWidth -Placeholder 'default'
                                }
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    New-UDTextbox -Id 'awsRegion' -Label 'AWS Region (Optional)' -FullWidth -Placeholder 'us-east-1'
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
                                    New-UDTextbox -Id 'awsRegion' -Label 'AWS Region (Optional)' -FullWidth -Placeholder 'us-east-1'
                                }
                            }
                        }
                    }
                }
            }
            } -OnSubmit {
                try {

                    Devolutions.CIEM\Write-CIEMLog -Message "Save Configuration button clicked" -Severity INFO -Component 'PSU-ConfigPage'

                    $provider = [string]$EventData.cloudProvider
                    $authMethod = [string]$EventData.authMethod
                    Devolutions.CIEM\Write-CIEMLog -Message "Form values - Provider: $provider, AuthMethod: $authMethod" -Severity DEBUG -Component 'PSU-ConfigPage'

                    # Validate ManagedIdentity is only saved when supported
                    $envInfo = Devolutions.CIEM\Get-PSUInstalledEnvironment
                    Devolutions.CIEM\Write-CIEMLog -Message "Environment: $($envInfo.Environment), SupportsManagedIdentity: $($envInfo.SupportsManagedIdentity)" -Severity DEBUG -Component 'PSU-ConfigPage'
                    if ($authMethod -eq 'ManagedIdentity' -and -not $envInfo.SupportsManagedIdentity) {
                        Devolutions.CIEM\Write-CIEMLog -Message "ManagedIdentity selected but not supported in this environment" -Severity WARNING -Component 'PSU-ConfigPage'
                        Show-UDToast -Message 'Managed Identity is not available in on-premises deployments.' -Duration 8000 -BackgroundColor '#f44336'
                        return
                    }

                    # Collect form values
                    Devolutions.CIEM\Write-CIEMLog -Message "Provider: $provider, AuthMethod: $authMethod" -Severity DEBUG -Component 'PSU-ConfigPage'

                    # Track save params for change detection
                    $saveParams = @{ Provider = $provider; Method = $authMethod }

                    if ($provider -eq 'Azure') {
                        $tenantId = [string]$EventData.azTenantId
                        $saveParams['TenantId'] = $tenantId

                        $activeProfile = @(Devolutions.CIEM\Get-CIEMAzureAuthenticationProfile -IsActive $true) | Select-Object -First 1
                        $profileId = if ($activeProfile.Id) { $activeProfile.Id } else { [guid]::NewGuid().ToString() }
                        $secretName = $null
                        $secretType = $null
                        $clientId = $null

                        switch ($authMethod) {
                            'ServicePrincipalSecret' {
                                $clientId = [string]$EventData.azSpClientId
                                $saveParams['ClientId'] = $clientId
                                $clientSecret = [string]$EventData.azSpClientSecret
                                $secretName = "CIEM_Azure_${profileId}_ClientSecret"
                                $secretType = 'ClientSecret'
                                if ($clientSecret -and $clientSecret -ne '********') {
                                    $saveParams['ClientSecret'] = $clientSecret
                                    Devolutions.CIEM\Set-CIEMSecret $secretName $clientSecret
                                    Devolutions.CIEM\Write-CIEMLog -Message "Saved secret to $secretName" -Severity DEBUG -Component 'PSU-ConfigPage'
                                }
                            }
                            'ServicePrincipalCertificate' {
                                $clientId = [string]$EventData.azCertClientId
                                $saveParams['ClientId'] = $clientId
                                $secretName = "CIEM_Azure_${profileId}_CertPfx"
                                $secretType = 'CertPfx'

                                # Store uploaded PFX certificate (base64) in PSU vault
                                if ($Page:UploadedCertBase64) {
                                    $saveParams['CertUploaded'] = $true
                                    Devolutions.CIEM\Set-CIEMSecret $secretName $Page:UploadedCertBase64
                                    Devolutions.CIEM\Write-CIEMLog -Message "Saved PFX certificate to $secretName (file: $($Page:UploadedCertFileName))" -Severity INFO -Component 'PSU-ConfigPage'
                                    $Page:UploadedCertBase64 = $null
                                    $Page:UploadedCertFileName = $null
                                }

                                # Store certificate password if provided
                                $certPassword = [string]$EventData.azCertPassword
                                if ($certPassword -and $certPassword -ne '********') {
                                    Devolutions.CIEM\Set-CIEMSecret "CIEM_Azure_${profileId}_CertPassword" $certPassword
                                    Devolutions.CIEM\Write-CIEMLog -Message "Saved certificate password" -Severity DEBUG -Component 'PSU-ConfigPage'
                                }
                            }
                            'ManagedIdentity' {
                                # No secrets needed
                            }
                        }

                        # Save auth profile
                        Devolutions.CIEM\Write-CIEMLog -Message "Saving Azure auth profile ($authMethod)..." -Severity INFO -Component 'PSU-ConfigPage'
                        Devolutions.CIEM\Save-CIEMAzureAuthenticationProfile -Id $profileId -ProviderId 'azure' -Name 'Default' -Method $authMethod -IsActive $true -TenantId $tenantId -ClientId $clientId -SecretName $secretName -SecretType $secretType

                        # Activate the profile
                        Devolutions.CIEM\Set-CIEMAzureAuthenticationProfileActive -Id $profileId
                        Devolutions.CIEM\Write-CIEMLog -Message "Azure auth profile saved and activated" -Severity INFO -Component 'PSU-ConfigPage'

                        # Enable the provider
                        Devolutions.CIEM\Update-CIEMProvider -Name 'Azure' -Enabled $true | Out-Null
                    }
                    elseif ($provider -eq 'AWS') {
                        $region = [string](Get-UDElement -Id 'awsRegion').value
                        $saveParams['Region'] = $region
                        $profile = $null

                        switch ($authMethod) {
                            'CurrentProfile' {
                                $profile = [string](Get-UDElement -Id 'awsProfile').value
                                $saveParams['Profile'] = $profile
                            }
                            'AccessKey' {
                                $accessKeyId = [string](Get-UDElement -Id 'awsAccessKeyId').value
                                $secretAccessKey = [string](Get-UDElement -Id 'awsSecretAccessKey').value
                                if ($accessKeyId -and $accessKeyId -ne '********') {
                                    $saveParams['AccessKeyId'] = $accessKeyId
                                    Devolutions.CIEM\Set-CIEMSecret 'CIEM_AWS_AccessKeyId' $accessKeyId
                                }
                                if ($secretAccessKey -and $secretAccessKey -ne '********') {
                                    $saveParams['SecretAccessKey'] = $secretAccessKey
                                    Devolutions.CIEM\Set-CIEMSecret 'CIEM_AWS_SecretAccessKey' $secretAccessKey
                                }
                            }
                        }

                        if ($authMethod -eq 'CurrentProfile') {
                            Devolutions.CIEM\Set-CIEMAWSAuthenticationProfile -Method $authMethod -Region $region -Profile $profile | Out-Null
                        }
                        else {
                            Devolutions.CIEM\Set-CIEMAWSAuthenticationProfile -Method $authMethod -Region $region | Out-Null
                        }

                        # Enable the provider
                        Devolutions.CIEM\Update-CIEMProvider -Name 'AWS' -Enabled $true | Out-Null
                        Devolutions.CIEM\Write-CIEMLog -Message "AWS configuration saved" -Severity INFO -Component 'PSU-ConfigPage'
                    }

                    Show-UDToast -Message 'Configuration saved successfully.' -Duration 5000 -BackgroundColor '#4caf50'
                    Devolutions.CIEM\Write-CIEMLog -Message "Save Configuration completed successfully" -Severity INFO -Component 'PSU-ConfigPage'
                } catch {
                    Devolutions.CIEM\Write-CIEMLog -Message "Save Configuration failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                    Devolutions.CIEM\Write-CIEMLog -Message "Stack: $($_.ScriptStackTrace)" -Severity DEBUG -Component 'PSU-ConfigPage'
                    Show-UDToast -Message "Save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                }
            }

            # Required Permissions and Test Authentication Buttons
            New-UDElement -Tag 'div' -Content {
                New-UDStack -Direction 'row' -Spacing 2 -Content {
                    New-UDButton -Text 'Get Required Permissions' -Variant 'outlined' -Color 'primary' -OnClick {
                        try {
                            $requiredPermissions = Devolutions.CIEM\Get-CIEMRequiredPermission -Provider 'Azure'
                            $discoveryPermissions = $requiredPermissions.Discovery
                            $remediationPermissions = $requiredPermissions.Remediation

                            Show-UDModal -Header {
                                New-UDTypography -Text 'Required Permissions for Azure Discovery and Remediation' -Variant 'h6'
                            } -Content {
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text 'Discovery Permissions' -Variant 'subtitle1' -Style @{ fontWeight = 'bold' }
                                    New-UDTypography -Text "The following permissions are required for Azure discovery ($($discoveryPermissions.DiscoveryEndpointCount) endpoints):" -Variant 'body2' -Style @{ marginBottom = '16px' }

                                    if ($discoveryPermissions.Graph.Count -gt 0) {
                                        New-UDTypography -Text 'Microsoft Graph API Permissions (Application)' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                        New-UDTypography -Text 'Grant these in Azure Portal > App Registrations > API Permissions > Add > Microsoft Graph > Application permissions' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                        New-UDList -Content {
                                            foreach ($perm in $discoveryPermissions.Graph) {
                                                New-UDListItem -Label $perm -Icon (New-UDIcon -Icon 'Key' -Size 'sm')
                                            }
                                        }
                                    }

                                    if ($discoveryPermissions.AzureRoles.Count -gt 0) {
                                        New-UDTypography -Text 'Azure RBAC Roles' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                        New-UDTypography -Text 'Assign these roles at the subscription or management group level.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                        New-UDList -Content {
                                            foreach ($role in $discoveryPermissions.AzureRoles) {
                                                New-UDListItem -Label $role -Icon (New-UDIcon -Icon 'Shield' -Size 'sm')
                                            }
                                        }
                                    }

                                    if ($remediationPermissions.Graph.Count -gt 0 -or $remediationPermissions.AzureRoles.Count -gt 0) {
                                        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '20px'; marginBottom = '20px' } } -Content {
                                            New-UDDivider
                                        }
                                        New-UDTypography -Text 'Remediation Permissions' -Variant 'subtitle1' -Style @{ fontWeight = 'bold' }
                                        New-UDTypography -Text "The following additional permissions are required for the supported Azure remediation actions across $($remediationPermissions.TemplateCount) remediation template(s):" -Variant 'body2' -Style @{ marginBottom = '16px' }

                                        if ($remediationPermissions.Graph.Count -gt 0) {
                                            New-UDTypography -Text 'Microsoft Graph API Permissions (Application)' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                            New-UDTypography -Text 'Grant these in Azure Portal > App Registrations > API Permissions > Add > Microsoft Graph > Application permissions' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                            New-UDList -Content {
                                                foreach ($perm in $remediationPermissions.Graph) {
                                                    New-UDListItem -Label $perm -Icon (New-UDIcon -Icon 'Key' -Size 'sm')
                                                }
                                            }
                                        }

                                        if ($remediationPermissions.AzureRoles.Count -gt 0) {
                                            New-UDTypography -Text 'Azure RBAC Roles' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                            New-UDTypography -Text 'Assign these roles at the subscription or management group level.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                            New-UDList -Content {
                                                foreach ($role in $remediationPermissions.AzureRoles) {
                                                    New-UDListItem -Label $role -Icon (New-UDIcon -Icon 'Shield' -Size 'sm')
                                                }
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
                            Devolutions.CIEM\Write-CIEMLog -Message "Test Authentication button clicked" -Severity INFO -Component 'PSU-ConfigPage'

                            $testProvider = (Get-UDElement -Id 'cloudProvider').value
                            if (-not $testProvider) { $testProvider = 'Azure' }

                            Show-UDToast -Message "Connecting to $testProvider..." -Duration 3000

                            $connectResult = Devolutions.CIEM\Connect-CIEM -Provider $testProvider -Force
                            $connectProvider = $connectResult.Providers | Where-Object { $_.Provider -eq $testProvider }
                            Devolutions.CIEM\Write-CIEMLog -Message "Connect-CIEM result: Status=$($connectProvider.Status), Account=$($connectProvider.Account)" -Severity INFO -Component 'PSU-ConfigPage'

                            if ($connectProvider.Status -eq 'Connected') {
                                Show-UDToast -Message "Authentication Successful - Connected as $($connectProvider.Account)" -Duration 8000 -BackgroundColor '#4caf50'
                            } else {
                                Devolutions.CIEM\Write-CIEMLog -Message "Authentication FAILED: $($connectProvider.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Show-UDToast -Message "Authentication Failed: $($connectProvider.Message)" -Duration 10000 -BackgroundColor '#f44336'
                            }
                        } catch {
                            Devolutions.CIEM\Write-CIEMLog -Message "Test Authentication exception: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                            Show-UDToast -Message "Authentication Failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                        }
                    }
                }
            } -Attributes @{ style = @{ marginTop = '16px' } }
        }

        New-UDDynamic -Id 'scheduledDiscoveryContainer' -Content {
            $scheduleProvider = (Get-UDElement -Id 'cloudProvider').value
            if (-not $scheduleProvider) { $scheduleProvider = $currentProvider }
            $scheduleDisplay = if ($scheduleProvider -eq 'Azure') { 'block' } else { 'none' }

            New-UDElement -Tag 'div' -Id 'scheduledDiscoveryWrapper' -Attributes @{ style = @{ display = $scheduleDisplay } } -Content {
                if ($scheduleProvider -eq 'Azure') {
                    New-UDCard -Title 'Scheduled Discovery' -Content {
            $scheduleRows = @(Devolutions.CIEM\Get-CIEMAzureDiscoverySchedule)
            $schedule = $scheduleRows | Select-Object -First 1
            $selectedScope = if ($schedule) { [string]$schedule.Scope } else { 'All' }
            $selectedCadence = if (-not $schedule -or $schedule.Cron -eq '0 2 * * *') {
                'daily'
            }
            elseif ($schedule.Cron -eq '0 2 * * 1') {
                'weekly'
            }
            else {
                throw "Unsupported scheduled discovery cron '$($schedule.Cron)'."
            }
            $scheduleEnabled = if ($schedule) { [bool]$schedule.Enabled } else { $false }

            New-UDGrid -Container -Spacing 2 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                    New-UDSelect -Id 'azureDiscoveryScheduleCadence' -Label 'Cadence' -DefaultValue $selectedCadence -FullWidth -Option {
                        New-UDSelectOption -Name 'Daily' -Value 'daily'
                        New-UDSelectOption -Name 'Weekly' -Value 'weekly'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                    New-UDSelect -Id 'azureDiscoveryScheduleScope' -Label 'Scope' -DefaultValue $selectedScope -FullWidth -Option {
                        New-UDSelectOption -Name 'All' -Value 'All'
                        New-UDSelectOption -Name 'ARM' -Value 'ARM'
                        New-UDSelectOption -Name 'Entra' -Value 'Entra'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 2 -Content {
                    New-UDSwitch -Id 'azureDiscoveryScheduleEnabled' -Label 'Enabled' -Checked $scheduleEnabled
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 2 -Content {
                    New-UDButton -Id 'saveAzureDiscoveryScheduleBtn' -Text 'Save' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                        try {
                            $cadence = [string](Get-UDElement -Id 'azureDiscoveryScheduleCadence').value
                            $scope = [string](Get-UDElement -Id 'azureDiscoveryScheduleScope').value
                            $enabled = [bool](Get-UDElement -Id 'azureDiscoveryScheduleEnabled').checked

                            $cron = switch ($cadence) {
                                'daily' { '0 2 * * *' }
                                'weekly' { '0 2 * * 1' }
                                default { throw "Unsupported scheduled discovery cadence '$cadence'." }
                            }

                            Devolutions.CIEM\Set-CIEMAzureDiscoverySchedule -Scope $scope -Cron $cron -Enabled $enabled | Out-Null
                            Sync-UDElement -Id 'azureDiscoveryScheduleStatus'
                            Show-UDToast -Message 'Scheduled discovery saved.' -Duration 5000 -BackgroundColor '#4caf50'
                        }
                        catch {
                            Devolutions.CIEM\Write-CIEMLog -Message "Save scheduled discovery failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                            Show-UDToast -Message "Scheduled discovery save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                        }
                    }
                }
            }

            New-UDDynamic -Id 'azureDiscoveryScheduleStatus' -Content {
                $currentSchedule = @(Devolutions.CIEM\Get-CIEMAzureDiscoverySchedule) | Select-Object -First 1
                if ($currentSchedule) {
                    $state = if ($currentSchedule.Enabled) { 'Enabled' } else { 'Disabled' }
                    $lastStatus = if ($currentSchedule.LastStatus) { $currentSchedule.LastStatus } else { 'No scheduled run recorded' }
                    New-UDTypography -Text "$state - $($currentSchedule.Scope) - $($currentSchedule.Cron) - $lastStatus" -Variant 'caption' -Style @{ color = '#666' }
                }
                else {
                    New-UDTypography -Text 'Disabled - no schedule configured' -Variant 'caption' -Style @{ color = '#666' }
                }
            }
            } -Style @{ marginTop = '24px' }
                }
            }
        }

        New-UDCard -Title 'Notification Channels' -Content {
            $notificationProfile = @(Devolutions.CIEM\Get-CIEMNotificationAuthenticationProfile -Id 'email-smtp') | Select-Object -First 1
            $notificationChannel = @(Devolutions.CIEM\Get-CIEMNotificationChannel -Id 'email-default') | Select-Object -First 1
            $notification = @(Devolutions.CIEM\Get-CIEMNotification -Id 'exposure-change-default') | Select-Object -First 1
            $passwordSecretName = 'CIEM_Notification_Email_Password'
            $passwordExists = Test-Path "Secret:$passwordSecretName"

            $selectedNotificationAuthMethod = if ($notificationProfile) { [string]$notificationProfile.Method } else { 'SmtpAnonymous' }
            $selectedTlsMode = if ($notificationProfile) { [string]$notificationProfile.Settings.TlsMode } else { 'None' }
            $selectedAutoSendScope = if ($notification) { [string]$notification.AutoSendScope } else { 'AnyDiscovery' }
            $selectedMinimumSeverity = if ($notification) { [string]$notification.MinimumSeverity } else { 'High' }
            $selectedChangeTypes = if ($notification) { @($notification.ChangeTypes) } else { @('NewRisk', 'RiskIncrease') }
            if (-not $Page:NotificationAuthMethod) {
                $Page:NotificationAuthMethod = $selectedNotificationAuthMethod
            }

            New-UDElement -Tag 'style' -Content {
@'
#notificationSmtpBasicFieldsWrapper { display: none !important; }
body:has(#notificationAuthMethod[value="SmtpBasic"]) #notificationSmtpBasicFieldsWrapper { display: block !important; }
body:has(#notificationAuthMethod[value="SmtpAnonymous"]) #notificationSmtpBasicFieldsWrapper { display: none !important; }
'@
            }

            New-UDGrid -Container -Spacing 2 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                    New-UDSelect -Id 'notificationAuthMethod' -Label 'SMTP Auth Method' -DefaultValue $selectedNotificationAuthMethod -FullWidth -Option {
                        New-UDSelectOption -Name 'Anonymous SMTP Relay' -Value 'SmtpAnonymous'
                        New-UDSelectOption -Name 'SMTP Basic' -Value 'SmtpBasic'
                    } -OnChange {
                        $Page:NotificationAuthMethod = $EventData
                        Sync-UDElement -Id 'notificationAuthFieldsContainer'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 5 -Content {
                    New-UDTextbox -Id 'notificationSmtpHost' -Label 'SMTP Host' -Value $notificationProfile.Settings.Host -FullWidth -Placeholder 'smtp.example.com'
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    $smtpPort = if ($notificationProfile) { [string]$notificationProfile.Settings.Port } else { '25' }
                    New-UDTextbox -Id 'notificationSmtpPort' -Label 'Port' -Value $smtpPort -FullWidth -Placeholder '25'
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                    New-UDSelect -Id 'notificationSmtpTlsMode' -Label 'TLS Mode' -DefaultValue $selectedTlsMode -FullWidth -Option {
                        New-UDSelectOption -Name 'None' -Value 'None'
                        New-UDSelectOption -Name 'STARTTLS' -Value 'StartTls'
                        New-UDSelectOption -Name 'SSL/TLS' -Value 'Ssl'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                    New-UDDynamic -Id 'notificationAuthFieldsContainer' -Content {
                        $smtpAuthMethod = $Page:NotificationAuthMethod
                        if (-not $smtpAuthMethod) { $smtpAuthMethod = $selectedNotificationAuthMethod }
                        $smtpBasicDisplay = if ($smtpAuthMethod -eq 'SmtpBasic') { 'block' } else { 'none' }

                        New-UDElement -Tag 'div' -Id 'notificationSmtpBasicFieldsWrapper' -Attributes @{ style = @{ display = $smtpBasicDisplay } } -Content {
                            New-UDGrid -Container -Spacing 2 -Content {
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    New-UDTextbox -Id 'notificationSmtpUsername' -Label 'SMTP Username' -Value $notificationProfile.Settings.Username -FullWidth -Placeholder 'alerts@example.com'
                                }
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    $smtpPasswordValue = if ($passwordExists) { '********' } else { '' }
                                    $smtpPasswordPlaceholder = if ($passwordExists) { 'Password is stored. Leave empty to keep existing.' } else { 'SMTP password' }
                                    New-UDTextbox -Id 'notificationSmtpPassword' -Label 'SMTP Password' -Type 'password' -Value $smtpPasswordValue -FullWidth -Placeholder $smtpPasswordPlaceholder
                                }
                            }
                        }
                    }
                }
            }

            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '16px'; marginBottom = '16px' } } -Content {
                New-UDDivider
            }

            New-UDGrid -Container -Spacing 2 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    $channelEnabled = if ($notificationChannel) { [bool]$notificationChannel.Enabled } else { $false }
                    New-UDSwitch -Id 'notificationChannelEnabled' -Label 'Email Channel Enabled' -Checked $channelEnabled
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 9 -Content {
                    New-UDTextbox -Id 'notificationFromAddress' -Label 'From Address' -Value $notificationChannel.FromAddress -FullWidth -Placeholder 'ciem@example.com'
                }
                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                    New-UDTextbox -Id 'notificationToRecipients' -Label 'To Recipients' -Value (@($notificationChannel.ToRecipients) -join ', ') -FullWidth -Placeholder 'security@example.com, it@example.com'
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    New-UDTextbox -Id 'notificationCcRecipients' -Label 'Cc Recipients' -Value (@($notificationChannel.CcRecipients) -join ', ') -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    New-UDTextbox -Id 'notificationBccRecipients' -Label 'Bcc Recipients' -Value (@($notificationChannel.BccRecipients) -join ', ') -FullWidth
                }
            }

            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '16px'; marginBottom = '16px' } } -Content {
                New-UDDivider
            }

            New-UDGrid -Container -Spacing 2 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    $notificationEnabled = if ($notification) { [bool]$notification.Enabled } else { $false }
                    New-UDSwitch -Id 'notificationEnabled' -Label 'Exposure Change Notification Enabled' -Checked $notificationEnabled
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    New-UDSelect -Id 'notificationAutoSendScope' -Label 'Auto-send Scope' -DefaultValue $selectedAutoSendScope -FullWidth -Option {
                        New-UDSelectOption -Name 'Any Discovery' -Value 'AnyDiscovery'
                        New-UDSelectOption -Name 'Scheduled Discovery' -Value 'ScheduledDiscovery'
                        New-UDSelectOption -Name 'Manual Only' -Value 'ManualOnly'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    New-UDSelect -Id 'notificationMinimumSeverity' -Label 'Minimum Severity' -DefaultValue $selectedMinimumSeverity -FullWidth -Option {
                        New-UDSelectOption -Name 'Critical' -Value 'Critical'
                        New-UDSelectOption -Name 'High' -Value 'High'
                        New-UDSelectOption -Name 'Medium' -Value 'Medium'
                        New-UDSelectOption -Name 'Low' -Value 'Low'
                        New-UDSelectOption -Name 'Info' -Value 'Info'
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                    New-UDStack -Direction 'row' -Spacing 1 -Content {
                        New-UDSwitch -Id 'notificationChangeTypeNewRisk' -Label 'New' -Checked ($selectedChangeTypes -contains 'NewRisk')
                        New-UDSwitch -Id 'notificationChangeTypeRiskIncrease' -Label 'Increased' -Checked ($selectedChangeTypes -contains 'RiskIncrease')
                        New-UDSwitch -Id 'notificationChangeTypeRemovedRisk' -Label 'Removed' -Checked ($selectedChangeTypes -contains 'RemovedRisk')
                    }
                }
                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                    $subjectTemplate = if ($notification) { $notification.SubjectTemplate } else { '[CIEM] {{Severity}} exposure: {{Title}}' }
                    New-UDTextbox -Id 'notificationSubjectTemplate' -Label 'Subject Template' -Value $subjectTemplate -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    $textTemplate = if ($notification) { $notification.TextBodyTemplate } else { "Exposure change: {{Title}}`nSeverity: {{Severity}}`nEvidence: {{Evidence}}" }
                    New-UDTextbox -Id 'notificationTextBodyTemplate' -Label 'Plain Text Body Template' -Value $textTemplate -Multiline -Rows 5 -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    $htmlTemplate = if ($notification) { $notification.HtmlBodyTemplate } else { '<p><strong>{{Severity}}</strong>: {{Title}}</p><p>{{Evidence}}</p>' }
                    New-UDTextbox -Id 'notificationHtmlBodyTemplate' -Label 'HTML Body Template' -Value $htmlTemplate -Multiline -Rows 5 -FullWidth
                }
                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                    New-UDStack -Direction 'row' -Spacing 2 -Content {
                        New-UDButton -Id 'saveNotificationsBtn' -Text 'Save Notifications' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                            try {
                                $parseRecipients = {
                                    param([string]$RecipientText)

                                    if ([string]::IsNullOrWhiteSpace($RecipientText)) {
                                        return
                                    }

                                    foreach ($recipient in ($RecipientText -split ',')) {
                                        $trimmedRecipient = $recipient.Trim()
                                        if (-not [string]::IsNullOrWhiteSpace($trimmedRecipient)) {
                                            $trimmedRecipient
                                        }
                                    }
                                }

                                $smtpAuthMethod = [string]$Page:NotificationAuthMethod
                                if (-not $smtpAuthMethod) { $smtpAuthMethod = [string](Get-UDElement -Id 'notificationAuthMethod').value }
                                $smtpHost = [string](Get-UDElement -Id 'notificationSmtpHost').value
                                $smtpPort = [int](Get-UDElement -Id 'notificationSmtpPort').value
                                $smtpTlsMode = [string](Get-UDElement -Id 'notificationSmtpTlsMode').value
                                $smtpUsername = [string](Get-UDElement -Id 'notificationSmtpUsername').value
                                $smtpPassword = [string](Get-UDElement -Id 'notificationSmtpPassword').value

                                if ($smtpAuthMethod -eq 'SmtpBasic' -and $smtpPassword -and $smtpPassword -ne '********') {
                                    Devolutions.CIEM\Set-CIEMSecret $passwordSecretName $smtpPassword
                                }
                                if ($smtpAuthMethod -eq 'SmtpBasic' -and -not (Test-Path "Secret:$passwordSecretName") -and -not $smtpPassword) {
                                    throw 'SMTP Basic requires a password.'
                                }

                                $profileParams = @{
                                    Name = 'Default SMTP'
                                    Method = $smtpAuthMethod
                                    Host = $smtpHost
                                    Port = $smtpPort
                                    TlsMode = $smtpTlsMode
                                }
                                if ($smtpAuthMethod -eq 'SmtpBasic') {
                                    $profileParams.Username = $smtpUsername
                                    $profileParams.PasswordSecretName = $passwordSecretName
                                }
                                $savedProfile = Devolutions.CIEM\Set-CIEMNotificationAuthenticationProfile @profileParams

                                $toRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationToRecipients').value))
                                $ccRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationCcRecipients').value))
                                $bccRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationBccRecipients').value))

                                Devolutions.CIEM\Set-CIEMNotificationChannel `
                                    -Enabled ([bool](Get-UDElement -Id 'notificationChannelEnabled').checked) `
                                    -AuthenticationProfileId $savedProfile.Id `
                                    -FromAddress ([string](Get-UDElement -Id 'notificationFromAddress').value) `
                                    -ToRecipients $toRecipients `
                                    -CcRecipients $ccRecipients `
                                    -BccRecipients $bccRecipients | Out-Null

                                $changeTypes = @()
                                if ([bool](Get-UDElement -Id 'notificationChangeTypeNewRisk').checked) { $changeTypes += 'NewRisk' }
                                if ([bool](Get-UDElement -Id 'notificationChangeTypeRiskIncrease').checked) { $changeTypes += 'RiskIncrease' }
                                if ([bool](Get-UDElement -Id 'notificationChangeTypeRemovedRisk').checked) { $changeTypes += 'RemovedRisk' }

                                Devolutions.CIEM\Set-CIEMNotification `
                                    -Enabled ([bool](Get-UDElement -Id 'notificationEnabled').checked) `
                                    -AutoSendScope ([string](Get-UDElement -Id 'notificationAutoSendScope').value) `
                                    -ChangeTypes $changeTypes `
                                    -MinimumSeverity ([string](Get-UDElement -Id 'notificationMinimumSeverity').value) `
                                    -SubjectTemplate ([string](Get-UDElement -Id 'notificationSubjectTemplate').value) `
                                    -TextBodyTemplate ([string](Get-UDElement -Id 'notificationTextBodyTemplate').value) `
                                    -HtmlBodyTemplate ([string](Get-UDElement -Id 'notificationHtmlBodyTemplate').value) | Out-Null

                                Sync-UDElement -Id 'notificationHistoryTable'
                                Show-UDToast -Message 'Notifications saved.' -Duration 5000 -BackgroundColor '#4caf50'
                            }
                            catch {
                                Devolutions.CIEM\Write-CIEMLog -Message "Save notifications failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Show-UDToast -Message "Notification save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                            }
                        }
                        New-UDButton -Id 'testNotificationEmailBtn' -Text 'Test Email' -Variant 'outlined' -Color 'secondary' -ShowLoading -OnClick {
                            try {
                                $sendResult = Devolutions.CIEM\Send-CIEMNotification -InvocationSource 'Manual' -Test
                                Sync-UDElement -Id 'notificationHistoryTable'
                                Show-UDToast -Message "Test email completed: $($sendResult.SentCount) sent." -Duration 5000 -BackgroundColor '#4caf50'
                            }
                            catch {
                                Devolutions.CIEM\Write-CIEMLog -Message "Test notification failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                Sync-UDElement -Id 'notificationHistoryTable'
                                Show-UDToast -Message "Test email failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                            }
                        }
                    }
                }
            }

            New-UDDynamic -Id 'notificationHistoryTable' -Content {
                $historyRows = @(Devolutions.CIEM\Get-CIEMNotificationHistory -Last 10)
                if ($historyRows.Count -eq 0) {
                    New-UDTypography -Text 'No notification history.' -Variant 'caption' -Style @{ color = '#666'; marginTop = '16px' }
                }
                else {
                    New-UDTable -Data $historyRows -Columns @(
                        New-UDTableColumn -Property 'AttemptedAt' -Title 'Attempted'
                        New-UDTableColumn -Property 'Status' -Title 'Status'
                        New-UDTableColumn -Property 'SourceSignalId' -Title 'Source'
                        New-UDTableColumn -Property 'RecipientSummary' -Title 'Recipients'
                        New-UDTableColumn -Property 'ErrorMessage' -Title 'Error'
                    ) -Dense
                }
            }
        } -Style @{ marginTop = '24px' }

        New-UDElement -Tag 'div' -Content {
            New-UDStack -Direction 'row' -Spacing 2 -Content {
                New-UDButton -Id 'resetConfigBtn' -Text 'Reset to Defaults' -Variant 'outlined' -Color 'secondary' -OnClick {
                    try {
                        Set-UDElement -Id 'cloudProvider' -Properties @{ value = 'Azure' }
                        Set-UDElement -Id 'authMethod' -Properties @{ value = 'ServicePrincipalSecret' }
                        Sync-UDElement -Id 'authMethodContainer'
                        Sync-UDElement -Id 'authFieldsContainer'
                        Sync-UDElement -Id 'scheduledDiscoveryContainer'
                        Show-UDToast -Message 'Form reset to default values. Click Save to apply.' -Duration 5000 -BackgroundColor '#ff9800'
                    } catch {
                        Show-UDToast -Message "Failed to reset: $($_.Exception.Message)" -Duration 8000 -BackgroundColor '#f44336'
                    }
                }
            }
        } -Attributes @{ style = @{ marginTop = '24px' } }
    } -Navigation $Navigation -NavigationLayout permanent
}
