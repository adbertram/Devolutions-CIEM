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

Describe 'Configuration page PSU-native form and certificate upload' {
    It 'does not render database schema maintenance controls' {
        $script:PageContent | Should -Not -Match 'CIEM Database'
        $script:PageContent | Should -Not -Match 'Reapplies CIEM database schema'
        $script:PageContent | Should -Not -Match 'refreshes provider and check catalogs'
        $script:PageContent | Should -Not -Match 'New-CIEMDatabase'
        $script:PageContent | Should -Not -Match 'Reapply Schema and Catalogs'
        $script:PageContent | Should -Not -Match 'Initialize Database'
        $script:PageContent | Should -Not -Match 'Initialize the CIEM database before configuring providers or running scans'
        $script:PageContent | Should -Not -Match 'initializeCiemDatabaseBtn'
        $script:PageContent | Should -Not -Match '\$databaseExists'
        $script:PageContent | Should -Not -Match 'if\s*\(\s*-not\s+\$databaseExists\s*\)'
    }

    It 'uses a PSU form submit handler for saving configuration values' {
        $script:PageContent | Should -Match "New-UDForm\s+-Id\s+'ciemConfigForm'"
        $script:PageContent | Should -Match '-OnSubmit\s*{'
        $script:PageContent | Should -Match '\$EventData\.cloudProvider'
        $script:PageContent | Should -Match '\$EventData\.authMethod'
    }

    It 'reads Azure save values from EventData instead of scraping UD controls' {
        foreach ($fieldId in @(
            'azTenantId',
            'azSpClientId',
            'azSpClientSecret',
            'azCertClientId',
            'azCertPassword'
        )) {
            $script:PageContent | Should -Not -Match "Get-UDElement\s+-Id\s+'$fieldId'"
        }
    }

    It 'uses New-UDUpload for certificate files instead of browser-local JavaScript transport' {
        $script:PageContent | Should -Match "New-UDUpload\s+-Id\s+'azCertPfxUpload'"
        $script:PageContent | Should -Match "-Accept\s+'\.pfx,\.p12'"
        $script:PageContent | Should -Not -Match 'localStorage'
        $script:PageContent | Should -Not -Match 'FileReader'
        $script:PageContent | Should -Not -Match 'azCertProcess'
        $script:PageContent | Should -Not -Match 'document\.createElement'
    }

    It 'keeps temporary certificate upload state in Page scope' {
        $script:PageContent | Should -Match '\$Page:UploadedCertBase64'
        $script:PageContent | Should -Match '\$Page:UploadedCertFileName'
        $script:PageContent | Should -Not -Match '\$Session:UploadedCertBase64'
        $script:PageContent | Should -Not -Match '\$Session:UploadedCertFileName'
    }

    It 'persists AWS authentication profile metadata through the AWS cache command' {
        $script:PageContent | Should -Match 'Set-CIEMAWSAuthenticationProfile'
        $script:PageContent | Should -Match '-Method\s+\$authMethod'
        $script:PageContent | Should -Match '-Region\s+\$region'
        $script:PageContent | Should -Match "Get-UDElement\s+-Id\s+'awsProfile'"
        $script:PageContent | Should -Match "Get-UDElement\s+-Id\s+'awsRegion'"
        $script:PageContent | Should -Match "Get-UDElement\s+-Id\s+'awsAccessKeyId'"
        $script:PageContent | Should -Match "Get-UDElement\s+-Id\s+'awsSecretAccessKey'"
    }
}

Describe 'Configuration page scheduled discovery controls' {
    It 'renders scheduled discovery controls backed by the Azure discovery schedule commands' {
        $script:PageContent | Should -Match 'Scheduled Discovery'
        $script:PageContent | Should -Match 'Get-CIEMAzureDiscoverySchedule'
        $script:PageContent | Should -Match 'Set-CIEMAzureDiscoverySchedule'
        $script:PageContent | Should -Match "New-UDSelect\s+-Id\s+'azureDiscoveryScheduleCadence'"
        $script:PageContent | Should -Match "New-UDSelect\s+-Id\s+'azureDiscoveryScheduleScope'"
        $script:PageContent | Should -Match "New-UDSwitch\s+-Id\s+'azureDiscoveryScheduleEnabled'"
        $script:PageContent | Should -Match "New-UDButton\s+-Id\s+'saveAzureDiscoveryScheduleBtn'"
    }

    It 'syncs scheduled discovery visibility with the selected cloud provider' {
        $script:PageContent | Should -Match "Sync-UDElement -Id 'scheduledDiscoveryContainer'"
        $script:PageContent | Should -Match "New-UDDynamic -Id 'scheduledDiscoveryContainer'"
        $script:PageContent | Should -Match 'if \(\$scheduleProvider -ne ''Azure''\)'
    }
}
