function New-CIEMAzureDenyAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType('CIEMAzureDenyAssignment[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$DenyAssignmentName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Scope,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$DoNotApplyToChildren = $false,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Principals,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ExcludePrincipals,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsNotActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsDataActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsNotDataActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Condition,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$IsSystemProtected = $true,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureDenyAssignment[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $p = @{ id=$item.Id; provider_id=$item.ProviderId; deny_assignment_name=$item.DenyAssignmentName; description=$item.Description; scope=$item.Scope; do_not_apply_to_children=[int]$item.DoNotApplyToChildren; principals=$item.Principals; exclude_principals=$item.ExcludePrincipals; permissions_actions=$item.PermissionsActions; permissions_not_actions=$item.PermissionsNotActions; permissions_data_actions=$item.PermissionsDataActions; permissions_not_data_actions=$item.PermissionsNotDataActions; condition=$item.Condition; is_system_protected=[int]$item.IsSystemProtected; now=$now }
                $cId = $item.Id
            } else {
                $p = @{ id=$Id; provider_id=$ProviderId; deny_assignment_name=$DenyAssignmentName; description=$Description; scope=$Scope; do_not_apply_to_children=[int]$DoNotApplyToChildren; principals=$Principals; exclude_principals=$ExcludePrincipals; permissions_actions=$PermissionsActions; permissions_not_actions=$PermissionsNotActions; permissions_data_actions=$PermissionsDataActions; permissions_not_data_actions=$PermissionsNotDataActions; condition=$Condition; is_system_protected=[int]$IsSystemProtected; now=$now }
                $cId = $Id
            }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_deny_assignments WHERE id = @id" -Parameters @{ id = $cId }
            if ($existing) { throw "Azure deny assignment '$cId' already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_deny_assignments (id, provider_id, deny_assignment_name, description, scope, do_not_apply_to_children, principals, exclude_principals, permissions_actions, permissions_not_actions, permissions_data_actions, permissions_not_data_actions, condition, is_system_protected, collected_at) VALUES (@id, @provider_id, @deny_assignment_name, @description, @scope, @do_not_apply_to_children, @principals, @exclude_principals, @permissions_actions, @permissions_not_actions, @permissions_data_actions, @permissions_not_data_actions, @condition, @is_system_protected, @now)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureDenyAssignment -Id $cId
        }
    }
}
