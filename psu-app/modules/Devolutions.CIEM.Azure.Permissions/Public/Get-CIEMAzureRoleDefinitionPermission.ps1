function Get-CIEMAzureRoleDefinitionPermission {
    [CmdletBinding()]
    [OutputType([CIEMAzureRoleDefinitionPermission[]])]
    param(
        [Parameter()][int]$Id,
        [Parameter()][string]$RoleDefinitionId,
        [Parameter()][string]$ActionType,
        [Parameter()][string]$Action
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('RoleDefinitionId')) { $conditions += "role_definition_id = @role_definition_id"; $params.role_definition_id = $RoleDefinitionId }
    if ($PSBoundParameters.ContainsKey('ActionType')) { $conditions += "action_type = @action_type"; $params.action_type = $ActionType }
    if ($PSBoundParameters.ContainsKey('Action')) { $conditions += "action = @action"; $params.action = $Action }
    $query = "SELECT * FROM azure_role_definition_permissions"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureRoleDefinitionPermission]::new()
        $obj.Id = [int]$row.id; $obj.RoleDefinitionId = $row.role_definition_id
        $obj.ActionType = $row.action_type; $obj.Action = $row.action
        $obj
    })
}
