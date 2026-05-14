BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

Describe 'Generic CIEM authentication profile schema' {
    It 'creates exactly the generic authentication profile tables' {
        $tables = @(Invoke-CIEMQuery -Query @"
SELECT name
FROM sqlite_master
WHERE type = 'table'
AND name IN ('authentication_profiles', 'authentication_profile_assignments', 'notification_authentication_profiles')
ORDER BY name
"@)

        $tables.name | Should -Contain 'authentication_profiles'
        $tables.name | Should -Contain 'authentication_profile_assignments'
        $tables.name | Should -Not -Contain 'notification_authentication_profiles'
    }

    It 'stores notification channel profile usage through assignments instead of a channel column' {
        $columns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('notification_channels')")
        $columns.name | Should -Not -Contain 'authentication_profile_id'

        $assignmentColumns = @(Invoke-CIEMQuery -Query "PRAGMA table_info('authentication_profile_assignments')")
        $assignmentColumns.name | Should -Contain 'usage_type'
        $assignmentColumns.name | Should -Contain 'usage_id'
        $assignmentColumns.name | Should -Contain 'authentication_profile_id'
    }
}

Describe 'Generic CIEM authentication profile commands' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profile_assignments' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profiles' -AsNonQuery | Out-Null
    }

    It 'saves and returns an Azure profile without raw secret values' {
        $profile = Save-CIEMAuthenticationProfile `
            -Name 'Production Azure' `
            -Provider 'Azure' `
            -Method 'ServicePrincipalSecret' `
            -Settings @{
                TenantId = '11111111-1111-1111-1111-111111111111'
                ClientId = '22222222-2222-2222-2222-222222222222'
            } `
            -SecretRefs @{ ClientSecret = 'CIEM_Azure_prod_ClientSecret' }

        $profile.Provider | Should -Be 'Azure'
        $profile.Method | Should -Be 'ServicePrincipalSecret'
        $profile.Settings.TenantId | Should -Be '11111111-1111-1111-1111-111111111111'
        $profile.SecretRefs.ClientSecret | Should -Be 'CIEM_Azure_prod_ClientSecret'
        $profile.PSObject.Properties.Name | Should -Not -Contain 'ClientSecret'

        $stored = @(Get-CIEMAuthenticationProfile -Id $profile.Id)[0]
        $stored.SecretRefs.ClientSecret | Should -Be 'CIEM_Azure_prod_ClientSecret'
        $stored.PSObject.Properties.Name | Should -Not -Contain 'ClientSecret'
    }

    It 'rejects provider and method combinations that are not registered' {
        {
            Save-CIEMAuthenticationProfile `
                -Name 'Broken Profile' `
                -Provider 'Email' `
                -Method 'ServicePrincipalSecret' `
                -Settings @{ Host = 'smtp.example.com'; Port = 587; TlsMode = 'StartTls' } `
                -SecretRefs @{}
        } | Should -Throw "*method 'ServicePrincipalSecret' is not valid for provider 'Email'*"
    }

    It 'rejects settings that do not match the field schema options' {
        {
            Save-CIEMAuthenticationProfile `
                -Name 'Broken SMTP Profile' `
                -Provider 'Email' `
                -Method 'SmtpAnonymous' `
                -Settings @{ Host = 'smtp.example.com'; Port = 587; TlsMode = 'BogusTls' } `
                -SecretRefs @{}
        } | Should -Throw "*field 'TlsMode' must be one of: None, StartTls, Ssl*"
    }

    It 'rejects numeric settings that cannot be parsed as numbers' {
        {
            Save-CIEMAuthenticationProfile `
                -Name 'Broken SMTP Port' `
                -Provider 'Email' `
                -Method 'SmtpAnonymous' `
                -Settings @{ Host = 'smtp.example.com'; Port = 'not-a-number'; TlsMode = 'None' } `
                -SecretRefs @{}
        } | Should -Throw "*field 'Port' must be a number*"
    }

    It 'updates an existing profile while preserving the original creation timestamp' {
        $profile = Save-CIEMAuthenticationProfile -Name 'SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp.example.com'
            Port = 25
            TlsMode = 'None'
        } -SecretRefs @{}

        $updated = Save-CIEMAuthenticationProfile -Id $profile.Id -Name 'SMTP Relay Updated' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp-updated.example.com'
            Port = 587
            TlsMode = 'StartTls'
        } -SecretRefs @{}

        $updated.Id | Should -Be $profile.Id
        $updated.Name | Should -Be 'SMTP Relay Updated'
        $updated.CreatedAt | Should -Be $profile.CreatedAt
        $updated.Settings.Host | Should -Be 'smtp-updated.example.com'
        [datetime]$updated.UpdatedAt | Should -BeGreaterOrEqual ([datetime]$profile.UpdatedAt)
    }

    It 'rejects provider or method changes while a profile is assigned' {
        $profile = Save-CIEMAuthenticationProfile -Name 'SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host    = 'smtp.example.com'
            Port    = 25
            TlsMode = 'None'
        } -SecretRefs @{}
        Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $profile.Id | Out-Null

        {
            Save-CIEMAuthenticationProfile -Id $profile.Id -Name 'Invalid Azure Profile' -Provider 'Azure' -Method 'ManagedIdentity' -Settings @{} -SecretRefs @{}
        } | Should -Throw "*assigned to NotificationChannel 'email-default'*cannot change provider or method*"

        $stored = Get-CIEMAuthenticationProfile -Id $profile.Id
        $stored.Provider | Should -Be 'Email'
        $stored.Method | Should -Be 'SmtpAnonymous'
    }

    It 'removes stale profile-owned secrets when updating an unassigned profile' {
        Mock -ModuleName Devolutions.CIEM Remove-CIEMSecret {}

        $profileId = 'owned-secret-update'
        Save-CIEMAuthenticationProfile -Id $profileId -Name 'SMTP Basic' -Provider 'Email' -Method 'SmtpBasic' -Settings @{
            Host     = 'smtp.example.com'
            Port     = 587
            TlsMode  = 'StartTls'
            Username = 'ciem'
        } -SecretRefs @{
            Password = "CIEM_AuthProfile_${profileId}_Password"
        } | Out-Null

        Save-CIEMAuthenticationProfile -Id $profileId -Name 'SMTP Anonymous' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host    = 'smtp.example.com'
            Port    = 25
            TlsMode = 'None'
        } -SecretRefs @{} | Out-Null

        Should -Invoke -ModuleName Devolutions.CIEM Remove-CIEMSecret -Times 1 -Exactly -ParameterFilter {
            $Name -eq "CIEM_AuthProfile_${profileId}_Password"
        }
    }

    It 'removes an unassigned profile' {
        $profile = Save-CIEMAuthenticationProfile -Name 'Removable SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp.example.com'
            Port = 25
            TlsMode = 'None'
        } -SecretRefs @{}

        Remove-CIEMAuthenticationProfile -Id $profile.Id

        @(Get-CIEMAuthenticationProfile -Id $profile.Id) | Should -HaveCount 0
    }

    It 'assigns one profile per provider discovery target' {
        $first = Save-CIEMAuthenticationProfile -Name 'Azure A' -Provider 'Azure' -Method 'ManagedIdentity' -Settings @{} -SecretRefs @{}
        $second = Save-CIEMAuthenticationProfile -Name 'Azure B' -Provider 'Azure' -Method 'ManagedIdentity' -Settings @{} -SecretRefs @{}

        Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure' -AuthenticationProfileId $first.Id | Out-Null
        Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure' -AuthenticationProfileId $second.Id | Out-Null

        $assignments = @(Get-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure')
        $assignments.Count | Should -Be 1
        $assignments[0].AuthenticationProfileId | Should -Be $second.Id
    }

    It 'rejects assigning a provider profile to a mismatched provider discovery target' {
        $profile = Save-CIEMAuthenticationProfile -Name 'AWS Access' -Provider 'AWS' -Method 'AccessKey' -Settings @{ Region = 'us-east-1' } -SecretRefs @{
            AccessKeyId = 'CIEM_AWS_prod_AccessKeyId'
            SecretAccessKey = 'CIEM_AWS_prod_SecretAccessKey'
        }

        {
            Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure' -AuthenticationProfileId $profile.Id
        } | Should -Throw "*provider 'AWS' cannot be assigned to provider discovery target 'Azure'*"
    }

    It 'rejects assigning a missing profile' {
        {
            Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure' -AuthenticationProfileId 'missing-profile'
        } | Should -Throw "*Authentication profile 'missing-profile' was not found*"
    }

    It 'assigns an Email profile to the Email notification channel' {
        $profile = Save-CIEMAuthenticationProfile -Name 'SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp.example.com'
            Port = 25
            TlsMode = 'None'
        } -SecretRefs @{}

        $assignment = Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $profile.Id

        $assignment.UsageType | Should -Be 'NotificationChannel'
        $assignment.UsageId | Should -Be 'email-default'
        $assignment.AuthenticationProfileId | Should -Be $profile.Id
    }

    It 'rejects unsupported notification channel assignment targets' {
        $profile = Save-CIEMAuthenticationProfile -Name 'SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp.example.com'
            Port = 25
            TlsMode = 'None'
        } -SecretRefs @{}

        {
            Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'slack-default' -AuthenticationProfileId $profile.Id
        } | Should -Throw "*Unsupported notification channel assignment target 'slack-default'*"
    }

    It 'rejects non-Email profiles for notification channel assignment' {
        $profile = Save-CIEMAuthenticationProfile -Name 'Azure Managed Identity' -Provider 'Azure' -Method 'ManagedIdentity' -Settings @{} -SecretRefs @{}

        {
            Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $profile.Id
        } | Should -Throw "*provider 'Azure' cannot be assigned to notification channel 'email-default'*"
    }

    It 'blocks removal while a profile is assigned' {
        $profile = Save-CIEMAuthenticationProfile -Name 'SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp.example.com'
            Port = 25
            TlsMode = 'None'
        } -SecretRefs @{}
        Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $profile.Id | Out-Null

        { Remove-CIEMAuthenticationProfile -Id $profile.Id } | Should -Throw "*assigned to NotificationChannel 'email-default'*"
    }

    It 'removes profile-owned secrets when removing an unassigned profile' {
        Mock -ModuleName Devolutions.CIEM Remove-CIEMSecret {}

        $profileId = 'owned-secret-remove'
        Save-CIEMAuthenticationProfile -Id $profileId -Name 'SMTP Basic' -Provider 'Email' -Method 'SmtpBasic' -Settings @{
            Host     = 'smtp.example.com'
            Port     = 587
            TlsMode  = 'StartTls'
            Username = 'ciem'
        } -SecretRefs @{
            Password = "CIEM_AuthProfile_${profileId}_Password"
        } | Out-Null

        Remove-CIEMAuthenticationProfile -Id $profileId

        Should -Invoke -ModuleName Devolutions.CIEM Remove-CIEMSecret -Times 1 -Exactly -ParameterFilter {
            $Name -eq "CIEM_AuthProfile_${profileId}_Password"
        }
    }

    It 'does not export legacy provider-specific authentication profile commands' {
        Get-Command -Module Devolutions.CIEM -Name 'Get-CIEMAzureAuthenticationProfile' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Module Devolutions.CIEM -Name 'Save-CIEMAzureAuthenticationProfile' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Module Devolutions.CIEM -Name 'Set-CIEMAWSAuthenticationProfile' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command -Module Devolutions.CIEM -Name 'Set-CIEMNotificationAuthenticationProfile' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'exports the generic authentication profile field schema command for PSU pages' {
        Get-Command -Module Devolutions.CIEM -Name 'Get-CIEMAuthenticationProfileFieldSchema' -ErrorAction Stop | Should -Not -BeNullOrEmpty

        $allSchemas = @(Get-CIEMAuthenticationProfileFieldSchema)
        @($allSchemas.provider | Sort-Object -Unique) | Should -Be @('AWS', 'Azure', 'Email')

        $schema = @(Get-CIEMAuthenticationProfileFieldSchema -Provider 'Email' -Method 'SmtpBasic')

        $schema.Count | Should -Be 1
        $schema[0].provider | Should -Be 'Email'
        $schema[0].method | Should -Be 'SmtpBasic'
        @($schema[0].fields.name) | Should -Contain 'Password'
    }
}

