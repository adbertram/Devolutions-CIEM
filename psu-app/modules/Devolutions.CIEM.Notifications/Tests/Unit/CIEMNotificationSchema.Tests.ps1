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
    'notification_channels',
    'notifications',
    'notification_history'
  )
"@)

        $tables | Should -HaveCount 3
        $tables.name | Should -Contain 'notification_channels'
        $tables.name | Should -Contain 'notifications'
        $tables.name | Should -Contain 'notification_history'
    }

    It 'does not store authentication profile ownership on notification channels' {
        $columns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('notification_channels')")

        $columns.name | Should -Contain 'from_address'
        $columns.name | Should -Contain 'to_recipients_json'
        $columns.name | Should -Not -Contain 'authentication_profile_id'
    }

    It 'contains no legacy notification authentication migration path' {
        $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')
        $newDatabaseSource = Get-Content -Path (Join-Path $moduleRoot 'Public/New-CIEMDatabase.ps1') -Raw
        $legacyMigrationPath = Join-Path $moduleRoot 'modules/Devolutions.CIEM.Notifications/Private/UpdateCIEMNotificationStorageSchema.ps1'

        $legacyMigrationPath | Should -Not -Exist
        $newDatabaseSource | Should -Not -Match 'UpdateCIEMNotificationStorageSchema'
    }

    It 'exports notification commands without exposing class types in public parameters' {
        $commands = @(
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
            $channel = [CIEMNotificationChannel]::new()
            $notification = [CIEMNotification]::new()

            [PSCustomObject]@{
                ChannelProperties     = @($channel.PSObject.Properties.Name)
                NotificationProperties = @($notification.PSObject.Properties.Name)
            }
        }

        $classProperties.ChannelProperties | Should -Contain 'FromAddress'
        $classProperties.ChannelProperties | Should -Not -Contain 'AuthenticationProfileId'
        $classProperties.NotificationProperties | Should -Contain 'HtmlBodyTemplate'
    }
}
