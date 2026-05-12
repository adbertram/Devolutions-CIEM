function Set-CIEMNotification {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [bool]$Enabled,

        [Parameter(Mandatory)]
        [ValidateSet('AnyDiscovery', 'ScheduledDiscovery', 'ManualOnly')]
        [string]$AutoSendScope,

        [Parameter(Mandatory)]
        [ValidateSet('NewRisk', 'RiskIncrease', 'RemovedRisk')]
        [string[]]$ChangeTypes,

        [Parameter(Mandatory)]
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info')]
        [string]$MinimumSeverity,

        [Parameter(Mandatory)]
        [string]$SubjectTemplate,

        [Parameter(Mandatory)]
        [string]$TextBodyTemplate,

        [Parameter(Mandatory)]
        [string]$HtmlBodyTemplate
    )

    $ErrorActionPreference = 'Stop'

    if ($ChangeTypes.Count -eq 0) {
        throw 'At least one notification change type is required.'
    }

    $id = 'exposure-change-default'
    $now = (Get-Date).ToString('o')
    $existing = @(Invoke-CIEMQuery -Query 'SELECT created_at FROM notifications WHERE id = @id' -Parameters @{ id = $id })
    $createdAt = if ($existing.Count -eq 1) { [string]$existing[0].created_at } else { $now }

    Invoke-CIEMQuery -Query @"
INSERT INTO notifications (
    id, name, type, enabled, auto_send_scope, change_types_json, minimum_severity,
    subject_template, text_body_template, html_body_template, created_at, updated_at
)
VALUES (
    @id, 'Exposure Change', 'ExposureChange', @enabled, @auto_send_scope, @change_types_json, @minimum_severity,
    @subject_template, @text_body_template, @html_body_template, @created_at, @updated_at
)
ON CONFLICT(id) DO UPDATE SET
    name = excluded.name,
    type = excluded.type,
    enabled = excluded.enabled,
    auto_send_scope = excluded.auto_send_scope,
    change_types_json = excluded.change_types_json,
    minimum_severity = excluded.minimum_severity,
    subject_template = excluded.subject_template,
    text_body_template = excluded.text_body_template,
    html_body_template = excluded.html_body_template,
    updated_at = excluded.updated_at
"@ -Parameters @{
        id                 = $id
        enabled            = [int]$Enabled
        auto_send_scope    = $AutoSendScope
        change_types_json  = ConvertToCIEMNotificationJson -InputObject @($ChangeTypes)
        minimum_severity   = $MinimumSeverity
        subject_template   = $SubjectTemplate
        text_body_template = $TextBodyTemplate
        html_body_template = $HtmlBodyTemplate
        created_at         = $createdAt
        updated_at         = $now
    } -AsNonQuery | Out-Null

    Get-CIEMNotification -Id $id
}
