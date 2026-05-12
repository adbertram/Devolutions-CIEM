BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'CIEM notification configuration commands' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM notification_history' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM notifications' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM notification_channels' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM notification_authentication_profiles' -AsNonQuery | Out-Null
    }

    It 'saves an SMTP Basic notification authentication profile with secret references only' {
        $profile = Set-CIEMNotificationAuthenticationProfile `
            -Name 'Default SMTP' `
            -Method 'SmtpBasic' `
            -Host 'smtp.example.com' `
            -Port 587 `
            -TlsMode 'StartTls' `
            -Username 'alerts@example.com' `
            -PasswordSecretName 'CIEM_Notification_Email_Password'

        $profile.Method | Should -Be 'SmtpBasic'
        $profile.Settings.Host | Should -Be 'smtp.example.com'
        $profile.Settings.Port | Should -Be 587
        $profile.Settings.Username | Should -Be 'alerts@example.com'
        $profile.SecretRefs.Password | Should -Be 'CIEM_Notification_Email_Password'
        $profile.PSObject.Properties.Name | Should -Not -Contain 'Password'

        $stored = @(Get-CIEMNotificationAuthenticationProfile -Id $profile.Id)[0]
        $stored.SecretRefs.Password | Should -Be 'CIEM_Notification_Email_Password'
    }

    It 'throws when SMTP Basic authentication is saved without a password secret reference' {
        {
            Set-CIEMNotificationAuthenticationProfile `
                -Name 'Broken SMTP' `
                -Method 'SmtpBasic' `
                -Host 'smtp.example.com' `
                -Port 587 `
                -TlsMode 'StartTls' `
                -Username 'alerts@example.com'
        } | Should -Throw "*PasswordSecretName*"
    }

    It 'saves an Email channel that references the notification authentication profile' {
        $profile = Set-CIEMNotificationAuthenticationProfile -Name 'SMTP Relay' -Method 'SmtpAnonymous' -Host 'smtp-relay.example.com' -Port 25 -TlsMode 'None'

        $channel = Set-CIEMNotificationChannel `
            -Enabled $true `
            -AuthenticationProfileId $profile.Id `
            -FromAddress 'ciem@example.com' `
            -ToRecipients @('security@example.com', 'it@example.com') `
            -CcRecipients @('audit@example.com')

        $channel.Type | Should -Be 'Email'
        $channel.Enabled | Should -BeTrue
        $channel.AuthenticationProfileId | Should -Be $profile.Id
        $channel.ToRecipients | Should -Contain 'security@example.com'
        $channel.CcRecipients | Should -Contain 'audit@example.com'
    }

    It 'saves an Exposure Change notification template with filters and text plus HTML bodies' {
        $notification = Set-CIEMNotification `
            -Enabled $true `
            -AutoSendScope 'AnyDiscovery' `
            -ChangeTypes @('NewRisk', 'RiskIncrease') `
            -MinimumSeverity 'High' `
            -SubjectTemplate '[CIEM] {{Severity}} exposure: {{Title}}' `
            -TextBodyTemplate 'Text {{Title}} {{Evidence}}' `
            -HtmlBodyTemplate '<p>HTML {{Title}} {{Evidence}}</p>'

        $notification.Type | Should -Be 'ExposureChange'
        $notification.Enabled | Should -BeTrue
        $notification.ChangeTypes | Should -Contain 'NewRisk'
        $notification.ChangeTypes | Should -Contain 'RiskIncrease'
        $notification.MinimumSeverity | Should -Be 'High'
        $notification.HtmlBodyTemplate | Should -Be '<p>HTML {{Title}} {{Evidence}}</p>'
    }
}
