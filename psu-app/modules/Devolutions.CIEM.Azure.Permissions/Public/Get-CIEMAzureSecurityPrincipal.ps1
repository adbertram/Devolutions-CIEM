function Get-CIEMAzureSecurityPrincipal {
    [CmdletBinding()]
    [OutputType([CIEMAzureSecurityPrincipal[]])]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$Type,
        [Parameter()][string]$Category,
        [Parameter()][string]$UserPrincipalName,
        [Parameter()][string]$AppId
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('Type')) { $conditions += "type = @type"; $params.type = $Type }
    if ($PSBoundParameters.ContainsKey('Category')) { $conditions += "category = @category"; $params.category = $Category }
    if ($PSBoundParameters.ContainsKey('UserPrincipalName')) { $conditions += "user_principal_name = @upn"; $params.upn = $UserPrincipalName }
    if ($PSBoundParameters.ContainsKey('AppId')) { $conditions += "app_id = @app_id"; $params.app_id = $AppId }
    $query = "SELECT * FROM azure_security_principals"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureSecurityPrincipal]::new()
        $obj.Id = $row.id; $obj.ProviderId = $row.provider_id; $obj.Type = $row.type
        $obj.DisplayName = $row.display_name; $obj.Enabled = if ($null -ne $row.enabled) { [bool]$row.enabled } else { $null }
        $obj.Category = $row.category; $obj.PrincipalType = $row.principal_type
        $obj.UserPrincipalName = $row.user_principal_name; $obj.UserType = $row.user_type
        $obj.AppId = $row.app_id; $obj.ServicePrincipalType = $row.service_principal_type
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
