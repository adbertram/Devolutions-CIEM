function Get-CIEMAzureDirectoryRoleAssignment {
    [CmdletBinding()]
    [OutputType([CIEMAzureDirectoryRoleAssignment[]])]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$PrincipalId,
        [Parameter()][string]$RoleName,
        [Parameter()][string]$RoleTemplateId
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('PrincipalId')) { $conditions += "principal_id = @principal_id"; $params.principal_id = $PrincipalId }
    if ($PSBoundParameters.ContainsKey('RoleName')) { $conditions += "role_name = @role_name"; $params.role_name = $RoleName }
    if ($PSBoundParameters.ContainsKey('RoleTemplateId')) { $conditions += "role_template_id = @role_template_id"; $params.role_template_id = $RoleTemplateId }
    $query = "SELECT * FROM azure_directory_role_assignments"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureDirectoryRoleAssignment]::new()
        $obj.Id = $row.id; $obj.ProviderId = $row.provider_id; $obj.PrincipalId = $row.principal_id
        $obj.RoleName = $row.role_name; $obj.RoleTemplateId = $row.role_template_id
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
