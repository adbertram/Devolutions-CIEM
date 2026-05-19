BeforeAll {
    $script:PagesRoot = Join-Path $PSScriptRoot '..' '..' 'Pages'
    $script:PageRegistryPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'pages.json'
    $script:AuthenticationProfilesPagePath = Join-Path $script:PagesRoot 'New-CIEMAuthenticationProfilesPage.ps1'
    $script:ConfigurationPagePath = Join-Path $script:PagesRoot 'New-CIEMConfigPage.ps1'
    $script:ModulePath = Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psm1'
    $script:PageRegistry = @(Get-Content -Path $script:PageRegistryPath -Raw | ConvertFrom-Json -Depth 10)
    $script:ConfigurationPageContent = Get-Content -Path $script:ConfigurationPagePath -Raw
}

Describe 'Authentication Profiles configuration section' {
    It 'removes the standalone Authentication Profiles page from the CIEM page registry' {
        $page = $script:PageRegistry | Where-Object name -eq 'Authentication Profiles'

        $page | Should -BeNullOrEmpty
    }

    It 'removes the standalone Authentication Profiles page factory file' {
        $script:AuthenticationProfilesPagePath | Should -Not -Exist
    }

    It 'moves generic authentication profile management into the Configuration page' {
        $script:ConfigurationPageContent | Should -Match "New-UDTable\s+-Id 'authenticationProfilesTable'"
        $script:ConfigurationPageContent | Should -Match "New-UDButton\s+-Id 'newAuthenticationProfileBtn'"
        $script:ConfigurationPageContent | Should -Match "New-UDButton\s+-Id 'saveAuthenticationProfileBtn'"
        $script:ConfigurationPageContent | Should -Match "New-UDElement\s+-Tag 'div'\s+-Id 'authenticationProfileForm'"
        $script:ConfigurationPageContent | Should -Match 'Devolutions\.CIEM\\Get-CIEMAuthenticationProfile'
        $script:ConfigurationPageContent | Should -Match 'Devolutions\.CIEM\\Save-CIEMAuthenticationProfile'
        $script:ConfigurationPageContent | Should -Match 'Devolutions\.CIEM\\Remove-CIEMAuthenticationProfile'
        $script:ConfigurationPageContent | Should -Match 'Devolutions\.CIEM\\Set-CIEMAuthenticationProfileAssignment'
    }

    It 'keeps data-driven profile fields in the moved Configuration section' {
        $script:ConfigurationPageContent | Should -Match 'Devolutions\.CIEM\\Get-CIEMAuthenticationProfileFieldSchema'
        $script:ConfigurationPageContent | Should -Match '\$fieldSchema'
        $script:ConfigurationPageContent | Should -Match 'New-CIEMAuthenticationProfileFormContent'
        $script:ConfigurationPageContent | Should -Match 'New-CIEMAuthenticationProfileFieldControls'
        $script:ConfigurationPageContent | Should -Match 'Get-CIEMAuthenticationProfileFieldSchema\s+-Provider \$Provider\s+-Method \$Method'
        $script:ConfigurationPageContent | Should -Not -Match 'switch\s*\(\s*\$Provider\s*\)'
        $script:ConfigurationPageContent | Should -Not -Match 'switch\s*\(\s*\$selectedProvider\s*\)'
    }

    It 'renders a new profile modal with no provider or method selected by default' {
        $script:ConfigurationPageContent | Should -Match '\$providerSelected = -not \[string\]::IsNullOrWhiteSpace\(\$Provider\)'
        $script:ConfigurationPageContent | Should -Match '\$methodSelected = -not \[string\]::IsNullOrWhiteSpace\(\$Method\)'
        $script:ConfigurationPageContent | Should -Match '\$awsProviderButtonVariant = if \(''AWS'' -eq \$Provider\) \{ ''contained'' \} else \{ ''outlined'' \}'
        $script:ConfigurationPageContent | Should -Match '\$azureProviderButtonVariant = if \(''Azure'' -eq \$Provider\) \{ ''contained'' \} else \{ ''outlined'' \}'
        $script:ConfigurationPageContent | Should -Match '\$emailProviderButtonVariant = if \(''Email'' -eq \$Provider\) \{ ''contained'' \} else \{ ''outlined'' \}'
        $script:ConfigurationPageContent | Should -Match 'if \(\$providerSelected -and \$methodSelected\)'
        $script:ConfigurationPageContent | Should -Match '\$Page:AuthenticationProfileProvider = '''''
        $script:ConfigurationPageContent | Should -Match '\$Page:AuthenticationProfileMethod = '''''
        $script:ConfigurationPageContent | Should -Not -Match '\$Page:AuthenticationProfileProvider = \[string\]\$fieldSchemas\[0\]\.provider'
        $script:ConfigurationPageContent | Should -Not -Match '\$Page:AuthenticationProfileMethod = \[string\]\$fieldSchemas\[0\]\.method'
    }

    It 'stores Provider and Method selection in page state before saving from the modal' {
        $script:ConfigurationPageContent | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Azure' -Method 'ServicePrincipalSecret'"))
        $script:ConfigurationPageContent | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'AWS' -Method 'CurrentProfile'"))
        $script:ConfigurationPageContent | Should -Match ([regex]::Escape("Set-CIEMAuthenticationProfileFormContent -Provider 'Email' -Method 'SmtpAnonymous'"))
        $script:ConfigurationPageContent | Should -Match ([regex]::Escape('$Page:AuthenticationProfileProvider = $Provider'))
        $script:ConfigurationPageContent | Should -Match ([regex]::Escape('$Page:AuthenticationProfileMethod = $Method'))
        $script:ConfigurationPageContent | Should -Match "Authentication profile form did not submit a provider value"
        $script:ConfigurationPageContent | Should -Match "Authentication profile form did not submit a method value"
        $script:ConfigurationPageContent | Should -Match 'authProfileField_\$\{provider\}_\$\{method\}_\$fieldName'
    }

    It 'resolves secrets before testing the selected profile' {
        $script:ConfigurationPageContent | Should -Match "New-UDButton\s+-Id 'testAuthenticationProfileBtn'\s+-Text 'Test Authentication'"
        $script:ConfigurationPageContent | Should -Match 'Get-CIEMAuthenticationProfile\s+-Id \$selectedProfile\.Id\s+-ResolveSecrets'
        $script:ConfigurationPageContent | Should -Match 'Devolutions\.CIEM\\Connect-CIEM\s+-Provider \$testProfile\.Provider\s+-AuthenticationProfile \$testProfile\s+-Force'
        $script:ConfigurationPageContent | Should -Not -Match 'Connect-CIEM\s+-Provider \$selectedProfile\.Provider\s+-AuthenticationProfile \$selectedProfile'
    }

    It 'seeds editable setting fields through textbox values instead of asynchronous DOM updates' {
        $script:ConfigurationPageContent | Should -Match "Get-UDElement -Id 'authProfileName'"
        $script:ConfigurationPageContent | Should -Match 'defaultValue'
        $script:ConfigurationPageContent | Should -Match 'New-UDTextbox[^\r\n]*-Id \$inputId[^\r\n]*-Label \$field\.label[^\r\n]*-Value \$renderedValue[^\r\n]*-Type \$fieldType[^\r\n]*-FullWidth'
        $script:ConfigurationPageContent | Should -Not -Match 'Set-UDElement -Id \$inputId -Properties @\{ value = \$renderedValue \}'
        $script:ConfigurationPageContent | Should -Match '\$fieldElement\s*=\s*Get-UDElement -Id \$inputId'
        $script:ConfigurationPageContent | Should -Match "Authentication profile form did not render field"
        $script:ConfigurationPageContent | Should -Match '\$value\s*=\s*\$fieldElement\.value'
        $script:ConfigurationPageContent | Should -Match '\$secretValue\s*=\s*\[string\]\(Get-UDElement -Id \$inputId\)\.value'
        $script:ConfigurationPageContent | Should -Not -Match 'AuthenticationProfileFieldValues'
    }

    It 'keeps authentication profile form helpers exported by the module' {
        $moduleContent = Get-Content -Path $script:ModulePath -Raw

        $moduleContent | Should -Match "New-CIEMAuthenticationProfileFormContent"
        $moduleContent | Should -Match "Set-CIEMAuthenticationProfileFormContent"
        $moduleContent | Should -Match "Show-CIEMAuthenticationProfileDetailsModal"
    }
}
