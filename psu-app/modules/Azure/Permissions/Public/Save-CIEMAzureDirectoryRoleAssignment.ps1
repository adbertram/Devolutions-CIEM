function Save-CIEMAzureDirectoryRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$PrincipalId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RoleName,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RoleTemplateId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureDirectoryRoleAssignment[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ id=$item.Id; provider_id=$item.ProviderId; principal_id=$item.PrincipalId; role_name=$item.RoleName; role_template_id=$item.RoleTemplateId; now=$now } }
            else { $p = @{ id=$Id; provider_id=$ProviderId; principal_id=$PrincipalId; role_name=$RoleName; role_template_id=$RoleTemplateId; now=$now } }
            Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_directory_role_assignments (id, provider_id, principal_id, role_name, role_template_id, collected_at) VALUES (@id, @provider_id, @principal_id, @role_name, @role_template_id, @now)" -Parameters $p -AsNonQuery | Out-Null
        }
    }
}
