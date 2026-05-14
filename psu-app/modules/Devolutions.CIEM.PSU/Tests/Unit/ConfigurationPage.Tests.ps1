BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMConfigPage.ps1') -Raw
}

Describe 'Configuration page authentication cleanup' {
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

    It 'does not render authentication profile management controls' {
        $script:PageContent | Should -Not -Match 'Cloud Provider Authentication'
        $script:PageContent | Should -Not -Match "New-UDForm\s+-Id\s+'ciemConfigForm'"
        $script:PageContent | Should -Not -Match "New-UDSelect\s+-Id\s+'cloudProvider'"
        $script:PageContent | Should -Not -Match "New-UDSelect\s+-Id\s+'authMethod'"
        $script:PageContent | Should -Not -Match 'Save-CIEMAzureAuthenticationProfile'
        $script:PageContent | Should -Not -Match 'Set-CIEMAWSAuthenticationProfile'
        $script:PageContent | Should -Not -Match 'Set-CIEMNotificationAuthenticationProfile'
    }

    It 'does not render authentication utility actions' {
        $script:PageContent | Should -Not -Match 'Get Required Permissions'
        $script:PageContent | Should -Not -Match 'Test Authentication'
        $script:PageContent | Should -Not -Match 'Get-CIEMRequiredPermission'
        $script:PageContent | Should -Not -Match 'Connect-CIEM'
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

    It 'renders scheduled discovery directly without provider-auth visibility coupling' {
        $script:PageContent | Should -Match "New-UDElement -Tag 'div' -Id 'scheduledDiscoveryWrapper'"
        $script:PageContent | Should -Not -Match "scheduledDiscoveryContainer"
        $script:PageContent | Should -Not -Match '\$scheduleProvider'
        $script:PageContent | Should -Not -Match '\$scheduleDisplay'
    }
}

Describe 'Configuration page notification controls' {
    It 'renders notification channel controls backed by notification commands' {
        $script:PageContent | Should -Match 'Notification Channels'
        $script:PageContent | Should -Match 'Get-CIEMNotificationChannel'
        $script:PageContent | Should -Match 'Set-CIEMNotificationChannel'
        $script:PageContent | Should -Match 'Get-CIEMNotificationHistory'
        $script:PageContent | Should -Match 'Send-CIEMNotification'
        $script:PageContent | Should -Match "New-UDTextbox\s+-Id\s+'notificationToRecipients'"
        $script:PageContent | Should -Match "New-UDButton\s+-Id\s+'saveNotificationsBtn'"
        $script:PageContent | Should -Match "New-UDButton\s+-Id\s+'testNotificationEmailBtn'"
    }

    It 'does not manage Email provider connection settings from Configuration' {
        $script:PageContent | Should -Not -Match "New-UDSelect\s+-Id\s+'notificationAuthMethod'"
        $script:PageContent | Should -Not -Match "New-UDTextbox\s+-Id\s+'notificationSmtpHost'"
        $script:PageContent | Should -Not -Match 'CIEM_Notification_Email_Password'
        $script:PageContent | Should -Not -Match 'Set-CIEMSecret\s+\$passwordSecretName\s+\$smtpPassword'
    }
}
