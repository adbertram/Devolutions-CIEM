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

    New-UDPage -Name 'Configuration' -Url '/ciem/config' -Content {
        # Ensure module functions are available in this page's runspace
        Import-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue

        # Load configuration from PSU cache (or defaults if first run)
        $CurrentConfig = Get-CIEMConfig

        # Get PSU environment
        $envInfo = Get-PSUInstalledEnvironment

        # Get current provider (default to Azure)
        $currentProvider = (Get-CIEMProvider | Where-Object IsDefault | Select-Object -First 1).Name
        if (-not $currentProvider) { $currentProvider = 'Azure' }

        # Store original auth values in session state for change detection on save
        # Only initialize on first page load (not on dynamic refreshes)
        if (-not $Session:OriginalAuthValues) {
            $azProvider = Get-CIEMProvider -Name $currentProvider
            $Session:OriginalAuthValues = @{
                Provider = $currentProvider
                Method = if ($azProvider.Authentication.Method) { $azProvider.Authentication.Method } else { 'ServicePrincipalSecret' }
                TenantId = $azProvider.Authentication.TenantId
                ClientId = $azProvider.Authentication.ClientId
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
                    $awsProvider = Get-CIEMProvider -Name 'AWS'
                    $awsAuthMethod = if ($awsProvider.Authentication.Method) { $awsProvider.Authentication.Method } else { 'CurrentProfile' }

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
                    $azProviderForMethod = Get-CIEMProvider -Name 'Azure'
                    $azureAuthMethod = if ($azProviderForMethod.Authentication.Method) { $azProviderForMethod.Authentication.Method } else { 'ServicePrincipalSecret' }

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
                $defaultProvider = (Get-CIEMProvider | Where-Object IsDefault | Select-Object -First 1).Name
                $selectedProvider = if ($uiProvider) { $uiProvider } elseif ($defaultProvider) { $defaultProvider } else { 'Azure' }
                $providerForFields = Get-CIEMProvider -Name $selectedProvider
                $selectedMethod = if ($uiMethod) { $uiMethod } elseif ($providerForFields.Authentication.Method) { $providerForFields.Authentication.Method } else { 'ServicePrincipalSecret' }

                # Check for ManagedIdentity warning
                $envCheck = Get-PSUInstalledEnvironment
                if ($selectedMethod -eq 'ManagedIdentity' -and -not $envCheck.SupportsManagedIdentity) {
                    New-UDAlert -Severity 'warning' -Text 'Managed Identity will not work in on-premises deployments. Please choose a different authentication method.' -Style @{ marginBottom = '16px' }
                }

                # Load credentials: TenantId/ClientId from provider cache, secrets from PSU secrets
                $storedCreds = @{
                    TenantId = $providerForFields.Authentication.TenantId
                    ClientId = $providerForFields.Authentication.ClientId
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
                    $awsProviderForFields = Get-CIEMProvider -Name 'AWS'
                    $awsStoredProfile = $awsProviderForFields.Authentication.Profile
                    $awsStoredRegion = $awsProviderForFields.Authentication.Region
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
                            $selectedProvider = (Get-UDElement -Id 'cloudProvider').value
                            if (-not $selectedProvider) { $selectedProvider = 'Azure' }
                            $permissions = Get-CIEMRequiredPermission -Provider $selectedProvider
                            Show-UDModal -Header {
                                New-UDTypography -Text "Required Permissions for $selectedProvider CIEM Scans" -Variant 'h6'
                            } -Content {
                                New-UDElement -Tag 'div' -Content {
                                    New-UDTypography -Text "The following permissions are required to run all $($permissions.CheckCount) $selectedProvider security checks:" -Variant 'body2' -Style @{ marginBottom = '16px' }

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

                                    if ($permissions.IAM.Count -gt 0) {
                                        New-UDTypography -Text 'AWS IAM Actions' -Variant 'subtitle1' -Style @{ fontWeight = 'bold'; marginTop = '16px' }
                                        New-UDTypography -Text 'Attach an IAM policy to your scanning identity (user or role) that grants these actions.' -Variant 'caption' -Style @{ color = '#666'; marginBottom = '8px' }
                                        New-UDList -Content {
                                            foreach ($perm in $permissions.IAM) {
                                                New-UDListItem -Label $perm -Icon (New-UDIcon -Icon 'UserShield' -Size 'sm')
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
