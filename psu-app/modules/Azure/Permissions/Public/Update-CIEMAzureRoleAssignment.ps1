function Update-CIEMAzureRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureRoleAssignment')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PrincipalId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PrincipalType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RoleDefinitionId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Scope,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Condition,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ConditionVersion,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')][string]$CreatedOn,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleAssignment[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id; $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $params.principal_id = $item.PrincipalId; $setClauses += "principal_id = @principal_id"
                $params.principal_type = $item.PrincipalType; $setClauses += "principal_type = @principal_type"
                $params.role_definition_id = $item.RoleDefinitionId; $setClauses += "role_definition_id = @role_definition_id"
                $params.scope = $item.Scope; $setClauses += "scope = @scope"
                $params.condition = $item.Condition; $setClauses += "condition = @condition"
                $params.condition_version = $item.ConditionVersion; $setClauses += "condition_version = @condition_version"
                $params.description = $item.Description; $setClauses += "description = @description"
                $params.created_on = if ($item.CreatedOn) { $item.CreatedOn.ToString('o') } else { $null }; $setClauses += "created_on = @created_on"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_role_assignments WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure role assignment '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ PrincipalId='principal_id'; PrincipalType='principal_type'; RoleDefinitionId='role_definition_id'; Scope='scope'; Condition='condition'; ConditionVersion='condition_version'; Description='description'; CreatedOn='created_on' }
                foreach ($pn in $colMap.Keys) { if ($PSBoundParameters.ContainsKey($pn)) { $col = $colMap[$pn]; $setClauses += "$col = @$col"; $params[$col] = $PSBoundParameters[$pn] } }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureRoleAssignment -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_role_assignments SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureRoleAssignment -Id $cId }
        }
    }
}
