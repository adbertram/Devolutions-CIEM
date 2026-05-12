function Set-CIEMNotificationChannel {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled,

        [Parameter(Mandatory)]
        [string]$AuthenticationProfileId,

        [Parameter(Mandatory)]
        [string]$FromAddress,

        [Parameter(Mandatory)]
        [string[]]$ToRecipients,

        [Parameter()]
        [string[]]$CcRecipients = @(),

        [Parameter()]
        [string[]]$BccRecipients = @()
    )

    $ErrorActionPreference = 'Stop'

    $profile = @(Get-CIEMNotificationAuthenticationProfile -Id $AuthenticationProfileId)
    if ($profile.Count -ne 1) {
        throw "Notification authentication profile '$AuthenticationProfileId' was not found."
    }
    if ($profile[0].Type -ne 'Email') {
        throw "Notification authentication profile '$AuthenticationProfileId' must be type Email."
    }

    $allRecipients = @($ToRecipients) + @($CcRecipients) + @($BccRecipients)
    if ($allRecipients.Count -eq 0) {
        throw 'At least one notification channel recipient is required.'
    }

    $id = 'email-default'
    $now = (Get-Date).ToString('o')
    $existing = @(Invoke-CIEMQuery -Query 'SELECT created_at FROM notification_channels WHERE id = @id' -Parameters @{ id = $id })
    $createdAt = if ($existing.Count -eq 1) { [string]$existing[0].created_at } else { $now }

    Invoke-CIEMQuery -Query @"
INSERT INTO notification_channels (
    id, name, type, enabled, authentication_profile_id, from_address,
    to_recipients_json, cc_recipients_json, bcc_recipients_json,
    created_at, updated_at
)
VALUES (
    @id, 'Email', 'Email', @enabled, @authentication_profile_id, @from_address,
    @to_recipients_json, @cc_recipients_json, @bcc_recipients_json,
    @created_at, @updated_at
)
ON CONFLICT(id) DO UPDATE SET
    name = excluded.name,
    type = excluded.type,
    enabled = excluded.enabled,
    authentication_profile_id = excluded.authentication_profile_id,
    from_address = excluded.from_address,
    to_recipients_json = excluded.to_recipients_json,
    cc_recipients_json = excluded.cc_recipients_json,
    bcc_recipients_json = excluded.bcc_recipients_json,
    updated_at = excluded.updated_at
"@ -Parameters @{
        id                        = $id
        enabled                   = [int]$Enabled
        authentication_profile_id = $AuthenticationProfileId
        from_address              = $FromAddress
        to_recipients_json        = ConvertToCIEMNotificationJson -InputObject @($ToRecipients)
        cc_recipients_json        = ConvertToCIEMNotificationJson -InputObject @($CcRecipients)
        bcc_recipients_json       = ConvertToCIEMNotificationJson -InputObject @($BccRecipients)
        created_at                = $createdAt
        updated_at                = $now
    } -AsNonQuery | Out-Null

    Get-CIEMNotificationChannel -Id $id
}