Describe 'Generic CIEM authentication profile runtime resolution' {
    BeforeEach {
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profile_assignments' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profiles' -AsNonQuery | Out-Null
        Mock -ModuleName Devolutions.CIEM Get-CIEMSecret {
            "resolved:$Name"
        }
    }

    It 'resolves Azure provider discovery authentication through assignments' {
        $profile = Save-CIEMAuthenticationProfile `
            -Name 'Production Azure' `
            -Provider 'Azure' `
            -Method 'ServicePrincipalSecret' `
            -Settings @{
                TenantId = '11111111-1111-1111-1111-111111111111'
                ClientId = '22222222-2222-2222-2222-222222222222'
            } `
            -SecretRefs @{ ClientSecret = 'CIEM_Azure_prod_ClientSecret' }
        Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure' -AuthenticationProfileId $profile.Id | Out-Null

        $resolved = InModuleScope Devolutions.CIEM {
            GetCIEMAssignedAuthenticationProfile -UsageType 'ProviderDiscovery' -UsageId 'Azure'
        }

        $resolved.Id | Should -Be $profile.Id
        $resolved.Provider | Should -Be 'Azure'
        $resolved.Secrets.ClientSecret | Should -Be 'resolved:CIEM_Azure_prod_ClientSecret'
    }

    It 'resolves AWS provider discovery authentication through assignments' {
        $profile = Save-CIEMAuthenticationProfile `
            -Name 'AWS Current Profile' `
            -Provider 'AWS' `
            -Method 'CurrentProfile' `
            -Settings @{
                Profile = 'ciem-prod'
                Region = 'us-east-1'
            } `
            -SecretRefs @{}
        Set-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'AWS' -AuthenticationProfileId $profile.Id | Out-Null

        $resolved = InModuleScope Devolutions.CIEM {
            GetCIEMAssignedAuthenticationProfile -UsageType 'ProviderDiscovery' -UsageId 'AWS'
        }

        $resolved.Id | Should -Be $profile.Id
        $resolved.Provider | Should -Be 'AWS'
        $resolved.Settings.Profile | Should -Be 'ciem-prod'
    }

    It 'resolves Email notification authentication through the default notification channel assignment' {
        $profile = Save-CIEMAuthenticationProfile `
            -Name 'SMTP Relay' `
            -Provider 'Email' `
            -Method 'SmtpBasic' `
            -Settings @{
                Host = 'smtp.example.com'
                Port = 587
                TlsMode = 'StartTls'
                Username = 'alerts@example.com'
            } `
            -SecretRefs @{ Password = 'CIEM_Email_default_Password' }
        Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $profile.Id | Out-Null

        $resolved = InModuleScope Devolutions.CIEM {
            GetCIEMAssignedAuthenticationProfile -UsageType 'NotificationChannel' -UsageId 'email-default'
        }

        $resolved.Id | Should -Be $profile.Id
        $resolved.Provider | Should -Be 'Email'
        $resolved.Secrets.Password | Should -Be 'resolved:CIEM_Email_default_Password'
    }

    It 'fails clearly when a provider discovery target has no assigned profile' {
        {
            InModuleScope Devolutions.CIEM {
                GetCIEMAssignedAuthenticationProfile -UsageType 'ProviderDiscovery' -UsageId 'Azure'
            }
        } | Should -Throw "*No authentication profile assignment found for ProviderDiscovery 'Azure'*"
    }

    It 'fails clearly when an assignment points at a deleted profile' {
        $databasePath = InModuleScope Devolutions.CIEM { $script:DatabasePath }
        $connection = Open-PSUSQLiteConnection -Database $databasePath
        try {
            Invoke-PSUSQLiteQuery -Connection $connection -Query 'PRAGMA foreign_keys=OFF' -AsNonQuery | Out-Null
            Invoke-PSUSQLiteQuery -Connection $connection -Query @"
INSERT INTO authentication_profile_assignments (
    usage_type, usage_id, authentication_profile_id, created_at, updated_at
)
VALUES (
    'NotificationChannel', 'email-default', 'deleted-profile', '2026-05-12T12:00:00Z', '2026-05-12T12:00:00Z'
)
"@ -AsNonQuery | Out-Null
        }
        finally {
            $connection.Dispose()
        }

        {
            InModuleScope Devolutions.CIEM {
                GetCIEMAssignedAuthenticationProfile -UsageType 'NotificationChannel' -UsageId 'email-default'
            }
        } | Should -Throw "*assigned to NotificationChannel 'email-default' was not found*"
    }
}

Describe 'Generic CIEM authentication profile connector source' {
    BeforeAll {
        $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..')
        $script:ConnectCIEMSource = Get-Content (Join-Path $moduleRoot 'Public' 'Connect-CIEM.ps1') -Raw
        $script:AzureConnectorSource = Get-Content (Join-Path $moduleRoot 'modules' 'Azure' 'Infrastructure' 'Public' 'Connect-CIEMAzure.ps1') -Raw
        $script:AWSConnectorSource = Get-Content (Join-Path $moduleRoot 'modules' 'AWS' 'Infrastructure' 'Public' 'Connect-CIEMAWS.ps1') -Raw
        $script:NotificationSource = Get-Content (Join-Path $moduleRoot 'modules' 'Devolutions.CIEM.Notifications' 'Public' 'Send-CIEMNotification.ps1') -Raw
        $script:AttackPathSource = Get-Content (Join-Path $moduleRoot 'modules' 'Devolutions.CIEM.Graph' 'Private' 'ResolveCIEMAttackPathRemediationScript.ps1') -Raw
    }

    It 'resolves provider discovery profiles before calling provider connectors' {
        $script:ConnectCIEMSource | Should -Match 'GetCIEMAssignedAuthenticationProfile\s+-UsageType ''ProviderDiscovery''\s+-UsageId \$p'
    }

    It 'keeps Azure connector on the generic provider discovery assignment path' {
        $script:AzureConnectorSource | Should -Match 'GetCIEMAssignedAuthenticationProfile\s+-UsageType ''ProviderDiscovery''\s+-UsageId ''Azure'''
        $script:AzureConnectorSource | Should -Not -Match 'Get-CIEMAzureAuthenticationProfile'
    }

    It 'keeps AWS connector on the generic provider discovery assignment path' {
        $script:AWSConnectorSource | Should -Match 'GetCIEMAssignedAuthenticationProfile\s+-UsageType ''ProviderDiscovery''\s+-UsageId ''AWS'''
        $script:AWSConnectorSource | Should -Not -Match 'AWSAuthProfileCacheKey'
        $script:AWSConnectorSource | Should -Not -Match 'Get-PSUCache'
    }

    It 'keeps Email sends on the generic notification channel assignment path' {
        $script:NotificationSource | Should -Match 'GetCIEMAssignedAuthenticationProfile\s+-UsageType ''NotificationChannel''\s+-UsageId ''email-default'''
        $script:NotificationSource | Should -Not -Match 'Get-CIEMNotificationAuthenticationProfile'
    }

    It 'keeps attack path remediation tokens on the generic provider discovery assignment path' {
        $script:AttackPathSource | Should -Match 'GetCIEMAssignedAuthenticationProfile\s+-UsageType ''ProviderDiscovery''\s+-UsageId ''Azure'''
        $script:AttackPathSource | Should -Not -Match 'Get-CIEMAzureAuthenticationProfile'
    }
}
