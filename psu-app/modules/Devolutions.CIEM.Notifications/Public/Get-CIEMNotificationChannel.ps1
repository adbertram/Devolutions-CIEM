function Get-CIEMNotificationChannel {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$Id
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT id, name, type, enabled, authentication_profile_id, from_address,
       to_recipients_json, cc_recipients_json, bcc_recipients_json,
       created_at, updated_at
FROM notification_channels
"@
    $parameters = @{}

    if ($PSBoundParameters.ContainsKey('Id')) {
        $query += "`nWHERE id = @id"
        $parameters.id = $Id
    }

    $query += "`nORDER BY name ASC"
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        [PSCustomObject]@{
            Id                      = [string]$row.id
            Name                    = [string]$row.name
            Type                    = [string]$row.type
            Enabled                 = [bool]([int]$row.enabled)
            AuthenticationProfileId = [string]$row.authentication_profile_id
            FromAddress             = [string]$row.from_address
            ToRecipients            = [string[]]@(ConvertFromCIEMNotificationJsonArray -Json ([string]$row.to_recipients_json))
            CcRecipients            = [string[]]@(ConvertFromCIEMNotificationJsonArray -Json ([string]$row.cc_recipients_json))
            BccRecipients           = [string[]]@(ConvertFromCIEMNotificationJsonArray -Json ([string]$row.bcc_recipients_json))
            CreatedAt               = [string]$row.created_at
            UpdatedAt               = [string]$row.updated_at
        }
    })
}
