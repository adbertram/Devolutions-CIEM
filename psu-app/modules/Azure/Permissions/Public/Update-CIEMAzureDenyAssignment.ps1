function Update-CIEMAzureDenyAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureDenyAssignment')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$DenyAssignmentName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Scope,
        [Parameter(ParameterSetName = 'ByProperties')][Nullable[bool]]$DoNotApplyToChildren,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Principals,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ExcludePrincipals,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsNotActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsDataActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PermissionsNotDataActions,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Condition,
        [Parameter(ParameterSetName = 'ByProperties')][Nullable[bool]]$IsSystemProtected,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureDenyAssignment[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id; $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $params.deny_assignment_name = $item.DenyAssignmentName; $setClauses += "deny_assignment_name = @deny_assignment_name"
                $params.description = $item.Description; $setClauses += "description = @description"
                $params.scope = $item.Scope; $setClauses += "scope = @scope"
                $params.do_not_apply_to_children = [int]$item.DoNotApplyToChildren; $setClauses += "do_not_apply_to_children = @do_not_apply_to_children"
                $params.principals = $item.Principals; $setClauses += "principals = @principals"
                $params.exclude_principals = $item.ExcludePrincipals; $setClauses += "exclude_principals = @exclude_principals"
                $params.permissions_actions = $item.PermissionsActions; $setClauses += "permissions_actions = @permissions_actions"
                $params.permissions_not_actions = $item.PermissionsNotActions; $setClauses += "permissions_not_actions = @permissions_not_actions"
                $params.permissions_data_actions = $item.PermissionsDataActions; $setClauses += "permissions_data_actions = @permissions_data_actions"
                $params.permissions_not_data_actions = $item.PermissionsNotDataActions; $setClauses += "permissions_not_data_actions = @permissions_not_data_actions"
                $params.condition = $item.Condition; $setClauses += "condition = @condition"
                $params.is_system_protected = [int]$item.IsSystemProtected; $setClauses += "is_system_protected = @is_system_protected"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_deny_assignments WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure deny assignment '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ DenyAssignmentName='deny_assignment_name'; Description='description'; Scope='scope'; Principals='principals'; ExcludePrincipals='exclude_principals'; PermissionsActions='permissions_actions'; PermissionsNotActions='permissions_not_actions'; PermissionsDataActions='permissions_data_actions'; PermissionsNotDataActions='permissions_not_data_actions'; Condition='condition' }
                foreach ($pn in $colMap.Keys) { if ($PSBoundParameters.ContainsKey($pn)) { $col = $colMap[$pn]; $setClauses += "$col = @$col"; $params[$col] = $PSBoundParameters[$pn] } }
                if ($PSBoundParameters.ContainsKey('DoNotApplyToChildren')) { $setClauses += "do_not_apply_to_children = @do_not_apply_to_children"; $params.do_not_apply_to_children = [int]$DoNotApplyToChildren }
                if ($PSBoundParameters.ContainsKey('IsSystemProtected')) { $setClauses += "is_system_protected = @is_system_protected"; $params.is_system_protected = [int]$IsSystemProtected }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureDenyAssignment -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_deny_assignments SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureDenyAssignment -Id $cId }
        }
    }
}
