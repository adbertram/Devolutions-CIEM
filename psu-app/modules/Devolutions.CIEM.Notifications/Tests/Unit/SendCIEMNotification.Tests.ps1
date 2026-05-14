BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    function AddTestExposureChange {
        param(
            [Parameter(Mandatory)][int]$RunId,
            [Parameter(Mandatory)][string]$Id,
            [Parameter(Mandatory)][string]$ChangeType,
            [Parameter(Mandatory)][string]$Severity,
            [Parameter(Mandatory)][int]$SeverityRank,
            [Parameter(Mandatory)][string]$Title
        )

        $ErrorActionPreference = 'Stop'

        Invoke-CIEMQuery -Query @"
INSERT INTO ciem_exposure_changes (
    id, previous_discovery_run_id, current_discovery_run_id, exposure_key,
    change_type, exposure_type, severity, severity_rank, title, previous_severity,
    current_severity, impacted_identity_id, impacted_identity_name,
    impacted_identity_type, impacted_resource_id, impacted_resource_name,
    first_seen_at, previous_state_json, current_state_json, evidence, created_at
)
VALUES (
    @id, NULL, @run_id, @exposure_key,
    @change_type, 'IdentityRisk', @severity, @severity_rank, @title, NULL,
    @severity, 'user-notify', 'Notification User',
    'User', '/subscriptions/prod', 'Production Subscription',
    '2026-05-12T12:00:00Z', NULL, '{}', @evidence, '2026-05-12T12:00:00Z'
)
"@ -Parameters @{
            id            = $Id
            run_id        = $RunId
            exposure_key  = "identity:$Id"
            change_type   = $ChangeType
            severity      = $Severity
            severity_rank = $SeverityRank
            title         = $Title
            evidence      = "$Title evidence"
        } -AsNonQuery | Out-Null
    }

    function InitializeTestNotificationConfiguration {
        $profile = Save-CIEMAuthenticationProfile -Name 'SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp-relay.example.com'
            Port = 25
            TlsMode = 'None'
        } -SecretRefs @{}
        Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $profile.Id | Out-Null
        Set-CIEMNotificationChannel -Enabled $true -FromAddress 'ciem@example.com' -ToRecipients @('security@example.com') | Out-Null
        Set-CIEMNotification -Enabled $true -AutoSendScope 'AnyDiscovery' -ChangeTypes @('NewRisk', 'RiskIncrease') -MinimumSeverity 'High' -SubjectTemplate '[CIEM] {{Severity}} {{Title}}' -TextBodyTemplate 'Text {{Title}} {{Evidence}}' -HtmlBodyTemplate '<p>HTML {{Title}} {{Evidence}}</p>' | Out-Null
    }
}

Describe 'Send-CIEMNotification' {
    BeforeEach {
        Mock -ModuleName Devolutions.CIEM SendCIEMEmailMessage {
            [PSCustomObject]@{ MessageId = 'smtp-test-message' }
        }

        Invoke-CIEMQuery -Query 'DELETE FROM notification_history' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM notifications' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM notification_channels' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profile_assignments' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM authentication_profiles' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM ciem_exposure_changes' -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query 'DELETE FROM azure_discovery_runs' -AsNonQuery | Out-Null
    }

    It 'sends matching exposure changes and records simple notification history rows' {
        InitializeTestNotificationConfiguration
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-12T12:00:00Z' -CompletedAt '2026-05-12T12:10:00Z'
        AddTestExposureChange -RunId $run.Id -Id 'critical-new' -ChangeType 'NewRisk' -Severity 'Critical' -SeverityRank 1 -Title 'Critical new risk'

        $result = Send-CIEMNotification -CurrentDiscoveryRunId $run.Id -InvocationSource 'Manual'

        $result.SentCount | Should -Be 1
        $history = @(Get-CIEMNotificationHistory)
        $history | Should -HaveCount 1
        $history[0].Status | Should -Be 'Succeeded'
        $history[0].SourceSignalId | Should -Be 'critical-new'
        Should -Invoke -CommandName SendCIEMEmailMessage -ModuleName Devolutions.CIEM -Times 1 -Exactly
    }

    It 'does not send exposure changes outside configured change type and severity filters' {
        InitializeTestNotificationConfiguration
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-12T12:00:00Z' -CompletedAt '2026-05-12T12:10:00Z'
        AddTestExposureChange -RunId $run.Id -Id 'removed-risk' -ChangeType 'RemovedRisk' -Severity 'Critical' -SeverityRank 1 -Title 'Removed risk'
        AddTestExposureChange -RunId $run.Id -Id 'medium-new' -ChangeType 'NewRisk' -Severity 'Medium' -SeverityRank 3 -Title 'Medium new risk'

        $result = Send-CIEMNotification -CurrentDiscoveryRunId $run.Id -InvocationSource 'Manual'

        $result.SentCount | Should -Be 0
        @(Get-CIEMNotificationHistory) | Should -HaveCount 0
        Should -Invoke -CommandName SendCIEMEmailMessage -ModuleName Devolutions.CIEM -Times 0 -Exactly
    }

    It 'attempts all matching sends and throws after recording failures' {
        InitializeTestNotificationConfiguration
        Mock -ModuleName Devolutions.CIEM SendCIEMEmailMessage { throw 'smtp unavailable' }
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-12T12:00:00Z' -CompletedAt '2026-05-12T12:10:00Z'
        AddTestExposureChange -RunId $run.Id -Id 'critical-failure' -ChangeType 'NewRisk' -Severity 'Critical' -SeverityRank 1 -Title 'Critical failure risk'

        { Send-CIEMNotification -CurrentDiscoveryRunId $run.Id -InvocationSource 'Manual' } | Should -Throw '*notification send failed*'

        $history = @(Get-CIEMNotificationHistory)
        $history | Should -HaveCount 1
        $history[0].Status | Should -Be 'Failed'
        $history[0].ErrorMessage | Should -Be 'smtp unavailable'
    }

    It 'does not send when invocation source is excluded by auto-send scope' {
        $profile = Save-CIEMAuthenticationProfile -Name 'SMTP Relay' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{
            Host = 'smtp-relay.example.com'
            Port = 25
            TlsMode = 'None'
        } -SecretRefs @{}
        Set-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default' -AuthenticationProfileId $profile.Id | Out-Null
        Set-CIEMNotificationChannel -Enabled $true -FromAddress 'ciem@example.com' -ToRecipients @('security@example.com') | Out-Null
        Set-CIEMNotification -Enabled $true -AutoSendScope 'ScheduledDiscovery' -ChangeTypes @('NewRisk') -MinimumSeverity 'High' -SubjectTemplate '[CIEM] {{Title}}' -TextBodyTemplate 'Text {{Title}}' -HtmlBodyTemplate '<p>{{Title}}</p>' | Out-Null
        $run = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Completed' -StartedAt '2026-05-12T12:00:00Z' -CompletedAt '2026-05-12T12:10:00Z'
        AddTestExposureChange -RunId $run.Id -Id 'critical-manual' -ChangeType 'NewRisk' -Severity 'Critical' -SeverityRank 1 -Title 'Critical manual risk'

        $result = Send-CIEMNotification -CurrentDiscoveryRunId $run.Id -InvocationSource 'Manual'

        $result.SentCount | Should -Be 0
        Should -Invoke -CommandName SendCIEMEmailMessage -ModuleName Devolutions.CIEM -Times 0 -Exactly
    }
}

