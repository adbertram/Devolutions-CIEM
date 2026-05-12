function Get-CIEMNotificationHistory {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$Last
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT id, notification_id, channel_id, source_signal_id, source_signal_type,
       status, attempted_at, completed_at, message_id, recipient_summary, error_message
FROM notification_history
ORDER BY attempted_at DESC, id DESC
"@
    $parameters = @{}
    if ($PSBoundParameters.ContainsKey('Last')) {
        $query += "`nLIMIT @last"
        $parameters.last = $Last
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)
    @(foreach ($row in $rows) {
        [PSCustomObject]@{
            Id               = [int]$row.id
            NotificationId   = [string]$row.notification_id
            ChannelId        = [string]$row.channel_id
            SourceSignalId   = [string]$row.source_signal_id
            SourceSignalType = [string]$row.source_signal_type
            Status           = [string]$row.status
            AttemptedAt      = [string]$row.attempted_at
            CompletedAt      = [string]$row.completed_at
            MessageId        = [string]$row.message_id
            RecipientSummary = [string]$row.recipient_summary
            ErrorMessage     = [string]$row.error_message
        }
    })
}
