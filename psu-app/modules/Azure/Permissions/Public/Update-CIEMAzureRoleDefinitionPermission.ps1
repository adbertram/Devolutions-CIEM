function Update-CIEMAzureRoleDefinitionPermission {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureRoleDefinitionPermission')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][int]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ActionType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Action,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleDefinitionPermission[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) {
                $cId = $item.Id; $setClauses = @(); $params = @{ id = $cId }
                $params.action_type = $item.ActionType; $setClauses += "action_type = @action_type"
                $params.action = $item.Action; $setClauses += "action = @action"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_role_definition_permissions WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure role definition permission '$cId' not found." }
                $setClauses = @(); $params = @{ id = $cId }
                $colMap = @{ ActionType='action_type'; Action='action' }
                foreach ($pn in $colMap.Keys) { if ($PSBoundParameters.ContainsKey($pn)) { $col = $colMap[$pn]; $setClauses += "$col = @$col"; $params[$col] = $PSBoundParameters[$pn] } }
            }
            if ($setClauses.Count -eq 0) { if ($PassThru) { Get-CIEMAzureRoleDefinitionPermission -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_role_definition_permissions SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureRoleDefinitionPermission -Id $cId }
        }
    }
}
