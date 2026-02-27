function Save-CIEMAzureRoleDefinitionPermission {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RoleDefinitionId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ActionType,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Action,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleDefinitionPermission[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) { $p = @{ role_definition_id=$item.RoleDefinitionId; action_type=$item.ActionType; action=$item.Action } }
            else { $p = @{ role_definition_id=$RoleDefinitionId; action_type=$ActionType; action=$Action } }
            Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_role_definition_permissions (role_definition_id, action_type, action) VALUES (@role_definition_id, @action_type, @action)" -Parameters $p -AsNonQuery | Out-Null
        }
    }
}
