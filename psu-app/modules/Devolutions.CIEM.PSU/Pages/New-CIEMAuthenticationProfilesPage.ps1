function New-CIEMAuthenticationProfileFieldControls {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Method,

        [string]$SelectedProfileId
    )

    $ErrorActionPreference = 'Stop'

    New-UDGrid -Container -Spacing 2 -Content {
        $currentSelectedProfile = if ($SelectedProfileId) {
            @(Devolutions.CIEM\Get-CIEMAuthenticationProfile -Id $SelectedProfileId) | Select-Object -First 1
        }
        $schema = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema -Provider $Provider -Method $Method | Select-Object -First 1)
        $schemaProvider = [string]$schema.provider
        $schemaMethod = [string]$schema.method
        foreach ($field in @($schema.fields)) {
            $fieldName = [string]$field.name
            $inputId = "authProfileField_${schemaProvider}_${schemaMethod}_$fieldName"
            $existingValue = if ($currentSelectedProfile -and $currentSelectedProfile.Provider -eq $schemaProvider -and $currentSelectedProfile.Method -eq $schemaMethod -and $field.kind -eq 'setting') { $currentSelectedProfile.Settings.$fieldName } else { $null }
            $renderedValue = if ($null -ne $existingValue) { $existingValue } else { '' }
            $fieldType = if ($field.inputType -eq 'password') { 'password' } elseif ($field.inputType -eq 'number') { 'number' } else { 'text' }

            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                if ($field.inputType -eq 'select') {
                    New-UDSelect -Id $inputId -Label $field.label -DefaultValue $renderedValue -FullWidth -Option {
                        foreach ($option in @($field.options)) {
                            New-UDSelectOption -Name $option -Value $option
                        }
                    }
                }
                elseif ($field.inputType -eq 'upload') {
                    New-UDUpload -Id $inputId -Text $field.label -Accept '.pfx,.p12' -OnUpload {
                        $upload = $Body | ConvertFrom-Json -ErrorAction Stop
                        if ([string]::IsNullOrWhiteSpace([string]$upload.data)) {
                            throw 'Authentication profile upload did not include file data.'
                        }
                        $Page:UploadedAuthProfileSecretFiles[$fieldName] = [PSCustomObject]@{
                            Name = [string]$upload.name
                            Data = [string]$upload.data
                        }
                        Sync-UDElement -Id 'authProfileUploadStatus'
                    }
                }
                elseif ($field.kind -eq 'setting') {
                    New-UDTextbox -Id $inputId -Label $field.label -Value $renderedValue -Type $fieldType -FullWidth
                }
                else {
                    $value = if ($currentSelectedProfile -and $currentSelectedProfile.Provider -eq $schemaProvider -and $currentSelectedProfile.Method -eq $schemaMethod -and $field.kind -eq 'secret' -and $currentSelectedProfile.SecretRefs.$fieldName) { '********' } else { '' }
                    New-UDTextbox -Id $inputId -Label $field.label -Value $value -Type $fieldType -FullWidth
                }
            }
        }

        New-UDGrid -Item -ExtraSmallSize 12 -Content {
            New-UDDynamic -Id 'authProfileUploadStatus' -Content {
                foreach ($fileKey in @($Page:UploadedAuthProfileSecretFiles.Keys)) {
                    New-UDChip -Label "$($fileKey): $($Page:UploadedAuthProfileSecretFiles[$fileKey].Name)" -Size 'small'
                }
            }
        }
    }
}

function Set-CIEMAuthenticationProfileFormContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Method
    )

    $ErrorActionPreference = 'Stop'

    $nameElement = Get-UDElement -Id 'authProfileName'
    if ($null -eq $nameElement) {
        throw 'Authentication profile form did not render the name field.'
    }

    $Page:AuthenticationProfileName = [string]$nameElement.value
    $Page:AuthenticationProfileProvider = $Provider
    $Page:AuthenticationProfileMethod = $Method

    Set-UDElement -Id 'authenticationProfileForm' -Content {
        New-CIEMAuthenticationProfileFormContent `
            -Provider ([string]$Page:AuthenticationProfileProvider) `
            -Method ([string]$Page:AuthenticationProfileMethod) `
            -Name ([string]$Page:AuthenticationProfileName) `
            -SelectedProfileId $Page:SelectedAuthenticationProfileId
    }
}

