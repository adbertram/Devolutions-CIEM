function New-CIEMAzureDirectoryRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType([CIEMAzureDirectoryRoleAssignment[]])]
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
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ id=$item.Id; provider_id=$item.ProviderId; principal_id=$item.PrincipalId; role_name=$item.RoleName; role_template_id=$item.RoleTemplateId; now=$now }; $cId=$item.Id }
            else { $p = @{ id=$Id; provider_id=$ProviderId; principal_id=$PrincipalId; role_name=$RoleName; role_template_id=$RoleTemplateId; now=$now }; $cId=$Id }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_directory_role_assignments WHERE id = @id" -Parameters @{ id = $cId }
            if ($existing) { throw "Azure directory role assignment '$cId' already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_directory_role_assignments (id, provider_id, principal_id, role_name, role_template_id, collected_at) VALUES (@id, @provider_id, @principal_id, @role_name, @role_template_id, @now)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureDirectoryRoleAssignment -Id $cId
        }
    }
}
