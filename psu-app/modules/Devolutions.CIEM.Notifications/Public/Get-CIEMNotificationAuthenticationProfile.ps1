function Get-CIEMNotificationAuthenticationProfile {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$Id
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT id, name, type, method, settings_json, secret_refs_json, created_at, updated_at
FROM notification_authentication_profiles
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
            Id         = [string]$row.id
            Name       = [string]$row.name
            Type       = [string]$row.type
            Method     = [string]$row.method
            Settings   = ConvertFromCIEMNotificationJson -Json ([string]$row.settings_json)
            SecretRefs = ConvertFromCIEMNotificationJson -Json ([string]$row.secret_refs_json)
            CreatedAt  = [string]$row.created_at
            UpdatedAt  = [string]$row.updated_at
        }
    })
}
