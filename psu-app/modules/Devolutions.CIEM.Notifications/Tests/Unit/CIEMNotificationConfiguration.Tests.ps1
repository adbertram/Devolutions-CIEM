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
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profile_assignments' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profiles' -AsNonQuery | Out-Null
    }

    It 'saves an SMTP Basic generic authentication profile with secret references only' {
        $profile = Save-CIEMAuthenticationProfile `
            -Name 'Default SMTP' `
            -Provider 'Email' `
            -Method 'SmtpBasic' `
            -Settings @{
                Host = 'smtp.example.com'
                Port = 587
                TlsMode = 'StartTls'
                Username = 'alerts@example.com'
            } `
            -SecretRefs @{ Password = 'CIEM_Notification_Email_Password' }

        $profile.Provider | Should -Be 'Email'
        $profile.Method | Should -Be 'SmtpBasic'
        $profile.Settings.Host | Should -Be 'smtp.example.com'
        $profile.Settings.Port | Should -Be 587
        $profile.Settings.Username | Should -Be 'alerts@example.com'
        $profile.SecretRefs.Password | Should -Be 'CIEM_Notification_Email_Password'
        $profile.PSObject.Properties.Name | Should -Not -Contain 'Password'

        $stored = @(Get-CIEMAuthenticationProfile -Id $profile.Id)[0]
        $stored.SecretRefs.Password | Should -Be 'CIEM_Notification_Email_Password'
    }

    It 'throws when SMTP Basic generic authentication is saved without a password secret reference' {
        {
            Save-CIEMAuthenticationProfile `
                -Name 'Broken SMTP' `
                -Provider 'Email' `
                -Method 'SmtpBasic' `
                -Settings @{
                    Host = 'smtp.example.com'
                    Port = 587
                    TlsMode = 'StartTls'
                    Username = 'alerts@example.com'
                } `
                -SecretRefs @{}
        } | Should -Throw "*field 'Password' is required*"
    }

    It 'saves an Email channel without storing authentication profile ownership' {
        $channel = Set-CIEMNotificationChannel `
            -Enabled $true `
            -FromAddress 'ciem@example.com' `
            -ToRecipients @('security@example.com', 'it@example.com') `
            -CcRecipients @('audit@example.com')

        $channel.Type | Should -Be 'Email'
        $channel.Enabled | Should -BeTrue
        $channel.PSObject.Properties.Name | Should -Not -Contain 'AuthenticationProfileId'
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
