function Update-CIEMAzureEffectiveRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureEffectiveRoleAssignment[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [int]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$PrincipalDisplayName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$RoleName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$PermissionsJson,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ComputedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [switch]$PassThru
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $setClauses = @(); $params = @{ id = $obj.Id }
                $setClauses += "principal_id = @principal_id"; $params.principal_id = $obj.PrincipalId
                $setClauses += "principal_type = @principal_type"; $params.principal_type = $obj.PrincipalType
                $setClauses += "principal_display_name = @principal_display_name"; $params.principal_display_name = $obj.PrincipalDisplayName
                $setClauses += "original_principal_id = @original_principal_id"; $params.original_principal_id = $obj.OriginalPrincipalId
                $setClauses += "original_principal_type = @original_principal_type"; $params.original_principal_type = $obj.OriginalPrincipalType
                $setClauses += "role_definition_id = @role_definition_id"; $params.role_definition_id = $obj.RoleDefinitionId
                $setClauses += "role_name = @role_name"; $params.role_name = $obj.RoleName
                $setClauses += "scope = @scope"; $params.scope = $obj.Scope
                $setClauses += "permissions_json = @permissions_json"; $params.permissions_json = $obj.PermissionsJson
                $setClauses += "computed_at = @computed_at"; $params.computed_at = $obj.ComputedAt
                Invoke-CIEMQuery -Query "UPDATE azure_effective_role_assignments SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
                if ($PassThru) { Get-CIEMAzureEffectiveRoleAssignment -Id $obj.Id }
            }
        } else {
            $setClauses = @(); $params = @{ id = $Id }
            $columnMap = @{
                PrincipalDisplayName = 'principal_display_name'
                RoleName             = 'role_name'
                PermissionsJson      = 'permissions_json'
                ComputedAt           = 'computed_at'
            }
            foreach ($paramName in $columnMap.Keys) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $col = $columnMap[$paramName]
                    $setClauses += "$col = @$col"
                    $params[$col] = $PSBoundParameters[$paramName]
                }
            }
            if ($setClauses.Count -gt 0) {
                Invoke-CIEMQuery -Query "UPDATE azure_effective_role_assignments SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            }
            if ($PassThru) { Get-CIEMAzureEffectiveRoleAssignment -Id $Id }
        }
    }
}