Describe 'SendCIEMEmailMessage' {
    BeforeEach {
        $script:EmailProfile = [pscustomobject]@{
            Id         = 'email-profile'
            Provider   = 'Email'
            Method     = 'SmtpAnonymous'
            Settings   = [pscustomobject]@{
                Host    = 'smtp.example.com'
                Port    = 25
                TlsMode = 'None'
            }
            Secrets    = [pscustomobject]@{}
            SecretRefs = [pscustomobject]@{}
        }
        $script:EmailChannel = [pscustomobject]@{
            Id            = 'email-default'
            Type          = 'Email'
            FromAddress   = 'ciem@example.com'
            ToRecipients  = @('security@example.com')
            CcRecipients  = @()
            BccRecipients = @()
        }
    }

    It 'rejects non-Email authentication profiles before sending' {
        $script:EmailProfile.Provider = 'Azure'

        {
            InModuleScope Devolutions.CIEM -Parameters @{ Profile = $script:EmailProfile; Channel = $script:EmailChannel } {
                param($Profile, $Channel)
                SendCIEMEmailMessage -AuthenticationProfile $Profile -Channel $Channel -Subject 'Subject' -TextBody 'Text' -HtmlBody '<p>Text</p>'
            }
        } | Should -Throw "*must have provider Email*"
    }

    It 'rejects non-Email notification channels before sending' {
        $script:EmailChannel.Type = 'Slack'

        {
            InModuleScope Devolutions.CIEM -Parameters @{ Profile = $script:EmailProfile; Channel = $script:EmailChannel } {
                param($Profile, $Channel)
                SendCIEMEmailMessage -AuthenticationProfile $Profile -Channel $Channel -Subject 'Subject' -TextBody 'Text' -HtmlBody '<p>Text</p>'
            }
        } | Should -Throw "*must be type Email*"
    }

    It 'rejects unsupported TLS modes before sending' {
        $script:EmailProfile.Settings.TlsMode = 'BogusTls'

        {
            InModuleScope Devolutions.CIEM -Parameters @{ Profile = $script:EmailProfile; Channel = $script:EmailChannel } {
                param($Profile, $Channel)
                SendCIEMEmailMessage -AuthenticationProfile $Profile -Channel $Channel -Subject 'Subject' -TextBody 'Text' -HtmlBody '<p>Text</p>'
            }
        } | Should -Throw "*Unsupported SMTP TLS mode 'BogusTls'*"
    }

    It 'rejects SmtpBasic profiles when the resolved password is empty' {
        $script:EmailProfile.Method = 'SmtpBasic'
        $script:EmailProfile.Settings | Add-Member -NotePropertyName Username -NotePropertyValue 'alerts@example.com'
        $script:EmailProfile.Secrets | Add-Member -NotePropertyName Password -NotePropertyValue ''
        $script:EmailProfile.SecretRefs | Add-Member -NotePropertyName Password -NotePropertyValue 'CIEM_AuthProfile_email_Password'

        {
            InModuleScope Devolutions.CIEM -Parameters @{ Profile = $script:EmailProfile; Channel = $script:EmailChannel } {
                param($Profile, $Channel)
                SendCIEMEmailMessage -AuthenticationProfile $Profile -Channel $Channel -Subject 'Subject' -TextBody 'Text' -HtmlBody '<p>Text</p>'
            }
        } | Should -Throw "*did not return a password*"
    }
}
