function Update-CIEMAzureAppRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureAppRoleAssignment')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PrincipalId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PrincipalType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ResourceId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ResourceDisplayName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$AppRoleId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$AppRoleValue,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureAppRoleAssignment[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id; $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $params.principal_id = $item.PrincipalId; $setClauses += "principal_id = @principal_id"
                $params.principal_type = $item.PrincipalType; $setClauses += "principal_type = @principal_type"
                $params.resource_id = $item.ResourceId; $setClauses += "resource_id = @resource_id"
                $params.resource_display_name = $item.ResourceDisplayName; $setClauses += "resource_display_name = @resource_display_name"
                $params.app_role_id = $item.AppRoleId; $setClauses += "app_role_id = @app_role_id"
                $params.app_role_value = $item.AppRoleValue; $setClauses += "app_role_value = @app_role_value"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_app_role_assignments WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure app role assignment '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ PrincipalId='principal_id'; PrincipalType='principal_type'; ResourceId='resource_id'; ResourceDisplayName='resource_display_name'; AppRoleId='app_role_id'; AppRoleValue='app_role_value' }
                foreach ($pn in $colMap.Keys) { if ($PSBoundParameters.ContainsKey($pn)) { $col = $colMap[$pn]; $setClauses += "$col = @$col"; $params[$col] = $PSBoundParameters[$pn] } }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureAppRoleAssignment -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_app_role_assignments SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureAppRoleAssignment -Id $cId }
        }
    }
}
