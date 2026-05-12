function SaveCIEMNotificationHistory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$NotificationId,

        [Parameter(Mandatory)]
        [string]$ChannelId,

        [Parameter(Mandatory)]
        [string]$SourceSignalId,

        [Parameter(Mandatory)]
        [string]$SourceSignalType,

        [Parameter(Mandatory)]
        [ValidateSet('Succeeded', 'Failed')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$AttemptedAt,

        [Parameter()]
        [string]$MessageId,

        [Parameter()]
        [string]$RecipientSummary,

        [Parameter()]
        [string]$ErrorMessage
    )

    $ErrorActionPreference = 'Stop'

    Invoke-CIEMQuery -Query @"
INSERT INTO notification_history (
    notification_id, channel_id, source_signal_id, source_signal_type,
    status, attempted_at, completed_at, message_id, recipient_summary, error_message
)
VALUES (
    @notification_id, @channel_id, @source_signal_id, @source_signal_type,
    @status, @attempted_at, @completed_at, @message_id, @recipient_summary, @error_message
)
"@ -Parameters @{
        notification_id   = $NotificationId
        channel_id        = $ChannelId
        source_signal_id  = $SourceSignalId
        source_signal_type = $SourceSignalType
        status            = $Status
        attempted_at      = $AttemptedAt
        completed_at      = (Get-Date).ToString('o')
        message_id        = $MessageId
        recipient_summary = $RecipientSummary
        error_message     = $ErrorMessage
    } -AsNonQuery | Out-Null
}
