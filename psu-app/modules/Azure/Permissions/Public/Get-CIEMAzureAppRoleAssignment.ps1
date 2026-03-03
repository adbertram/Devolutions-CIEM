function Get-CIEMAzureAppRoleAssignment {
    [CmdletBinding()]
    [OutputType('CIEMAzureAppRoleAssignment[]')]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$PrincipalId,
        [Parameter()][string]$PrincipalType,
        [Parameter()][string]$ResourceId,
        [Parameter()][string]$AppRoleId
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('PrincipalId')) { $conditions += "principal_id = @principal_id"; $params.principal_id = $PrincipalId }
    if ($PSBoundParameters.ContainsKey('PrincipalType')) { $conditions += "principal_type = @principal_type"; $params.principal_type = $PrincipalType }
    if ($PSBoundParameters.ContainsKey('ResourceId')) { $conditions += "resource_id = @resource_id"; $params.resource_id = $ResourceId }
    if ($PSBoundParameters.ContainsKey('AppRoleId')) { $conditions += "app_role_id = @app_role_id"; $params.app_role_id = $AppRoleId }
    $query = "SELECT * FROM azure_app_role_assignments"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureAppRoleAssignment]::new()
        $obj.Id = $row.id; $obj.ProviderId = $row.provider_id; $obj.PrincipalId = $row.principal_id
        $obj.PrincipalType = $row.principal_type; $obj.ResourceId = $row.resource_id
        $obj.ResourceDisplayName = $row.resource_display_name
        $obj.AppRoleId = $row.app_role_id; $obj.AppRoleValue = $row.app_role_value
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
