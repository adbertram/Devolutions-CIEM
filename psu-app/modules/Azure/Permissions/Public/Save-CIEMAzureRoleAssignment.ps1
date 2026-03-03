function Save-CIEMAzureRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$PrincipalId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$PrincipalType,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$RoleDefinitionId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Scope,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Condition,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ConditionVersion,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')][string]$CreatedOn,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureRoleAssignment[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ id=$item.Id; provider_id=$item.ProviderId; principal_id=$item.PrincipalId; principal_type=$item.PrincipalType; role_definition_id=$item.RoleDefinitionId; scope=$item.Scope; condition=$item.Condition; condition_version=$item.ConditionVersion; description=$item.Description; created_on=if($item.CreatedOn){$item.CreatedOn.ToString('o')}else{$null}; now=$now } }
            else { $p = @{ id=$Id; provider_id=$ProviderId; principal_id=$PrincipalId; principal_type=$PrincipalType; role_definition_id=$RoleDefinitionId; scope=$Scope; condition=$Condition; condition_version=$ConditionVersion; description=$Description; created_on=$CreatedOn; now=$now } }
            Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO azure_role_assignments (id, provider_id, principal_id, principal_type, role_definition_id, scope, condition, condition_version, description, created_on, collected_at) VALUES (@id, @provider_id, @principal_id, @principal_type, @role_definition_id, @scope, @condition, @condition_version, @description, @created_on, @now)" -Parameters $p -AsNonQuery | Out-Null
        }
    }
}
