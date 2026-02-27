function Get-CIEMAzureRoleDefinition {
    [CmdletBinding()]
    [OutputType([CIEMAzureRoleDefinition[]])]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$RoleName,
        [Parameter()][string]$RoleType
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('RoleName')) { $conditions += "role_name = @role_name"; $params.role_name = $RoleName }
    if ($PSBoundParameters.ContainsKey('RoleType')) { $conditions += "role_type = @role_type"; $params.role_type = $RoleType }
    $query = "SELECT * FROM azure_role_definitions"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureRoleDefinition]::new()
        $obj.Id = $row.id; $obj.ProviderId = $row.provider_id; $obj.RoleName = $row.role_name
        $obj.RoleType = $row.role_type; $obj.Description = $row.description
        $obj.AssignableScopes = $row.assignable_scopes
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
