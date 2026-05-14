function Get-CIEMAuthenticationProfileAssignment {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [ValidateSet('ProviderDiscovery', 'NotificationChannel')]
        [string]$UsageType,

        [Parameter()]
        [string]$UsageId,

        [Parameter()]
        [string]$AuthenticationProfileId
    )

    $ErrorActionPreference = 'Stop'

    $query = @"
SELECT usage_type, usage_id, authentication_profile_id, created_at, updated_at
FROM authentication_profile_assignments
"@
    $where = [System.Collections.Generic.List[string]]::new()
    $parameters = @{}

    if ($PSBoundParameters.ContainsKey('UsageType')) {
        $where.Add('usage_type = @usage_type')
        $parameters.usage_type = $UsageType
    }
    if ($PSBoundParameters.ContainsKey('UsageId')) {
        $where.Add('usage_id = @usage_id')
        $parameters.usage_id = $UsageId
    }
    if ($PSBoundParameters.ContainsKey('AuthenticationProfileId')) {
        $where.Add('authentication_profile_id = @authentication_profile_id')
        $parameters.authentication_profile_id = $AuthenticationProfileId
    }
    if ($where.Count -gt 0) {
        $query += "`nWHERE $($where -join ' AND ')"
    }
    $query += "`nORDER BY usage_type ASC, usage_id ASC"

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)
    @(foreach ($row in $rows) {
        [PSCustomObject]@{
            UsageType               = [string]$row.usage_type
            UsageId                 = [string]$row.usage_id
            AuthenticationProfileId = [string]$row.authentication_profile_id
            CreatedAt               = [string]$row.created_at
            UpdatedAt               = [string]$row.updated_at
        }
    })
}
