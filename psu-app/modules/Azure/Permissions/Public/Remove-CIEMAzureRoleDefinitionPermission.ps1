function Remove-CIEMAzureRoleDefinitionPermission {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][int]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByRoleDefinitionId')][string]$RoleDefinitionId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleDefinitionPermission[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') { foreach ($item in $InputObject) { if ($PSCmdlet.ShouldProcess($item.Id, 'Remove Azure role definition permission')) { Invoke-CIEMQuery -Query "DELETE FROM azure_role_definition_permissions WHERE id = @id" -Parameters @{ id = $item.Id } -AsNonQuery | Out-Null } } }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByRoleDefinitionId') { if ($PSCmdlet.ShouldProcess("role definition '$RoleDefinitionId'", 'Remove all Azure role definition permissions')) { Invoke-CIEMQuery -Query "DELETE FROM azure_role_definition_permissions WHERE role_definition_id = @rdid" -Parameters @{ rdid = $RoleDefinitionId } -AsNonQuery | Out-Null } }
        else { if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure role definition permission')) { Invoke-CIEMQuery -Query "DELETE FROM azure_role_definition_permissions WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null } }
    }
}
