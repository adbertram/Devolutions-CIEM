function New-CIEMAzureRoleDefinitionPermission {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType([CIEMAzureRoleDefinitionPermission[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RoleDefinitionId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ActionType,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Action,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleDefinitionPermission[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) { $p = @{ role_definition_id=$item.RoleDefinitionId; action_type=$item.ActionType; action=$item.Action } }
            else { $p = @{ role_definition_id=$RoleDefinitionId; action_type=$ActionType; action=$Action } }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_role_definition_permissions WHERE role_definition_id = @role_definition_id AND action_type = @action_type AND action = @action" -Parameters $p
            if ($existing) { throw "Azure role definition permission '($($p.role_definition_id), $($p.action_type), $($p.action))' already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_role_definition_permissions (role_definition_id, action_type, action) VALUES (@role_definition_id, @action_type, @action)" -Parameters $p -AsNonQuery | Out-Null
            $inserted = Invoke-CIEMQuery -Query "SELECT id FROM azure_role_definition_permissions WHERE role_definition_id = @role_definition_id AND action_type = @action_type AND action = @action" -Parameters $p
            Get-CIEMAzureRoleDefinitionPermission -Id ([int]$inserted.id)
        }
    }
}
