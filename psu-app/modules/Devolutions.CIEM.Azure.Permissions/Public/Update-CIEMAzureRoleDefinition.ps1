function Update-CIEMAzureRoleDefinition {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureRoleDefinition])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RoleName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RoleType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')][string]$AssignableScopes,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleDefinition[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id; $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $params.role_name = $item.RoleName; $setClauses += "role_name = @role_name"
                $params.role_type = $item.RoleType; $setClauses += "role_type = @role_type"
                $params.description = $item.Description; $setClauses += "description = @description"
                $params.assignable_scopes = $item.AssignableScopes; $setClauses += "assignable_scopes = @assignable_scopes"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_role_definitions WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure role definition '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ RoleName='role_name'; RoleType='role_type'; Description='description'; AssignableScopes='assignable_scopes' }
                foreach ($pn in $colMap.Keys) { if ($PSBoundParameters.ContainsKey($pn)) { $col = $colMap[$pn]; $setClauses += "$col = @$col"; $params[$col] = $PSBoundParameters[$pn] } }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureRoleDefinition -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_role_definitions SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureRoleDefinition -Id $cId }
        }
    }
}
