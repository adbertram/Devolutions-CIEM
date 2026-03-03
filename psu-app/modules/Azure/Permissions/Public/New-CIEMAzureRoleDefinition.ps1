function New-CIEMAzureRoleDefinition {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType('CIEMAzureRoleDefinition[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RoleName,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RoleType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')][string]$AssignableScopes,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleDefinition[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ id=$item.Id; provider_id=$item.ProviderId; role_name=$item.RoleName; role_type=$item.RoleType; description=$item.Description; assignable_scopes=$item.AssignableScopes; now=$now }; $cId=$item.Id }
            else { $p = @{ id=$Id; provider_id=$ProviderId; role_name=$RoleName; role_type=$RoleType; description=$Description; assignable_scopes=$AssignableScopes; now=$now }; $cId=$Id }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_role_definitions WHERE id = @id" -Parameters @{ id = $cId }
            if ($existing) { throw "Azure role definition '$cId' already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_role_definitions (id, provider_id, role_name, role_type, description, assignable_scopes, collected_at) VALUES (@id, @provider_id, @role_name, @role_type, @description, @assignable_scopes, @now)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureRoleDefinition -Id $cId
        }
    }
}
