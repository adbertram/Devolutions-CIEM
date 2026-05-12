BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'CIEM notification schema and public commands' {
    It 'creates notification persistence tables during database setup' {
        $tables = @(Invoke-CIEMQuery -Query @"
SELECT name
FROM sqlite_master
WHERE type = 'table'
  AND name IN (
    'notification_authentication_profiles',
    'notification_channels',
    'notifications',
    'notification_history'
  )
"@)

        $tables | Should -HaveCount 4
        $tables.name | Should -Contain 'notification_authentication_profiles'
        $tables.name | Should -Contain 'notification_channels'
        $tables.name | Should -Contain 'notifications'
        $tables.name | Should -Contain 'notification_history'
    }

    It 'creates notification authentication profile columns for data-driven SMTP settings and secret references' {
        $columns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('notification_authentication_profiles')")

        $columns.name | Should -Contain 'settings_json'
        $columns.name | Should -Contain 'secret_refs_json'
        $columns.name | Should -Contain 'method'
    }

    It 'exports notification commands without exposing class types in public parameters' {
        $commands = @(
            'Get-CIEMNotificationAuthenticationProfile',
            'Set-CIEMNotificationAuthenticationProfile',
            'Get-CIEMNotificationChannel',
            'Set-CIEMNotificationChannel',
            'Get-CIEMNotification',
            'Set-CIEMNotification',
            'Get-CIEMNotificationHistory',
            'Send-CIEMNotification'
        )

        foreach ($commandName in $commands) {
            $command = Get-Command -Module Devolutions.CIEM -Name $commandName -ErrorAction Stop
            $command | Should -Not -BeNullOrEmpty
            foreach ($parameter in $command.Parameters.Values) {
                $parameter.ParameterType.FullName | Should -Not -Match '^CIEM'
            }
        }
    }

    It 'loads notification classes inside the module scope' {
        $classProperties = InModuleScope Devolutions.CIEM {
            $authProfile = [CIEMNotificationAuthenticationProfile]::new()
            $channel = [CIEMNotificationChannel]::new()
            $notification = [CIEMNotification]::new()

            [PSCustomObject]@{
                AuthProfileProperties = @($authProfile.PSObject.Properties.Name)
                ChannelProperties     = @($channel.PSObject.Properties.Name)
                NotificationProperties = @($notification.PSObject.Properties.Name)
            }
        }

        $classProperties.AuthProfileProperties | Should -Contain 'SettingsJson'
        $classProperties.AuthProfileProperties | Should -Contain 'SecretRefsJson'
        $classProperties.ChannelProperties | Should -Contain 'AuthenticationProfileId'
        $classProperties.NotificationProperties | Should -Contain 'HtmlBodyTemplate'
    }
}
