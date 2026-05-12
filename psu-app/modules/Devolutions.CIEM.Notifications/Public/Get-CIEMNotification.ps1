function Get-CIEMNotification {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$Id
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT id, name, type, enabled, auto_send_scope, change_types_json, minimum_severity,
       subject_template, text_body_template, html_body_template, created_at, updated_at
FROM notifications
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
            Id               = [string]$row.id
            Name             = [string]$row.name
            Type             = [string]$row.type
            Enabled          = [bool]([int]$row.enabled)
            AutoSendScope    = [string]$row.auto_send_scope
            ChangeTypes      = [string[]]@(ConvertFromCIEMNotificationJsonArray -Json ([string]$row.change_types_json))
            MinimumSeverity  = [string]$row.minimum_severity
            SubjectTemplate  = [string]$row.subject_template
            TextBodyTemplate = [string]$row.text_body_template
            HtmlBodyTemplate = [string]$row.html_body_template
            CreatedAt        = [string]$row.created_at
            UpdatedAt        = [string]$row.updated_at
        }
    })
}
