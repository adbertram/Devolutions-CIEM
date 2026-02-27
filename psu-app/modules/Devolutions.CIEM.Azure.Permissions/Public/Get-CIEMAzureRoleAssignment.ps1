function Get-CIEMAzureRoleAssignment {
    [CmdletBinding()]
    [OutputType([CIEMAzureRoleAssignment[]])]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$PrincipalId,
        [Parameter()][string]$PrincipalType,
        [Parameter()][string]$RoleDefinitionId,
        [Parameter()][string]$Scope
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('PrincipalId')) { $conditions += "principal_id = @principal_id"; $params.principal_id = $PrincipalId }
    if ($PSBoundParameters.ContainsKey('PrincipalType')) { $conditions += "principal_type = @principal_type"; $params.principal_type = $PrincipalType }
    if ($PSBoundParameters.ContainsKey('RoleDefinitionId')) { $conditions += "role_definition_id = @role_definition_id"; $params.role_definition_id = $RoleDefinitionId }
    if ($PSBoundParameters.ContainsKey('Scope')) { $conditions += "scope = @scope"; $params.scope = $Scope }
    $query = "SELECT * FROM azure_role_assignments"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureRoleAssignment]::new()
        $obj.Id = $row.id; $obj.ProviderId = $row.provider_id; $obj.PrincipalId = $row.principal_id
        $obj.PrincipalType = $row.principal_type; $obj.RoleDefinitionId = $row.role_definition_id
        $obj.Scope = $row.scope; $obj.Condition = $row.condition; $obj.ConditionVersion = $row.condition_version
        $obj.Description = $row.description
        $obj.CreatedOn = if ($row.created_on) { [datetime]$row.created_on } else { $null }
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
