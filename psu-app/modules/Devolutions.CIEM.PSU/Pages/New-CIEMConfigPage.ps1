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
                        $region = [string]$EventData.awsRegion
                        $saveParams['Region'] = $region

                        switch ($authMethod) {
                            'CurrentProfile' {
                                $saveParams['Profile'] = [string]$EventData.awsProfile
                            }
                            'AccessKey' {
                                $accessKeyId = [string]$EventData.awsAccessKeyId
                                $secretAccessKey = [string]$EventData.awsSecretAccessKey
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

        New-UDElement -Tag 'div' -Content {
            New-UDStack -Direction 'row' -Spacing 2 -Content {
                New-UDButton -Id 'resetConfigBtn' -Text 'Reset to Defaults' -Variant 'outlined' -Color 'secondary' -OnClick {
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
