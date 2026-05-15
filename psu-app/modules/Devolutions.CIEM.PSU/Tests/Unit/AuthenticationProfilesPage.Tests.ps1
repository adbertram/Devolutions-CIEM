BeforeAll {
    $script:PagesRoot = Join-Path $PSScriptRoot '..' '..' 'Pages'
    $script:PageRegistryPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'pages.json'
    $script:AuthenticationProfilesPagePath = Join-Path $script:PagesRoot 'New-CIEMAuthenticationProfilesPage.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psm1'
    $script:PageRegistry = @(Get-Content -Path $script:PageRegistryPath -Raw | ConvertFrom-Json -Depth 10)
}

Describe 'Authentication Profiles PSU page' {
    It 'registers the Authentication Profiles page in the CIEM page registry' {
        $page = $script:PageRegistry | Where-Object name -eq 'Authentication Profiles'

        $page | Should -Not -BeNullOrEmpty
        $page.route | Should -Be '/authentication-profiles'
        $page.factory | Should -Be 'New-CIEMAuthenticationProfilesPage'
        $page.test.smokeSelector | Should -Be "h4:has-text('Authentication Profiles')"
    }

    It 'defines a split-view page for generic authentication profiles' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match "New-UDPage\s+-Name 'Authentication Profiles'\s+-Url '/ciem/authentication-profiles'"
        $content | Should -Match "New-UDElement\s+-Tag 'div'\s+-Id 'authProfileListPane'"
        $content | Should -Match "New-UDElement\s+-Tag 'div'\s+-Id 'authProfileDetailsPane'"
        $content | Should -Match "New-UDElement\s+-Tag 'div'\s+-Id 'authenticationProfileForm'"
        $content | Should -Match "New-UDButton\s+-Id 'saveAuthenticationProfileBtn'"
        $content | Should -Match 'Devolutions\.CIEM\\Get-CIEMAuthenticationProfile'
        $content | Should -Match 'Devolutions\.CIEM\\Save-CIEMAuthenticationProfile'
        $content | Should -Match 'Devolutions\.CIEM\\Remove-CIEMAuthenticationProfile'
        $content | Should -Match 'Devolutions\.CIEM\\Set-CIEMAuthenticationProfileAssignment'
    }

    It 'uses a data-driven field schema instead of provider switch blocks' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match 'Devolutions\.CIEM\\Get-CIEMAuthenticationProfileFieldSchema'
        $content | Should -Match '\$fieldSchema'
        $content | Should -Not -Match 'switch\s*\(\s*\$Provider\s*\)'
        $content | Should -Not -Match 'switch\s*\(\s*\$selectedProvider\s*\)'
    }

    It 'renders only the selected provider and method schema fields' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match "New-UDElement\s+-Tag 'div'\s+-Id 'authenticationProfileForm'"
        $content | Should -Match 'New-CIEMAuthenticationProfileFormContent'
        $content | Should -Match 'New-CIEMAuthenticationProfileFieldControls'
        $moduleContent = Get-Content -Path $script:ModulePath -Raw
        $moduleContent | Should -Match "New-CIEMAuthenticationProfileFormContent"
        $moduleContent | Should -Match "Set-CIEMAuthenticationProfileFormContent"
        $content | Should -Match 'Get-CIEMAuthenticationProfileFieldSchema\s+-Provider \$Provider\s+-Method \$Method'
        $content | Should -Not -Match 'foreach \(\$schema in \$fieldSchemas\)'
        $content | Should -Not -Match "New-UDDynamic\s+-Id 'authProfileFieldsRegion'"
        $content | Should -Match 'authProfileField_\$\{schemaProvider\}_\$\{schemaMethod\}_\$fieldName'
        $content | Should -Match "New-UDElement\s+-Tag 'input'\s+-Id 'authProfileProvider'"
        $content | Should -Not -Match "New-UDDynamic\s+-Id 'authProfileProviderOptionsRegion'"
        $content | Should -Not -Match 'New-UDElement\s+-Tag ''div''\s+-Id "authProfileProviderOption_\$providerValue"'
        $content | Should -Match 'New-UDButton\s+-Id ''authProfileProviderOption_Azure''\s+-Text ''Azure''\s+-Variant \$azureProviderButtonVariant\s+-OnClick'
        $content | Should -Match 'New-UDButton\s+-Id ''authProfileProviderOption_AWS''\s+-Text ''AWS''\s+-Variant \$awsProviderButtonVariant\s+-OnClick'
        $content | Should -Match 'New-UDButton\s+-Id ''authProfileProviderOption_Email''\s+-Text ''Email''\s+-Variant \$emailProviderButtonVariant\s+-OnClick'
        $content | Should -Match "New-UDElement\s+-Tag 'input'\s+-Id 'authProfileMethod'"
        $content | Should -Match 'authProfileMethodOption_SmtpAnonymous'
        $content | Should -Not -Match "authProfileEditorRegion"
    }

    It 'filters method options by the selected provider and replaces the form content' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match 'Get-CIEMAuthenticationProfileFieldSchema\s+-Provider \$selectedProvider'
        $content | Should -Match 'function Set-CIEMAuthenticationProfileFormContent'
        $content | Should -Match "Set-UDElement -Id 'authenticationProfileForm' -Content"
        $content | Should -Match "New-UDElement\s+-Tag 'input'\s+-Id 'authProfileMethod'"
        $content | Should -Match 'authProfileMethodOption_SmtpAnonymous'
        $content | Should -Not -Match "New-UDDynamic\s+-Id 'authProfileMethodAndFieldsRegion'"
        $content | Should -Not -Match "Sync-UDElement -Id 'authProfileProviderOptionsRegion'"
        $content | Should -Not -Match "Sync-UDElement -Id 'authProfileMethodAndFieldsRegion'"
        $content | Should -Not -Match "Sync-UDElement -Id 'authProfileFieldsRegion'"
        $content | Should -Not -Match "New-UDDynamic\s+-Id 'authProfileProviderRegion'"
        $content | Should -Not -Match "New-UDDynamic\s+-Id 'authProfileSchemaRegion'"
        $content | Should -Not -Match "Sync-UDElement -Id 'authProfileSchemaRegion'"
        $content | Should -Not -Match "New-UDDynamic\s+-Id 'authProfileMethodRegion'"
        $content | Should -Not -Match "Set-UDElement -Id 'authProfileFieldsContainer' -Content"
        $content | Should -Not -Match 'foreach \(\$schema in \$fieldSchemas\)\s*\{\s*New-UDSelectOption'
    }

    It 'does not render the editor before a profile is selected or a draft is started' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match '\$shouldRenderProfileEditor\s*=\s*\$selectedProfile -or \(\$null -ne \$Page:AuthenticationProfileProvider -and \$null -ne \$Page:AuthenticationProfileMethod\)'
        $content | Should -Match 'if \(\$shouldRenderProfileEditor\)'
        $content | Should -Not -Match '\$selectedProvider = if \(\$Page:AuthenticationProfileProvider\).*else \{ \[string\]\$fieldSchemas\[0\]\.provider \}'
        $content | Should -Not -Match '\$selectedMethod = if \(\$Page:AuthenticationProfileMethod\).*else \{ \[string\]\$fieldSchemas\[0\]\.method \}'
    }

    It 'replaces the form when Provider changes so buttons and fields rerender together' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match 'New-UDButton\s+-Id ''authProfileProviderOption_Email''\s+-Text ''Email''\s+-Variant \$emailProviderButtonVariant\s+-OnClick'
        $content | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpAnonymous'"))
        $content | Should -Match ([regex]::Escape('$Page:AuthenticationProfileName = [string]$nameElement.value'))
        $content | Should -Match ([regex]::Escape('$Page:AuthenticationProfileProvider = $Provider'))
        $content | Should -Match ([regex]::Escape('$Page:AuthenticationProfileMethod = $Method'))
        $content | Should -Match ([regex]::Escape('$selectedProvider = if ($null -ne $Page:AuthenticationProfileProvider) { [string]$Page:AuthenticationProfileProvider } else { [string]$selectedProfile.Provider }'))
        $content | Should -Match ([regex]::Escape('$selectedMethod = if ($null -ne $Page:AuthenticationProfileMethod) { [string]$Page:AuthenticationProfileMethod } else { [string]$selectedProfile.Method }'))
        $content | Should -Match ([regex]::Escape("Set-UDElement -Id 'authenticationProfileForm' -Content"))
        $content | Should -Not -Match ([regex]::Escape('Set-UDElement -Id ''authProfileProvider'' -Properties @{ value = ''Email'' }'))
        $content | Should -Not -Match '\$providerElementValue'
        $content | Should -Not -Match '\$methodElementValue'
        $content | Should -Not -Match ([regex]::Escape("Sync-UDElement -Id 'authProfileProviderOptionsRegion'"))
        $content | Should -Not -Match ([regex]::Escape("Sync-UDElement -Id 'authProfileMethodAndFieldsRegion'"))
        $content | Should -Not -Match ([regex]::Escape("Sync-UDElement -Id 'authProfileFieldsRegion'"))
    }

    It 'renders a new draft with no provider or method selected by default' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match '\$providerSelected = -not \[string\]::IsNullOrWhiteSpace\(\$Provider\)'
        $content | Should -Match '\$methodSelected = -not \[string\]::IsNullOrWhiteSpace\(\$Method\)'
        $content | Should -Match '\$awsProviderButtonVariant = if \(''AWS'' -eq \$Provider\) \{ ''contained'' \} else \{ ''outlined'' \}'
        $content | Should -Match '\$azureProviderButtonVariant = if \(''Azure'' -eq \$Provider\) \{ ''contained'' \} else \{ ''outlined'' \}'
        $content | Should -Match '\$emailProviderButtonVariant = if \(''Email'' -eq \$Provider\) \{ ''contained'' \} else \{ ''outlined'' \}'
        $content | Should -Match 'if \(\$providerSelected -and \$methodSelected\)'
        $content | Should -Match '\$Page:AuthenticationProfileProvider = '''''
        $content | Should -Match '\$Page:AuthenticationProfileMethod = '''''
        $content | Should -Not -Match '\$Page:AuthenticationProfileProvider = \[string\]\$fieldSchemas\[0\]\.provider'
        $content | Should -Not -Match '\$Page:AuthenticationProfileMethod = \[string\]\$fieldSchemas\[0\]\.method'
    }

    It 'replaces the form when starting a new profile so stale schema field values are removed' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match "New-UDButton\s+-Id 'newAuthenticationProfileBtn'"
        $content | Should -Match '\$hasEditorState = \$Page:AuthenticationProfileProvider -and \$Page:AuthenticationProfileMethod'
        $content | Should -Match 'if \(\$hasEditorState\)'
        $content | Should -Match "Set-UDElement -Id 'authenticationProfileForm' -Content"
        $content | Should -Match "Sync-UDElement -Id 'authProfileDetailsRegion'"
        $content | Should -Match '\$Page:SelectedAuthenticationProfileId = \$null'
        $content | Should -Match '\$Page:AuthenticationProfileProvider = '''''
        $content | Should -Match '\$Page:AuthenticationProfileMethod = '''''
        $content | Should -Match ([regex]::Escape('-SelectedProfileId $null'))
        $content | Should -Not -Match "Set-UDElement -Id 'authProfileName' -Properties @\{ value = '' \}"
    }

    It 'passes each profile id into deferred edit button handlers with literal scriptblocks' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match '\$editProfileId\s*=\s*\[string\]\$profile\.Id'
        $content | Should -Match '\$editHandler\s*=\s*\[scriptblock\]::Create'
        $content | Should -Match 'New-UDCard\s+-Id "authProfileCard_\$editProfileId"[\s\S]*-OnClick \$editHandler'
        $content | Should -Match ([regex]::Escape('`$selectedId = ''$editProfileId'''))
        $content | Should -Match ([regex]::Escape('`$Page:SelectedAuthenticationProfileId = `$selectedId'))
        $content | Should -Not -Match '\$editHandler\s*=\s*\[scriptblock\]::Create\(@"[\s\S]*?Set-UDElement -Id ''authProfileName''[\s\S]*?"@\)'
        $content | Should -Not -Match '\$editHandler\s*=\s*\[scriptblock\]::Create\(@"[\s\S]*?Set-UDElement -Id ''authProfileProvider''[\s\S]*?"@\)'
        $content | Should -Not -Match '\$Page:SelectedAuthenticationProfileId\s*=\s*\$profile\.Id'
    }

    It 'stores Provider and Method selection in page state before saving' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Azure' -Method 'ServicePrincipalSecret'"))
        $content | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'AWS' -Method 'CurrentProfile'"))
        $content | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpAnonymous'"))
        $content | Should -Match ([regex]::Escape('$Page:AuthenticationProfileProvider = $Provider'))
        $content | Should -Match "No authentication profile methods are configured for provider"
        $content | Should -Match '\$Page:AuthenticationProfileName\s*=\s*\[string\]\$EventData'
        $content | Should -Match 'New-UDButton\s+-Id ''authProfileMethodOption_SmtpAnonymous''\s+-Text ''SMTP Anonymous''\s+-Variant \$smtpAnonymousVariant\s+-OnClick'
        $content | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpAnonymous'"))
        $content | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpBasic'"))
        $content | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Azure' -Method 'ManagedIdentity'"))
        $content | Should -Match ([regex]::Escape('$Page:AuthenticationProfileMethod = $Method'))
        $content | Should -Match "Get-UDElement -Id 'authProfileName'"
        $content | Should -Match '\$provider\s*=\s*\[string\]\$Page:AuthenticationProfileProvider'
        $content | Should -Match '\$method\s*=\s*\[string\]\$Page:AuthenticationProfileMethod'
        $content | Should -Match "Authentication profile form did not submit a provider value"
        $content | Should -Match "Authentication profile form did not submit a method value"
        $content | Should -Match 'authProfileField_\$\{provider\}_\$\{method\}_\$fieldName'
    }

    It 'renders a selected profile test action that resolves secrets before connecting with the selected profile' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match "New-UDButton\s+-Id 'testAuthenticationProfileBtn'\s+-Text 'Test Authentication'"
        $testAuthenticationButtonIndex = $content.IndexOf("New-UDButton -Id 'testAuthenticationProfileBtn'")
        $assignmentsHeadingIndex = $content.IndexOf("New-UDTypography -Text 'Assignments'")
        $testAuthenticationButtonIndex | Should -BeGreaterThan -1
        $assignmentsHeadingIndex | Should -BeGreaterThan -1
        $testAuthenticationButtonIndex | Should -BeLessThan $assignmentsHeadingIndex
        $content | Should -Match 'Get-CIEMAuthenticationProfile\s+-Id \$selectedProfile\.Id\s+-ResolveSecrets'
        $content | Should -Match 'Devolutions\.CIEM\\Connect-CIEM\s+-Provider \$testProfile\.Provider\s+-AuthenticationProfile \$testProfile\s+-Force'
        $content | Should -Not -Match 'Connect-CIEM\s+-Provider \$selectedProfile\.Provider\s+-AuthenticationProfile \$selectedProfile'
        $content | Should -Match ([regex]::Escape('Show-UDToast -Message "Authentication test succeeded for $($selectedProfile.Name)."'))
        $content | Should -Match ([regex]::Escape('Show-UDToast -Message "Authentication test failed: $($_.Exception.Message)"'))
    }

    It 'rebuilds secret references from the selected schema without carrying stale method secrets' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match '\$secretRefs\s*=\s*@\{\}'
        $content | Should -Match '\$existingProfile\.Provider -eq \$provider -and \$existingProfile\.Method -eq \$method'
        $content | Should -Match '\$existingSecretRef'
        $content | Should -Not -Match 'foreach \(\$secretRef in @\(\$existingProfile\.SecretRefs\.PSObject\.Properties\)\)'
    }

    It 'seeds editable setting fields through textbox values instead of asynchronous DOM updates' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match "New-UDElement\s+-Tag 'div'\s+-Id 'authenticationProfileForm'"
        $content | Should -Match "Get-UDElement -Id 'authProfileName'"
        $content | Should -Match 'New-UDTextbox[^\r\n]*-Id \$inputId[^\r\n]*-Label \$field\.label[^\r\n]*-Value \$renderedValue[^\r\n]*-Type \$fieldType[^\r\n]*-FullWidth'
        $content | Should -Not -Match 'Set-UDElement -Id \$inputId -Properties @\{ value = \$renderedValue \}'
        $content | Should -Match '\$fieldElement\s*=\s*Get-UDElement -Id \$inputId'
        $content | Should -Match "Authentication profile form did not render field"
        $content | Should -Match '\$value\s*=\s*\$fieldElement\.value'
        $content | Should -Match '\$secretValue\s*=\s*\[string\]\(Get-UDElement -Id \$inputId\)\.value'
        $content | Should -Not -Match 'AuthenticationProfileFieldValues'
        $content | Should -Not -Match '\$value\s*=\s*\$EventData\[\$inputId\]'
        $content | Should -Not -Match '\$secretValue\s*=\s*\[string\]\$EventData\[\$inputId\]'
        $content | Should -Not -Match '\$fieldProperty\s*=\s*\$EventData\.PSObject\.Properties\[\$inputId\]'
    }

    It 'renders new profile field textboxes with explicit empty values' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Match '\$renderedValue\s*=\s*if\s*\(\$null -ne \$existingValue\)\s*\{\s*\$existingValue\s*\}\s*else\s*\{\s*''''\s*\}'
        $content | Should -Match '\$value\s*=\s*if\s*\(\$currentSelectedProfile -and \$currentSelectedProfile\.Provider -eq \$schemaProvider -and \$currentSelectedProfile\.Method -eq \$schemaMethod -and \$field\.kind -eq ''secret'' -and \$currentSelectedProfile\.SecretRefs\.\$fieldName\)\s*\{\s*''\*\*\*\*\*\*\*\*''\s*\}\s*else\s*\{\s*''''\s*\}'
        $content | Should -Not -Match '\$renderedValue\s*=\s*\$existingValue'
        $content | Should -Not -Match '\}\s*else\s*\{\s*\$existingValue\s*\}'
    }

    It 'does not use provider-specific authentication profile labels' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Not -Match 'Azure authentication profiles'
        $content | Should -Not -Match 'AWS authentication profiles'
        $content | Should -Not -Match 'Email authentication profiles'
    }

    It 'does not pass unsupported style parameters directly to UD controls' {
        $script:AuthenticationProfilesPagePath | Should -Exist
        $content = Get-Content -Path $script:AuthenticationProfilesPagePath -Raw

        $content | Should -Not -Match 'New-UDButton[^\r\n]*-Style'
        $content | Should -Not -Match 'New-UDCard[^\r\n]*-Style'
        $content | Should -Not -Match 'New-UDStack[^\r\n]*-Style'
    }
}
