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
            $hasSchemaDefault = $field.PSObject.Properties.Name -contains 'defaultValue'
            $renderedValue = if ($null -ne $existingValue) { $existingValue } elseif ($hasSchemaDefault) { $field.defaultValue } else { '' }
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

                Devolutions.CIEM\Save-CIEMAuthenticationProfile -Id $profileId -Name $profileName -Provider $provider -Method $method -Settings $settings -SecretRefs $secretRefs | Out-Null
                $Page:SelectedAuthenticationProfileId = $profileId
                $Page:UploadedAuthProfileSecretFiles = @{}
                Hide-UDModal
                Sync-UDElement -Id 'authenticationProfilesTableRegion'
                Show-UDToast -Message 'Authentication profile saved.' -Duration 5000 -BackgroundColor '#4caf50'
            }
            catch {
                Devolutions.CIEM\Write-CIEMLog -Message "Authentication profile save failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                Show-UDToast -Message "Authentication profile save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
            }
        }
    }
}

function Show-CIEMAuthenticationProfileDetailsModal {
    [CmdletBinding()]
    param(
        [string]$SelectedProfileId
    )

    $ErrorActionPreference = 'Stop'

    $selectedProfile = if ($SelectedProfileId) {
        @(Devolutions.CIEM\Get-CIEMAuthenticationProfile -Id $SelectedProfileId) | Select-Object -First 1
    }

    if ($selectedProfile) {
        $Page:SelectedAuthenticationProfileId = [string]$selectedProfile.Id
        $Page:AuthenticationProfileName = [string]$selectedProfile.Name
        $Page:AuthenticationProfileProvider = [string]$selectedProfile.Provider
        $Page:AuthenticationProfileMethod = [string]$selectedProfile.Method
    }
    else {
        $Page:SelectedAuthenticationProfileId = $null
        $Page:AuthenticationProfileName = $null
        $Page:AuthenticationProfileProvider = ''
        $Page:AuthenticationProfileMethod = ''
    }
    $Page:UploadedAuthProfileSecretFiles = @{}

    Show-UDModal -Header {
        New-UDTypography -Text 'Authentication Profile Details' -Variant 'h6'
    } -Content {
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

        if ($selectedProfile) {
            New-UDElement -Tag 'div' -Attributes @{ style = @{ marginTop = '24px' } } -Content {
                New-UDTypography -Text 'Assignments' -Variant 'h6'
                New-UDStack -Direction 'row' -Spacing 1 -Content {
                    if ($selectedProfile.Provider -in @('Azure', 'AWS')) {
                        New-UDButton -Id 'assignProviderDiscoveryBtn' -Text 'Assign to Provider Discovery' -Variant 'outlined' -OnClick {
                            try {
                                Devolutions.CIEM\Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId $selectedProfile.Provider -AuthenticationProfileId $selectedProfile.Id | Out-Null
                                Sync-UDElement -Id 'authenticationProfilesTableRegion'
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
                                Sync-UDElement -Id 'authenticationProfilesTableRegion'
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
                            Hide-UDModal
                            Sync-UDElement -Id 'authenticationProfilesTableRegion'
                            Show-UDToast -Message 'Authentication profile removed.' -Duration 5000 -BackgroundColor '#4caf50'
                        }
                        catch {
                            Show-UDToast -Message "Remove failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                        }
                    }
                }
            }
        }
    } -Footer {
        New-UDButton -Id 'cancelAuthenticationProfileEditBtn' -Text 'Cancel' -Variant 'outlined' -OnClick {
            Hide-UDModal
        }
    } -FullWidth -MaxWidth 'md' -Persistent
}

function New-CIEMConfigPage {
    <#
    .SYNOPSIS
        Creates the CIEM Configuration page.
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
        New-UDTypography -Text 'Configuration' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }
        New-UDTypography -Text 'Configure authentication profiles, scheduled discovery, and outbound notifications' -Variant 'subtitle1' -Style @{ marginBottom = '30px'; color = '#666' }

        New-UDCard -Title 'Authentication Profiles' -Content {
            New-UDStack -Direction 'row' -Spacing 1 -AlignItems 'center' -Content {
                New-UDTextbox -Id 'authProfileSearch' -Label 'Search' -FullWidth -OnChange {
                    Sync-UDElement -Id 'authenticationProfilesTableRegion'
                }
                New-UDButton -Id 'newAuthenticationProfileBtn' -Text 'Add Profile' -Variant 'outlined' -Color 'primary' -OnClick {
                    Show-CIEMAuthenticationProfileDetailsModal
                }
            }

            New-UDDynamic -Id 'authenticationProfilesTableRegion' -Content {
                $profiles = @(Devolutions.CIEM\Get-CIEMAuthenticationProfile)
                $searchElement = Get-UDElement -Id 'authProfileSearch'
                $search = if ($searchElement) { [string]$searchElement.value } else { '' }
                if (-not [string]::IsNullOrWhiteSpace($search)) {
                    $profiles = @($profiles | Where-Object {
                        $_.Name -like "*$search*" -or $_.Provider -like "*$search*" -or $_.Method -like "*$search*"
                    })
                }

                $profileRows = @(foreach ($profile in $profiles) {
                    [PSCustomObject]@{
                        Id        = [string]$profile.Id
                        Name      = [string]$profile.Name
                        Provider  = [string]$profile.Provider
                        Method    = [string]$profile.Method
                        AppliesTo = (@($profile.AppliesTo) -join ', ')
                        UpdatedAt = [string]$profile.UpdatedAt
                    }
                })

                New-UDTable -Id 'authenticationProfilesTable' -Data $profileRows -Columns @(
                    New-UDTableColumn -Property 'Name' -Title 'Name'
                    New-UDTableColumn -Property 'Provider' -Title 'Provider'
                    New-UDTableColumn -Property 'Method' -Title 'Method'
                    New-UDTableColumn -Property 'AppliesTo' -Title 'Assignments'
                    New-UDTableColumn -Property 'Actions' -Title 'Actions' -Render {
                        New-UDButton -Id "editAuthenticationProfile_$($EventData.Id)" -Text 'Edit' -Variant 'outlined' -OnClick {
                            Show-CIEMAuthenticationProfileDetailsModal -SelectedProfileId ([string]$EventData.Id)
                        }
                    }
                ) -Dense -OnRowExpand {
                    New-UDStack -Spacing 1 -Content {
                        New-UDTypography -Text "Id: $($EventData.Id)" -Variant 'caption'
                        New-UDTypography -Text "Provider: $($EventData.Provider)" -Variant 'caption'
                        New-UDTypography -Text "Method: $($EventData.Method)" -Variant 'caption'
                        New-UDTypography -Text "Assignments: $($EventData.AppliesTo)" -Variant 'caption'
                        New-UDTypography -Text "Updated: $($EventData.UpdatedAt)" -Variant 'caption'
                    }
                }
            }
        } -Style @{ marginTop = '24px' }

        New-UDElement -Tag 'div' -Id 'scheduledDiscoveryWrapper' -Content {
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
            }
        }

        New-UDCard -Title 'Notification Channels' -Content {
            New-UDElement -Tag 'div' -Id 'availableNotificationChannelTypes' -Attributes @{ style = @{ marginBottom = '18px' } } -Content {
                New-UDTypography -Text 'Available Channel Types' -Variant 'subtitle2' -Style @{ marginBottom = '8px'; color = '#555' }
                New-UDStack -Direction 'row' -Spacing 1 -Content {
                    New-UDButton -Id 'addEmailNotificationChannelBtn' -Text 'Add Email Channel' -Variant 'outlined' -Color 'primary' -OnClick {
                        $notificationChannel = @(Devolutions.CIEM\Get-CIEMNotificationChannel -Id 'email-default') | Select-Object -First 1

                        Set-UDElement -Id 'notificationChannelEditorPane' -Content {
                            New-UDElement -Tag 'div' -Attributes @{ style = @{ border = '1px solid #d7dde5'; borderRadius = '6px'; padding = '16px'; marginBottom = '18px'; backgroundColor = '#fafbfc' } } -Content {
                                New-UDTypography -Text 'Email Channel' -Variant 'h6' -Style @{ marginBottom = '12px' }
                                New-UDGrid -Container -Spacing 2 -Content {
                                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                        New-UDTextbox -Id 'notificationFromAddress' -Label 'From Address' -Value $notificationChannel.FromAddress -FullWidth -Placeholder 'ciem@example.com'
                                    }
                                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                        New-UDTextbox -Id 'notificationToRecipients' -Label 'To Recipients' -Value (@($notificationChannel.ToRecipients) -join ', ') -FullWidth -Placeholder 'security@example.com, it@example.com'
                                    }
                                }
                                New-UDStack -Direction 'row' -Spacing 2 -Content {
                                    New-UDButton -Id 'saveNotificationsBtn' -Text 'Save' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                                        try {
                                            $parseRecipients = {
                                                param([string]$RecipientText)
                                                if ([string]::IsNullOrWhiteSpace($RecipientText)) { return }
                                                foreach ($recipient in ($RecipientText -split ',')) {
                                                    $trimmedRecipient = $recipient.Trim()
                                                    if (-not [string]::IsNullOrWhiteSpace($trimmedRecipient)) { $trimmedRecipient }
                                                }
                                            }

                                            $toRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationToRecipients').value))

                                            Devolutions.CIEM\Set-CIEMNotificationChannel `
                                                -Enabled $true `
                                                -FromAddress ([string](Get-UDElement -Id 'notificationFromAddress').value) `
                                                -ToRecipients $toRecipients | Out-Null

                                            Set-UDElement -Id 'notificationChannelEditorPane' -Content {}
                                            Sync-UDElement -Id 'notificationChannelsTableRegion'
                                            Show-UDToast -Message 'Notifications saved.' -Duration 5000 -BackgroundColor '#4caf50'
                                        }
                                        catch {
                                            Devolutions.CIEM\Write-CIEMLog -Message "Save notifications failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                            Show-UDToast -Message "Notification save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                                        }
                                    }
                                    New-UDButton -Id 'cancelNotificationChannelEditBtn' -Text 'Cancel' -Variant 'outlined' -OnClick {
                                        Set-UDElement -Id 'notificationChannelEditorPane' -Content {}
                                    }
                                }
                            }
                        }
                    }
                }
            }

            New-UDElement -Tag 'div' -Id 'notificationChannelEditorPane'

            New-UDDynamic -Id 'notificationChannelsTableRegion' -Content {
                $channels = @(Devolutions.CIEM\Get-CIEMNotificationChannel)
                $channelRows = @(foreach ($channel in $channels) {
                    [PSCustomObject]@{
                        Id            = [string]$channel.Id
                        Name          = [string]$channel.Name
                        Type          = [string]$channel.Type
                        Enabled       = [bool]$channel.Enabled
                        Status        = if ($channel.Enabled) { 'Enabled' } else { 'Disabled' }
                        From          = [string]$channel.FromAddress
                        Recipients    = (@($channel.ToRecipients) -join ', ')
                        CcRecipients  = (@($channel.CcRecipients) -join ', ')
                        BccRecipients = (@($channel.BccRecipients) -join ', ')
                        UpdatedAt     = [string]$channel.UpdatedAt
                    }
                })

                New-UDTable -Id 'notificationChannelsTable' -Data $channelRows -Columns @(
                    New-UDTableColumn -Property 'Name' -Title 'Channel'
                    New-UDTableColumn -Property 'Type' -Title 'Type'
                    New-UDTableColumn -Property 'Status' -Title 'Status'
                    New-UDTableColumn -Property 'From' -Title 'From'
                    New-UDTableColumn -Property 'Recipients' -Title 'Recipients'
                    New-UDTableColumn -Property 'Actions' -Title 'Actions' -Render {
                        New-UDButton -Id "editNotificationChannel_$($EventData.Id)" -Text 'Edit' -Variant 'outlined' -OnClick {
                            $notificationChannel = @(Devolutions.CIEM\Get-CIEMNotificationChannel -Id $EventData.Id) | Select-Object -First 1

                            Show-UDModal -Header {
                                New-UDTypography -Text 'Notification Channel Details' -Variant 'h6'
                            } -Content {
                                New-UDGrid -Container -Spacing 2 -Content {
                                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 3 -Content {
                                        New-UDSwitch -Id 'notificationChannelEnabled' -Label 'Enabled' -Checked ([bool]$notificationChannel.Enabled)
                                    }
                                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 9 -Content {
                                        New-UDTextbox -Id 'notificationFromAddress' -Label 'From Address' -Value $notificationChannel.FromAddress -FullWidth -Placeholder 'ciem@example.com'
                                    }
                                    New-UDGrid -Item -ExtraSmallSize 12 -Content {
                                        New-UDTextbox -Id 'notificationToRecipients' -Label 'To Recipients' -Value (@($notificationChannel.ToRecipients) -join ', ') -FullWidth -Placeholder 'security@example.com, it@example.com'
                                    }
                                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                        New-UDTextbox -Id 'notificationCcRecipients' -Label 'Cc Recipients' -Value (@($notificationChannel.CcRecipients) -join ', ') -FullWidth -Placeholder 'manager@example.com'
                                    }
                                    New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                                        New-UDTextbox -Id 'notificationBccRecipients' -Label 'Bcc Recipients' -Value (@($notificationChannel.BccRecipients) -join ', ') -FullWidth -Placeholder 'audit@example.com'
                                    }
                                }
                            } -Footer {
                                New-UDStack -Direction 'row' -Spacing 2 -Content {
                                    New-UDButton -Id 'saveNotificationsBtn' -Text 'Save' -Variant 'contained' -Color 'primary' -ShowLoading -OnClick {
                                        try {
                                            $parseRecipients = {
                                                param([string]$RecipientText)
                                                if ([string]::IsNullOrWhiteSpace($RecipientText)) { return }
                                                foreach ($recipient in ($RecipientText -split ',')) {
                                                    $trimmedRecipient = $recipient.Trim()
                                                    if (-not [string]::IsNullOrWhiteSpace($trimmedRecipient)) { $trimmedRecipient }
                                                }
                                            }

                                            $toRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationToRecipients').value))
                                            $ccRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationCcRecipients').value))
                                            $bccRecipients = [string[]]@(& $parseRecipients ([string](Get-UDElement -Id 'notificationBccRecipients').value))

                                            Devolutions.CIEM\Set-CIEMNotificationChannel `
                                                -Enabled ([bool](Get-UDElement -Id 'notificationChannelEnabled').checked) `
                                                -FromAddress ([string](Get-UDElement -Id 'notificationFromAddress').value) `
                                                -ToRecipients $toRecipients `
                                                -CcRecipients $ccRecipients `
                                                -BccRecipients $bccRecipients | Out-Null

                                            Hide-UDModal
                                            Sync-UDElement -Id 'notificationChannelsTableRegion'
                                            Show-UDToast -Message 'Notifications saved.' -Duration 5000 -BackgroundColor '#4caf50'
                                        }
                                        catch {
                                            Devolutions.CIEM\Write-CIEMLog -Message "Save notifications failed: $($_.Exception.Message)" -Severity ERROR -Component 'PSU-ConfigPage'
                                            Show-UDToast -Message "Notification save failed: $($_.Exception.Message)" -Duration 10000 -BackgroundColor '#f44336'
                                        }
                                    }
                                    New-UDButton -Id 'cancelNotificationChannelEditBtn' -Text 'Cancel' -Variant 'outlined' -OnClick {
                                        Hide-UDModal
                                    }
                                }
                            } -FullWidth -MaxWidth 'md' -Persistent
                        }
                    }
                ) -Dense -OnRowExpand {
                    New-UDStack -Spacing 1 -Content {
                        New-UDTypography -Text "Status: $($EventData.Status)" -Variant 'caption'
                        New-UDTypography -Text "Cc: $($EventData.CcRecipients)" -Variant 'caption'
                        New-UDTypography -Text "Bcc: $($EventData.BccRecipients)" -Variant 'caption'
                        New-UDTypography -Text "Updated: $($EventData.UpdatedAt)" -Variant 'caption'
                    }
                }
            }
        } -Style @{ marginTop = '24px' }
    } -Navigation $Navigation -NavigationLayout permanent
}
