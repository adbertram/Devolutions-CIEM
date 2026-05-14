function Get-CIEMAuthenticationProfile {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [string]$Id,

        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Method,

        [Parameter()]
        [switch]$ResolveSecrets
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT id, name, provider, method, settings_json, secret_refs_json, created_at, updated_at
FROM authentication_profiles
"@
    $where = [System.Collections.Generic.List[string]]::new()
    $parameters = @{}

    if ($PSBoundParameters.ContainsKey('Id')) {
        $where.Add('id = @id')
        $parameters.id = $Id
    }
    if ($PSBoundParameters.ContainsKey('Provider')) {
        $where.Add('provider = @provider')
        $parameters.provider = $Provider
    }
    if ($PSBoundParameters.ContainsKey('Method')) {
        $where.Add('method = @method')
        $parameters.method = $Method
    }
    if ($where.Count -gt 0) {
        $query += "`nWHERE $($where -join ' AND ')"
    }
    $query += "`nORDER BY name ASC"

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        $assignments = @(Invoke-CIEMQuery -Query @"
SELECT usage_type, usage_id, authentication_profile_id, created_at, updated_at
FROM authentication_profile_assignments
WHERE authentication_profile_id = @id
ORDER BY usage_type ASC, usage_id ASC
"@ -Parameters @{ id = [string]$row.id })
        $secretRefs = ConvertFromCIEMAuthenticationProfileJson -Json ([string]$row.secret_refs_json)
        $profile = [PSCustomObject]@{
            Id          = [string]$row.id
            Name        = [string]$row.name
            Provider    = [string]$row.provider
            Method      = [string]$row.method
            Settings    = ConvertFromCIEMAuthenticationProfileJson -Json ([string]$row.settings_json)
            SecretRefs  = $secretRefs
            Assignments = @($assignments | ForEach-Object {
                [PSCustomObject]@{
                    UsageType = [string]$_.usage_type
                    UsageId   = [string]$_.usage_id
                }
            })
            AppliesTo   = @($assignments | ForEach-Object { "$($_.usage_type):$($_.usage_id)" })
            CreatedAt   = [string]$row.created_at
            UpdatedAt   = [string]$row.updated_at
        }

        if ($ResolveSecrets) {
            $secrets = [ordered]@{}
            foreach ($secretProperty in @($secretRefs.PSObject.Properties)) {
                $secrets[$secretProperty.Name] = Get-CIEMSecret -Name ([string]$secretProperty.Value)
            }
            $profile | Add-Member -NotePropertyName 'Secrets' -NotePropertyValue ([PSCustomObject]$secrets)
        }

        $profile
    })
}
