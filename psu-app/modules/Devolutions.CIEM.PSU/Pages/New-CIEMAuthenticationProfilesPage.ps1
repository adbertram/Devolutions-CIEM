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
            $renderedValue = $existingValue
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
                    New-UDTextbox -Id $inputId -Label $field.label -Type $fieldType -FullWidth
                    if ($null -ne $renderedValue) {
                        Set-UDElement -Id $inputId -Properties @{ value = $renderedValue }
                    }
                }
                else {
                    $value = if ($currentSelectedProfile -and $currentSelectedProfile.Provider -eq $schemaProvider -and $currentSelectedProfile.Method -eq $schemaMethod -and $field.kind -eq 'secret' -and $currentSelectedProfile.SecretRefs.$fieldName) { '********' } else { $existingValue }
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
                            $Page:SelectedAuthenticationProfileId = $null
                            $Page:AuthenticationProfileName = $null
                            $Page:AuthenticationProfileProvider = [string]$fieldSchemas[0].provider
                            $Page:AuthenticationProfileMethod = [string]$fieldSchemas[0].method
                            $Page:UploadedAuthProfileSecretFiles = @{}
                            Set-UDElement -Id 'authProfileName' -Properties @{ value = '' }
                            Set-UDElement -Id 'authProfileProvider' -Properties @{ value = [string]$fieldSchemas[0].provider }
                            Sync-UDElement -Id 'authProfileListRegion'
                            Sync-UDElement -Id 'authProfileDetailsRegion'
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
Set-UDElement -Id 'authProfileName' -Properties @{ value = [string]`$selected.Name }
Set-UDElement -Id 'authProfileProvider' -Properties @{ value = [string]`$selected.Provider }
Sync-UDElement -Id 'authProfileListRegion'
Sync-UDElement -Id 'authProfileDetailsRegion'
Sync-UDElement -Id 'authProfileAssignmentsRegion'
"@)

                                New-UDCard -Title $profile.Name -Content {
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
                        $fieldSchemas = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema)
                        $selectedProvider = if ($Page:AuthenticationProfileProvider) { [string]$Page:AuthenticationProfileProvider } elseif ($selectedProfile) { [string]$selectedProfile.Provider } else { [string]$fieldSchemas[0].provider }
                        $selectedMethod = if ($Page:AuthenticationProfileMethod) { [string]$Page:AuthenticationProfileMethod } elseif ($selectedProfile) { [string]$selectedProfile.Method } else { [string]$fieldSchemas[0].method }
                        $selectedName = if ($Page:AuthenticationProfileName) { [string]$Page:AuthenticationProfileName } elseif ($selectedProfile) { [string]$selectedProfile.Name } else { '' }
                        $providerSchemas = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema -Provider $selectedProvider)
                        if (@($providerSchemas.method) -notcontains $selectedMethod) {
                            $selectedMethod = [string]$providerSchemas[0].method
                        }
                        $Page:AuthenticationProfileProvider = $selectedProvider
                        $Page:AuthenticationProfileMethod = $selectedMethod
                        $Page:AuthenticationProfileName = $selectedName

                        New-UDElement -Tag 'div' -Id 'authenticationProfileForm' -Content {
                            New-UDGrid -Container -Spacing 2 -Content {
                                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                    New-UDTextbox -Id 'authProfileName' -Label 'Name' -Value $selectedName -FullWidth -OnChange {
                                        $Page:AuthenticationProfileName = [string]$EventData
                                    }
                                }
                                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                    New-UDTypography -Text 'Provider' -Variant 'caption'
                                    New-UDElement -Tag 'input' -Id 'authProfileProvider' -Attributes @{ type = 'hidden'; value = $selectedProvider }
                                    New-UDStack -Direction 'row' -Spacing 1 -Content {
                                        foreach ($provider in @($fieldSchemas.provider | Sort-Object -Unique)) {
                                            $providerValue = [string]$provider
                                            $providerSchemasForOption = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema -Provider $providerValue)
                                            if ($providerSchemasForOption.Count -eq 0) {
                                                throw "No authentication profile methods are configured for provider '$providerValue'."
                                            }
                                            $defaultMethod = [string]$providerSchemasForOption[0].method
                                            $providerButtonVariant = if ($providerValue -eq $selectedProvider) { 'contained' } else { 'outlined' }
                                            $providerHandler = [scriptblock]::Create(@"
`$Page:AuthenticationProfileProvider = '$providerValue'
`$Page:AuthenticationProfileMethod = '$defaultMethod'
Sync-UDElement -Id 'authProfileMethodAndFieldsRegion'
"@)
                                            New-UDButton -Id "authProfileProviderOption_$providerValue" -Text $providerValue -Variant $providerButtonVariant -OnClick $providerHandler
                                        }
                                    }
                                }
                                New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                    New-UDDynamic -Id 'authProfileMethodAndFieldsRegion' -Content {
                                        New-UDGrid -Container -Spacing 2 -Content {
                                            New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                                New-UDTypography -Text 'Method' -Variant 'caption'
                                                $currentProvider = [string]$Page:AuthenticationProfileProvider
                                                $providerSchemas = @(Devolutions.CIEM\Get-CIEMAuthenticationProfileFieldSchema -Provider $currentProvider)
                                                if ($providerSchemas.Count -eq 0) {
                                                    throw "No authentication profile methods are configured for provider '$currentProvider'."
                                                }
                                                $currentMethod = [string]$Page:AuthenticationProfileMethod
                                                if (@($providerSchemas.method) -notcontains $currentMethod) {
                                                    $currentMethod = [string]$providerSchemas[0].method
                                                }
                                                $Page:AuthenticationProfileMethod = $currentMethod

                                                New-UDElement -Tag 'input' -Id 'authProfileMethod' -Attributes @{ type = 'hidden'; value = $currentMethod }
                                                New-UDStack -Direction 'row' -Spacing 1 -Content {
                                                    foreach ($schema in $providerSchemas) {
                                                        $methodValue = [string]$schema.method
                                                        $methodLabel = [string]$schema.displayName
                                                        $buttonVariant = if ($methodValue -eq $currentMethod) { 'contained' } else { 'outlined' }
                                                        $methodHandler = [scriptblock]::Create(@"
`$Page:AuthenticationProfileMethod = '$methodValue'
Sync-UDElement -Id 'authProfileFieldsRegion'
"@)
                                                        New-UDButton -Id "authProfileMethodOption_$methodValue" -Text $methodLabel -Variant $buttonVariant -OnClick $methodHandler
                                                    }
                                                }
                                            }
                                            New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                                New-UDDynamic -Id 'authProfileFieldsRegion' -Content {
                                                    New-CIEMAuthenticationProfileFieldControls -Provider ([string]$Page:AuthenticationProfileProvider) -Method ([string]$Page:AuthenticationProfileMethod) -SelectedProfileId $Page:SelectedAuthenticationProfileId
                                                }
                                            }
                                        }
                                    }
                                }
                            }
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
                                Sync-UDElement -Id 'authProfileDetailsRegion'
                                Sync-UDElement -Id 'authProfileAssignmentsRegion'
                                Show-UDToast -Message 'Authentication profile saved.' -Duration 5000 -BackgroundColor '#4caf50'
                            }
                            catch {
                                Devolutions.CIEM\Write-CIEMLog -Message "Authentication profile save failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-AuthenticationProfilesPage'
                                Show-UDToast -Message "Authentication profile save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
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
