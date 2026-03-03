function Get-CIEMAzureDenyAssignment {
    [CmdletBinding()]
    [OutputType('CIEMAzureDenyAssignment[]')]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$Scope
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('Scope')) { $conditions += "scope = @scope"; $params.scope = $Scope }
    $query = "SELECT * FROM azure_deny_assignments"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureDenyAssignment]::new()
        $obj.Id = $row.id; $obj.ProviderId = $row.provider_id
        $obj.DenyAssignmentName = $row.deny_assignment_name; $obj.Description = $row.description
        $obj.Scope = $row.scope
        $obj.DoNotApplyToChildren = [bool][int]$row.do_not_apply_to_children
        $obj.Principals = $row.principals; $obj.ExcludePrincipals = $row.exclude_principals
        $obj.PermissionsActions = $row.permissions_actions; $obj.PermissionsNotActions = $row.permissions_not_actions
        $obj.PermissionsDataActions = $row.permissions_data_actions; $obj.PermissionsNotDataActions = $row.permissions_not_data_actions
        $obj.Condition = $row.condition
        $obj.IsSystemProtected = [bool][int]$row.is_system_protected
        $obj.CollectedAt = if ($row.collected_at) { [datetime]$row.collected_at } else { Get-Date }
        $obj
    })
}