function New-CIEMAuthenticationProfileFormContent {
    [CmdletBinding()]
    param(
        [string]$Provider = '',

        [string]$Method = '',

        [string]$Name = '',

        [string]$SelectedProfileId
    )

    $ErrorActionPreference = 'Stop'

    $providerSelected = -not [string]::IsNullOrWhiteSpace($Provider)
    $methodSelected = -not [string]::IsNullOrWhiteSpace($Method)
    if ($providerSelected) {
        $providerSchemas = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema -Provider $Provider)
        if ($providerSchemas.Count -eq 0) {
            throw "No authentication profile methods are configured for provider '$Provider'."
        }
        if ($methodSelected -and @($providerSchemas.method) -notcontains $Method) {
            $Method = [string]$providerSchemas[0].method
        }
    }

    $Page:AuthenticationProfileProvider = $Provider
    $Page:AuthenticationProfileMethod = $Method
    $Page:AuthenticationProfileName = $Name

    New-UDGrid -Container -Spacing 2 -Content {
        New-UDGrid -Item -ExtraSmallSize 12 -Content {
            New-UDTextbox -Id 'authProfileName' -Label 'Name' -Value $Name -FullWidth -OnChange {
                $Page:AuthenticationProfileName = [string]$EventData
            }
        }
        New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
            New-UDTypography -Text 'Provider' -Variant 'caption'
            New-UDElement -Tag 'input' -Id 'authProfileProvider' -Attributes @{ type = 'hidden'; value = $Provider }
            New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'flex'; gap = '8px'; flexWrap = 'wrap' } } -Content {
                $awsProviderButtonVariant = if ('AWS' -eq $Provider) { 'contained' } else { 'outlined' }
                New-UDButton -Id 'authProfileProviderOption_AWS' -Text 'AWS' -Variant $awsProviderButtonVariant -OnClick {
                    Set-CIEMAuthenticationProfileFormContent -Provider 'AWS' -Method 'CurrentProfile'
                }
                $azureProviderButtonVariant = if ('Azure' -eq $Provider) { 'contained' } else { 'outlined' }
                New-UDButton -Id 'authProfileProviderOption_Azure' -Text 'Azure' -Variant $azureProviderButtonVariant -OnClick {
                    Set-CIEMAuthenticationProfileFormContent -Provider 'Azure' -Method 'ServicePrincipalSecret'
                }
                $emailProviderButtonVariant = if ('Email' -eq $Provider) { 'contained' } else { 'outlined' }
                New-UDButton -Id 'authProfileProviderOption_Email' -Text 'Email' -Variant $emailProviderButtonVariant -OnClick {
                    Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpAnonymous'
                }
            }
        }
        if ($providerSelected -and $methodSelected) {
            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                New-UDGrid -Container -Spacing 2 -Content {
                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                        New-UDTypography -Text 'Method' -Variant 'caption'
                        New-UDElement -Tag 'input' -Id 'authProfileMethod' -Attributes @{ type = 'hidden'; value = $Method }
                        New-UDElement -Tag 'div' -Attributes @{ style = @{ display = 'flex'; gap = '8px'; flexWrap = 'wrap' } } -Content {
                            if ($Provider -eq 'Azure') {
                                $spSecretVariant = if ('ServicePrincipalSecret' -eq $Method) { 'contained' } else { 'outlined' }
                                $spCertificateVariant = if ('ServicePrincipalCertificate' -eq $Method) { 'contained' } else { 'outlined' }
                                $managedIdentityVariant = if ('ManagedIdentity' -eq $Method) { 'contained' } else { 'outlined' }
                                New-UDButton -Id 'authProfileMethodOption_ServicePrincipalSecret' -Text 'Service Principal (Secret)' -Variant $spSecretVariant -OnClick {
                                    Set-CIEMAuthenticationProfileFormContent -Provider 'Azure' -Method 'ServicePrincipalSecret'
                                }
                                New-UDButton -Id 'authProfileMethodOption_ServicePrincipalCertificate' -Text 'Service Principal (Certificate)' -Variant $spCertificateVariant -OnClick {
                                    Set-CIEMAuthenticationProfileFormContent -Provider 'Azure' -Method 'ServicePrincipalCertificate'
                                }
                                New-UDButton -Id 'authProfileMethodOption_ManagedIdentity' -Text 'Managed Identity' -Variant $managedIdentityVariant -OnClick {
                                    Set-CIEMAuthenticationProfileFormContent -Provider 'Azure' -Method 'ManagedIdentity'
                                }
                            }
                            elseif ($Provider -eq 'AWS') {
                                $currentProfileVariant = if ('CurrentProfile' -eq $Method) { 'contained' } else { 'outlined' }
                                $accessKeyVariant = if ('AccessKey' -eq $Method) { 'contained' } else { 'outlined' }
                                New-UDButton -Id 'authProfileMethodOption_CurrentProfile' -Text 'Current Profile' -Variant $currentProfileVariant -OnClick {
                                    Set-CIEMAuthenticationProfileFormContent -Provider 'AWS' -Method 'CurrentProfile'
                                }
                                New-UDButton -Id 'authProfileMethodOption_AccessKey' -Text 'Access Key' -Variant $accessKeyVariant -OnClick {
                                    Set-CIEMAuthenticationProfileFormContent -Provider 'AWS' -Method 'AccessKey'
                                }
                            }
                            elseif ($Provider -eq 'Email') {
                                $smtpAnonymousVariant = if ('SmtpAnonymous' -eq $Method) { 'contained' } else { 'outlined' }
                                $smtpBasicVariant = if ('SmtpBasic' -eq $Method) { 'contained' } else { 'outlined' }
                                New-UDButton -Id 'authProfileMethodOption_SmtpAnonymous' -Text 'SMTP Anonymous' -Variant $smtpAnonymousVariant -OnClick {
                                    Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpAnonymous'
                                }
                                New-UDButton -Id 'authProfileMethodOption_SmtpBasic' -Text 'SMTP Basic' -Variant $smtpBasicVariant -OnClick {
                                    Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpBasic'
                                }
                            }
                            else {
                                throw "No authentication profile method buttons are configured for provider '$Provider'."
                            }
                        }
                    }
                    New-UDGrid -Item -ExtraSmallSize 12 -Content {
                        New-CIEMAuthenticationProfileFieldControls -Provider $Provider -Method $Method -SelectedProfileId $SelectedProfileId
                    }
                }
            }
        }
    }
    if ($providerSelected -and $methodSelected) {
        New-UDButton -Id 'saveAuthenticationProfileBtn' -Text 'Save Profile' -Variant 'contained' -OnClick {
            try {
                $profileId = if ($Page:SelectedAuthenticationProfileId) { [string]$Page:SelectedAuthenticationProfileId } else { [guid]::NewGuid().ToString() }
                $profileName = [string](Get-UDElement -Id 'authProfileName').value
                $provider = [string]$Page:AuthenticationProfileProvider
                $method = [string]$Page:AuthenticationProfileMethod
                if ([string]::IsNullOrWhiteSpace($provider)) {
                    throw 'Authentication profile form did not submit a provider value.'
                }
                if ([string]::IsNullOrWhiteSpace($method)) {
                    throw 'Authentication profile form did not submit a method value.'
                }
                $fieldSchema = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema -Provider $provider -Method $method | Select-Object -First 1)
                $existingProfile = if ($Page:SelectedAuthenticationProfileId) {
                    @(Devolutions.CIEM\Get-CIEMAuthenticationProfile -Id $profileId) | Select-Object -First 1
                }

                $settings = @{}
                $secretRefs = @{}

                foreach ($field in @($fieldSchema.fields)) {
                    $fieldName = [string]$field.name
                    $inputId = "authProfileField_${provider}_${method}_$fieldName"
                    if ($field.kind -eq 'setting') {
                        $fieldElement = Get-UDElement -Id $inputId
                        if ($null -eq $fieldElement) {
                            throw "Authentication profile form did not render field '$inputId'."
                        }
                        $value = $fieldElement.value
                        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                            $settings[$fieldName] = $value
                        }
                    }
                    elseif ($field.kind -eq 'secret') {
                        $secretName = "CIEM_AuthProfile_${profileId}_$fieldName"
                        $existingSecretRef = if ($existingProfile -and $existingProfile.Provider -eq $provider -and $existingProfile.Method -eq $method -and $existingProfile.SecretRefs.PSObject.Properties[$fieldName]) {
                            [string]$existingProfile.SecretRefs.$fieldName
                        }
                        if ($field.inputType -eq 'upload') {
                            if ($Page:UploadedAuthProfileSecretFiles.ContainsKey($fieldName)) {
                                Devolutions.CIEM\Set-CIEMSecret $secretName ([string]$Page:UploadedAuthProfileSecretFiles[$fieldName].Data)
                                $secretRefs[$fieldName] = $secretName
                            }
                            elseif (-not [string]::IsNullOrWhiteSpace($existingSecretRef)) {
                                $secretRefs[$fieldName] = $existingSecretRef
                            }
                        }
                        else {
                            $secretValue = [string](Get-UDElement -Id $inputId).value
                            if (-not [string]::IsNullOrWhiteSpace($secretValue) -and $secretValue -ne '********') {
                                Devolutions.CIEM\Set-CIEMSecret $secretName $secretValue
                                $secretRefs[$fieldName] = $secretName
                            }
                            elseif (-not [string]::IsNullOrWhiteSpace($existingSecretRef)) {
                                $secretRefs[$fieldName] = $existingSecretRef
                            }
                        }
                    }
                    else {
                        throw "Unsupported authentication profile field kind '$($field.kind)'."
                    }
                }

                $savedProfile = Devolutions.CIEM\Save-CIEMAuthenticationProfile -Id $profileId -Name $profileName -Provider $provider -Method $method -Settings $settings -SecretRefs $secretRefs
                $Page:SelectedAuthenticationProfileId = $savedProfile.Id
                $Page:UploadedAuthProfileSecretFiles = @{}
                Sync-UDElement -Id 'authProfileListRegion'
                Set-UDElement -Id 'authenticationProfileForm' -Content {
                    New-CIEMAuthenticationProfileFormContent `
                        -Provider ([string]$Page:AuthenticationProfileProvider) `
                        -Method ([string]$Page:AuthenticationProfileMethod) `
                        -Name ([string]$profileName) `
                        -SelectedProfileId $Page:SelectedAuthenticationProfileId
                }
                Sync-UDElement -Id 'authProfileAssignmentsRegion'
                Sync-UDElement -Id 'authProfileActionsRegion'
                Show-UDToast -Message 'Authentication profile saved.' -Duration 5000 -BackgroundColor '#4caf50'
            }
            catch {
                Devolutions.CIEM\Write-CIEMLog -Message "Authentication profile save failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-AuthenticationProfilesPage'
                Show-UDToast -Message "Authentication profile save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
            }
        }
    }
}

