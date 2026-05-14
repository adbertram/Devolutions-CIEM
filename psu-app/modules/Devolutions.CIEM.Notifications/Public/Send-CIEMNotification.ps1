function Send-CIEMNotification {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [int]$CurrentDiscoveryRunId,

        [Parameter(Mandatory)]
        [ValidateSet('Manual', 'ScheduledDiscovery')]
        [string]$InvocationSource,

        [Parameter()]
        [switch]$Test
    )

    $ErrorActionPreference = 'Stop'

    if (-not $Test -and -not $PSBoundParameters.ContainsKey('CurrentDiscoveryRunId')) {
        throw 'CurrentDiscoveryRunId is required unless -Test is specified.'
    }

    $enabledNotifications = @(Get-CIEMNotification | Where-Object { $_.Enabled -and $_.Type -eq 'ExposureChange' })
    if ($enabledNotifications.Count -eq 0) {
        return [PSCustomObject]@{
            SentCount   = 0
            FailedCount = 0
            SkippedCount = 0
        }
    }
    if ($enabledNotifications.Count -ne 1) {
        throw 'CIEM notifications V1 supports exactly one enabled ExposureChange notification.'
    }
    $notification = $enabledNotifications[0]

    $scopeAllowsSend = switch ($notification.AutoSendScope) {
        'AnyDiscovery' { $true }
        'ScheduledDiscovery' { $InvocationSource -eq 'ScheduledDiscovery' }
        'ManualOnly' { $InvocationSource -eq 'Manual' }
    }
    if (-not $scopeAllowsSend) {
        return [PSCustomObject]@{
            SentCount   = 0
            FailedCount = 0
            SkippedCount = 0
        }
    }

    $enabledChannels = @(Get-CIEMNotificationChannel | Where-Object { $_.Enabled -and $_.Type -eq 'Email' })
    if ($enabledChannels.Count -eq 0) {
        return [PSCustomObject]@{
            SentCount   = 0
            FailedCount = 0
            SkippedCount = 0
        }
    }
    if ($enabledChannels.Count -ne 1) {
        throw 'CIEM notifications V1 supports exactly one enabled Email notification channel.'
    }
    $channel = $enabledChannels[0]

    $profile = GetCIEMAssignedAuthenticationProfile -UsageType 'NotificationChannel' -UsageId 'email-default'

    $changes = if ($Test) {
        @([PSCustomObject]@{
            Id                    = 'test-notification'
            CurrentDiscoveryRunId = 0
            ChangeType            = 'NewRisk'
            Severity              = 'Critical'
            SeverityRank          = 1
            Title                 = 'Test exposure change notification'
            Evidence              = 'This is a test notification from the CIEM configuration page.'
            ImpactedIdentityName  = 'Test Identity'
            ImpactedResourceName  = 'Test Resource'
        })
    }
    else {
        @(Get-CIEMExposureChange -CurrentDiscoveryRunId $CurrentDiscoveryRunId)
    }

    $minimumSeverityRank = GetCIEMNotificationSeverityRank -Severity $notification.MinimumSeverity
    $matchingChanges = @($changes | Where-Object {
        $notification.ChangeTypes -contains $_.ChangeType -and [int]$_.SeverityRank -le $minimumSeverityRank
    })

    $sentCount = 0
    $failedCount = 0
    $recipientSummary = "To: $($channel.ToRecipients -join ', ')"
    if ($channel.CcRecipients.Count -gt 0) {
        $recipientSummary += "; Cc: $($channel.CcRecipients -join ', ')"
    }
    if ($channel.BccRecipients.Count -gt 0) {
        $recipientSummary += "; Bcc: $($channel.BccRecipients -join ', ')"
    }

    foreach ($change in $matchingChanges) {
        $templateValues = @{
            Severity              = $change.Severity
            Title                 = $change.Title
            Evidence              = $change.Evidence
            ChangeType            = $change.ChangeType
            Identity              = $change.ImpactedIdentityName
            Target                = $change.ImpactedResourceName
            CurrentDiscoveryRunId = $change.CurrentDiscoveryRunId
            SourceSignalId        = $change.Id
        }

        $subject = FormatCIEMNotificationTemplate -Template $notification.SubjectTemplate -Values $templateValues
        $textBody = FormatCIEMNotificationTemplate -Template $notification.TextBodyTemplate -Values $templateValues
        $htmlBody = FormatCIEMNotificationTemplate -Template $notification.HtmlBodyTemplate -Values $templateValues
        $attemptedAt = (Get-Date).ToString('o')

        try {
            $sendResult = SendCIEMEmailMessage -AuthenticationProfile $profile -Channel $channel -Subject $subject -TextBody $textBody -HtmlBody $htmlBody
            SaveCIEMNotificationHistory `
                -NotificationId $notification.Id `
                -ChannelId $channel.Id `
                -SourceSignalId ([string]$change.Id) `
                -SourceSignalType 'ExposureChange' `
                -Status 'Succeeded' `
                -AttemptedAt $attemptedAt `
                -MessageId $sendResult.MessageId `
                -RecipientSummary $recipientSummary
            $sentCount++
        }
        catch {
            $failedCount++
            SaveCIEMNotificationHistory `
                -NotificationId $notification.Id `
                -ChannelId $channel.Id `
                -SourceSignalId ([string]$change.Id) `
                -SourceSignalType 'ExposureChange' `
                -Status 'Failed' `
                -AttemptedAt $attemptedAt `
                -RecipientSummary $recipientSummary `
                -ErrorMessage $_.Exception.Message
        }
    }

    if ($failedCount -gt 0) {
        throw "notification send failed: $failedCount failure(s)"
    }

    [PSCustomObject]@{
        SentCount    = $sentCount
        FailedCount  = $failedCount
        SkippedCount = $changes.Count - $matchingChanges.Count
    }
}
