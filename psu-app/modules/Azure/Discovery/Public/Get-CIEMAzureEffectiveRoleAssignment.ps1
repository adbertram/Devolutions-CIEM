function Get-CIEMAzureEffectiveRoleAssignment {
    [CmdletBinding()]
    [OutputType('CIEMAzureEffectiveRoleAssignment[]')]
    param(
        [Parameter()]
        [int]$Id,

        [Parameter()]
        [string]$PrincipalId,

        [Parameter()]
        [string]$PrincipalType,

        [Parameter()]
        [string]$OriginalPrincipalId,

        [Parameter()]
        [string]$RoleDefinitionId,

        [Parameter()]
        [string]$Scope
    )

    $ErrorActionPreference = 'Stop'

    $query = "SELECT id, principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, permissions_json, computed_at FROM azure_effective_role_assignments"
    $conditions = @()
    $parameters = @{}

    $columnMap = @{
        Id                  = 'id'
        PrincipalId         = 'principal_id'
        PrincipalType       = 'principal_type'
        OriginalPrincipalId = 'original_principal_id'
        RoleDefinitionId    = 'role_definition_id'
        Scope               = 'scope'
    }

    foreach ($paramName in $columnMap.Keys) {
        if ($PSBoundParameters.ContainsKey($paramName)) {
            $col = $columnMap[$paramName]
            $conditions += "$col = @$col"
            $parameters[$col] = $PSBoundParameters[$paramName]
        }
    }

    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)

    @(foreach ($row in $rows) {
        $obj = [CIEMAzureEffectiveRoleAssignment]::new()
        $obj.Id = $row.id
        $obj.PrincipalId = $row.principal_id
        $obj.PrincipalType = $row.principal_type
        $obj.PrincipalDisplayName = $row.principal_display_name
        $obj.OriginalPrincipalId = $row.original_principal_id
        $obj.OriginalPrincipalType = $row.original_principal_type
        $obj.RoleDefinitionId = $row.role_definition_id
        $obj.RoleName = $row.role_name
        $obj.Scope = $row.scope
        $obj.PermissionsJson = $row.permissions_json
        $obj.ComputedAt = $row.computed_at
        $obj
    })
}