function New-CIEMAuthenticationProfilesPage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'Authentication Profiles' -Url '/ciem/authentication-profiles' -Content {
        if (-not $Page:UploadedAuthProfileSecretFiles) {
            $Page:UploadedAuthProfileSecretFiles = @{}
        }
        New-UDTypography -Text 'Authentication Profiles' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }

        New-UDGrid -Container -Spacing 2 -Content {
            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 4 -Content {
                New-UDElement -Tag 'div' -Id 'authProfileListPane' -Content {
                    New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                        New-UDTextbox -Id 'authProfileSearch' -Label 'Search' -FullWidth -OnChange {
                            Sync-UDElement -Id 'authProfileListRegion'
                        }
                        New-UDButton -Id 'newAuthenticationProfileBtn' -Icon (New-UDIcon -Icon 'Plus') -Variant 'outlined' -OnClick {
                            $fieldSchemas = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema)
                            $hasEditorState = $Page:AuthenticationProfileProvider -and $Page:AuthenticationProfileMethod
                            $Page:SelectedAuthenticationProfileId = $null
                            $Page:AuthenticationProfileName = $null
                            $Page:AuthenticationProfileProvider = ''
                            $Page:AuthenticationProfileMethod = ''
                            $Page:UploadedAuthProfileSecretFiles = @{}
                            Sync-UDElement -Id 'authProfileListRegion'
                            if ($hasEditorState) {
                                Set-UDElement -Id 'authenticationProfileForm' -Content {
                                    New-CIEMAuthenticationProfileFormContent `
                                        -Provider ([string]$Page:AuthenticationProfileProvider) `
                                        -Method ([string]$Page:AuthenticationProfileMethod) `
                                        -Name '' `
                                        -SelectedProfileId $null
                                }
                            }
                            else {
                                Sync-UDElement -Id 'authProfileDetailsRegion'
                            }
                            Sync-UDElement -Id 'authProfileActionsRegion'
                            Sync-UDElement -Id 'authProfileAssignmentsRegion'
                        }
                    }

                    New-UDDynamic -Id 'authProfileListRegion' -Content {
                        $profiles = @(Devolutions.CIEM\Get-CIEMAuthenticationProfile)
                        $search = [string](Get-UDElement -Id 'authProfileSearch').value
                        if (-not [string]::IsNullOrWhiteSpace($search)) {
                            $profiles = @($profiles | Where-Object {
                                $_.Name -like "*$search*" -or $_.Provider -like "*$search*" -or $_.Method -like "*$search*"
                            })
                        }

                        if ($profiles.Count -eq 0) {
                            New-UDTypography -Text 'No authentication profiles.' -Variant 'body2' -Style @{ color = '#666'; marginTop = '16px' }
                        }
                        else {
                            foreach ($profile in $profiles) {
                                $editProfileId = [string]$profile.Id
                                $editHandler = [scriptblock]::Create(@"
`$selectedId = '$editProfileId'
`$selected = @(Devolutions.CIEM\Get-CIEMAuthenticationProfile -Id `$selectedId) | Select-Object -First 1
`$Page:SelectedAuthenticationProfileId = `$selectedId
`$Page:AuthenticationProfileName = [string]`$selected.Name
`$Page:AuthenticationProfileProvider = [string]`$selected.Provider
`$Page:AuthenticationProfileMethod = [string]`$selected.Method
`$Page:UploadedAuthProfileSecretFiles = @{}
Sync-UDElement -Id 'authProfileListRegion'
Sync-UDElement -Id 'authProfileDetailsRegion'
Sync-UDElement -Id 'authProfileActionsRegion'
Sync-UDElement -Id 'authProfileAssignmentsRegion'
"@)

                                New-UDCard -Id "authProfileCard_$editProfileId" -Title $profile.Name -OnClick $editHandler -Content {
                                    New-UDStack -Direction 'row' -Spacing 1 -Content {
                                        New-UDChip -Label $profile.Provider -Size 'small'
                                        New-UDChip -Label $profile.Method -Size 'small'
                                    }
                                    if (@($profile.AppliesTo).Count -gt 0) {
                                        New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '8px' } } -Content {
                                            New-UDStack -Direction 'row' -Spacing 1 -Content {
                                                foreach ($appliesTo in @($profile.AppliesTo)) {
                                                    New-UDChip -Label $appliesTo -Size 'small'
                                                }
                                            }
                                        }
                                    }
                                    New-UDButton -Text 'Edit' -Variant 'text' -OnClick $editHandler
                                }
                            }
                        }
                    }
                }
            }

            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 8 -Content {
                New-UDElement -Tag 'div' -Id 'authProfileDetailsPane' -Content {
                    New-UDDynamic -Id 'authProfileDetailsRegion' -Content {
                        $profiles = @(Devolutions.CIEM\Get-CIEMAuthenticationProfile)
                        $selectedProfile = if ($Page:SelectedAuthenticationProfileId) {
                            $profiles | Where-Object Id -eq $Page:SelectedAuthenticationProfileId | Select-Object -First 1
                        }
                        $shouldRenderProfileEditor = $selectedProfile -or ($null -ne $Page:AuthenticationProfileProvider -and $null -ne $Page:AuthenticationProfileMethod)
                        if ($shouldRenderProfileEditor) {
                            $selectedProvider = if ($null -ne $Page:AuthenticationProfileProvider) { [string]$Page:AuthenticationProfileProvider } else { [string]$selectedProfile.Provider }
                            $selectedMethod = if ($null -ne $Page:AuthenticationProfileMethod) { [string]$Page:AuthenticationProfileMethod } else { [string]$selectedProfile.Method }
                            $selectedName = if ($Page:AuthenticationProfileName) { [string]$Page:AuthenticationProfileName } elseif ($selectedProfile) { [string]$selectedProfile.Name } else { '' }
                            if (-not [string]::IsNullOrWhiteSpace($selectedProvider)) {
                                $providerSchemas = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema -Provider $selectedProvider)
                                if (-not [string]::IsNullOrWhiteSpace($selectedMethod) -and @($providerSchemas.method) -notcontains $selectedMethod) {
                                    $selectedMethod = [string]$providerSchemas[0].method
                                }
                            }
                            $Page:AuthenticationProfileProvider = $selectedProvider
                            $Page:AuthenticationProfileMethod = $selectedMethod
                            $Page:AuthenticationProfileName = $selectedName

                            New-UDElement -Tag 'div' -Id 'authenticationProfileForm' -Content {
                                New-CIEMAuthenticationProfileFormContent `
                                    -Provider $selectedProvider `
                                    -Method $selectedMethod `
                                    -Name $selectedName `
                                    -SelectedProfileId $Page:SelectedAuthenticationProfileId
                            }
                        }
                    }

                    New-UDDynamic -Id 'authProfileActionsRegion' -Content {
                        $selectedProfile = if ($Page:SelectedAuthenticationProfileId) {
                            @(Devolutions.CIEM\Get-CIEMAuthenticationProfile -Id ([string]$Page:SelectedAuthenticationProfileId)) | Select-Object -First 1
                        }

                        if ($selectedProfile -and $selectedProfile.Provider -in @('Azure', 'AWS')) {
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '24px' } } -Content {
                                New-UDButton -Id 'testAuthenticationProfileBtn' -Text 'Test Authentication' -Variant 'outlined' -ShowLoading -OnClick {
                                    try {
                                        $testProfile = @(Devolutions.CIEM\Get-CIEMAuthenticationProfile -Id $selectedProfile.Id -ResolveSecrets) | Select-Object -First 1
                                        Devolutions.CIEM\Connect-CIEM -Provider $testProfile.Provider -AuthenticationProfile $testProfile -Force | Out-Null
                                        Show-UDToast -Message "Authentication test succeeded for $($selectedProfile.Name)." -Duration 5000 -BackgroundColor '#4caf50'
                                    }
                                    catch {
                                        Show-UDToast -Message "Authentication test failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                                    }
                                }
                            }
                        }
                    }

                    New-UDDynamic -Id 'authProfileAssignmentsRegion' -Content {
                        $selectedProfile = if ($Page:SelectedAuthenticationProfileId) {
                            @(Devolutions.CIEM\Get-CIEMAuthenticationProfile -Id ([string]$Page:SelectedAuthenticationProfileId)) | Select-Object -First 1
                        }

                        if ($selectedProfile) {
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '24px' } } -Content {
                                New-UDTypography -Text 'Assignments' -Variant 'h6'
                                if ($selectedProfile.Provider -in @('Azure', 'AWS')) {
                                    New-UDButton -Id 'assignProviderDiscoveryBtn' -Text 'Assign to Provider Discovery' -Variant 'outlined' -OnClick {
                                        try {
                                            Devolutions.CIEM\Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId $selectedProfile.Provider -AuthenticationProfileId $selectedProfile.Id | Out-Null
                                            Sync-UDElement -Id 'authProfileListRegion'
                                            Sync-UDElement -Id 'authProfileAssignmentsRegion'
                                            Show-UDToast -Message 'Assignment saved.' -Duration 5000 -BackgroundColor '#4caf50'
                                        }
                                        catch {
                                            Show-UDToast -Message "Assignment failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                                        }
                                    }
                                }
                                if ($selectedProfile.Provider -eq 'Email') {
                                    New-UDButton -Id 'assignEmailNotificationBtn' -Text 'Assign to Email Notifications' -Variant 'outlined' -OnClick {
                                        try {
                                            Devolutions.CIEM\Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $selectedProfile.Id | Out-Null
                                            Sync-UDElement -Id 'authProfileListRegion'
                                            Sync-UDElement -Id 'authProfileAssignmentsRegion'
                                            Show-UDToast -Message 'Assignment saved.' -Duration 5000 -BackgroundColor '#4caf50'
                                        }
                                        catch {
                                            Show-UDToast -Message "Assignment failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                                        }
                                    }
                                }

                                New-UDButton -Id 'removeAuthenticationProfileBtn' -Text 'Remove' -Variant 'outlined' -Color 'secondary' -OnClick {
                                    try {
                                        Devolutions.CIEM\Remove-CIEMAuthenticationProfile -Id $selectedProfile.Id
                                        $Page:SelectedAuthenticationProfileId = $null
                                        Sync-UDElement -Id 'authProfileListRegion'
                                        Sync-UDElement -Id 'authProfileDetailsRegion'
                                        Sync-UDElement -Id 'authProfileActionsRegion'
                                        Sync-UDElement -Id 'authProfileAssignmentsRegion'
                                        Show-UDToast -Message 'Authentication profile removed.' -Duration 5000 -BackgroundColor '#4caf50'
                                    }
                                    catch {
                                        Show-UDToast -Message "Remove failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
