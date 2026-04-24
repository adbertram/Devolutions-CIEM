BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMConfigPage.ps1') -Raw
}

Describe 'Configuration page required permissions modal' {
    It 'reads the Azure permission model from Get-CIEMRequiredPermission instead of inline SQL' {
        $script:PageContent | Should -Match 'Get-CIEMRequiredPermission\s+-Provider\s+''Azure'''
        $script:PageContent | Should -Not -Match 'SELECT permissions FROM azure_provider_apis'
    }

    It 'renders separate discovery and remediation sections' {
        $script:PageContent | Should -Match 'Discovery Permissions'
        $script:PageContent | Should -Match 'Remediation Permissions'
    }

    It 'does not pass unsupported Style parameters to New-UDDivider in the permissions modal' {
        $script:PageContent | Should -Not -Match 'New-UDDivider\s+-Style'
    }
}
