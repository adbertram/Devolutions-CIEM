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

    It 'renders authentication profiles as a summary table before editor details' {
        $script:PageContent | Should -Match 'Authentication Profiles'
        $script:PageContent | Should -Match "New-UDButton\s+-Id 'newAuthenticationProfileBtn'"
        $script:PageContent | Should -Match "New-UDDynamic\s+-Id 'authenticationProfilesTableRegion'"
        $script:PageContent | Should -Match "New-UDTable\s+-Id 'authenticationProfilesTable'"
        $script:PageContent | Should -Match 'OnRowExpand'
        $script:PageContent | Should -Match "New-UDTableColumn\s+-Property 'Actions'\s+-Title 'Actions'"
        $script:PageContent | Should -Match 'New-UDButton\s+-Id "editAuthenticationProfile_\$\(\$EventData.Id\)"'
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Get-CIEMAuthenticationProfile'
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Remove-CIEMAuthenticationProfile'
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Set-CIEMAuthenticationProfileAssignment'
        $script:PageContent | Should -Not -Match 'Cloud Provider Authentication'
        $script:PageContent | Should -Not -Match "New-UDForm\s+-Id\s+'ciemConfigForm'"
        $script:PageContent | Should -Not -Match "New-UDSelect\s+-Id\s+'cloudProvider'"
        $script:PageContent | Should -Not -Match "New-UDSelect\s+-Id\s+'authMethod'"
    }

    It 'opens a supported PSU modal for creating and editing authentication profile details' {
        $script:PageContent | Should -Match 'Show-UDModal'
        $script:PageContent | Should -Match 'Hide-UDModal'
        $script:PageContent | Should -Match 'Authentication Profile Details'
        $script:PageContent | Should -Match "New-UDElement\s+-Tag 'div'\s+-Id 'authenticationProfileForm'"
        $script:PageContent | Should -Match 'New-CIEMAuthenticationProfileFormContent'
        $script:PageContent | Should -Match 'New-CIEMAuthenticationProfileFieldControls'
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Get-CIEMAuthenticationProfileFieldSchema'
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Save-CIEMAuthenticationProfile'
        $script:PageContent | Should -Match "New-UDButton\s+-Id 'saveAuthenticationProfileBtn'"
        $script:PageContent | Should -Match "New-UDButton\s+-Id 'testAuthenticationProfileBtn'\s+-Text 'Test Authentication'"
        $script:PageContent | Should -Match 'Devolutions\.CIEM\\Connect-CIEM\s+-Provider \$testProfile\.Provider\s+-AuthenticationProfile \$testProfile\s+-Force'
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
    It 'renders available notification channel types and a channel table before editor details' {
        $script:PageContent | Should -Match 'Notification Channels'
        $script:PageContent | Should -Match 'Available Channel Types'
        $script:PageContent | Should -Match "New-UDButton\s+-Id\s+'addEmailNotificationChannelBtn'"
        $script:PageContent | Should -Match "New-UDElement\s+-Tag\s+'div'\s+-Id\s+'notificationChannelEditorPane'"
        $script:PageContent | Should -Match "New-UDDynamic\s+-Id\s+'notificationChannelsTableRegion'"
        $script:PageContent | Should -Match "New-UDTable\s+-Id\s+'notificationChannelsTable'"
        $script:PageContent | Should -Match 'OnRowExpand'
        $script:PageContent | Should -Match "New-UDTableColumn\s+-Property 'Actions'\s+-Title 'Actions'"
        $script:PageContent | Should -Match 'New-UDButton\s+-Id\s+"editNotificationChannel_\$\(\$EventData.Id\)"'
        $script:PageContent | Should -Match 'Get-CIEMNotificationChannel'
        $script:PageContent | Should -Match 'Set-CIEMNotificationChannel'
        $script:PageContent | Should -Match "New-UDTextbox\s+-Id\s+'notificationToRecipients'"
        $script:PageContent | Should -Match "New-UDButton\s+-Id\s+'saveNotificationsBtn'"
        $script:PageContent | Should -Not -Match 'Set-CIEMNotification\s+`'
        $script:PageContent | Should -Not -Match "New-UDSelect\s+-Id\s+'notificationAutoSendScope'"
        $script:PageContent | Should -Not -Match "New-UDTextbox\s+-Id\s+'notificationSubjectTemplate'"
        $script:PageContent | Should -Not -Match 'Get-CIEMNotificationHistory'
        $script:PageContent | Should -Not -Match 'Send-CIEMNotification'
        $script:PageContent | Should -Not -Match "New-UDButton\s+-Id\s+'testNotificationEmailBtn'"
    }

    It 'opens a supported PSU modal for editing every Email channel attribute' {
        $script:PageContent | Should -Match 'Show-UDModal'
        $script:PageContent | Should -Match 'Hide-UDModal'
        $script:PageContent | Should -Match 'Notification Channel Details'
        $script:PageContent | Should -Match "New-UDSwitch\s+-Id\s+'notificationChannelEnabled'"
        $script:PageContent | Should -Match "New-UDTextbox\s+-Id\s+'notificationFromAddress'"
        $script:PageContent | Should -Match "New-UDTextbox\s+-Id\s+'notificationToRecipients'"
        $script:PageContent | Should -Match "New-UDTextbox\s+-Id\s+'notificationCcRecipients'"
        $script:PageContent | Should -Match "New-UDTextbox\s+-Id\s+'notificationBccRecipients'"
        $script:PageContent | Should -Match 'Set-CIEMNotificationChannel\s+`[\s\S]*-Enabled \(\[bool\]\(Get-UDElement -Id ''notificationChannelEnabled''\)\.checked\)'
        $script:PageContent | Should -Match '-CcRecipients \$ccRecipients\s+`'
        $script:PageContent | Should -Match '-BccRecipients \$bccRecipients'
    }

    It 'does not manage Email provider connection settings from Configuration' {
        $script:PageContent | Should -Not -Match "New-UDSelect\s+-Id\s+'notificationAuthMethod'"
        $script:PageContent | Should -Not -Match "New-UDTextbox\s+-Id\s+'notificationSmtpHost'"
        $script:PageContent | Should -Not -Match 'CIEM_Notification_Email_Password'
        $script:PageContent | Should -Not -Match 'Set-CIEMSecret\s+\$passwordSecretName\s+\$smtpPassword'
    }
}
