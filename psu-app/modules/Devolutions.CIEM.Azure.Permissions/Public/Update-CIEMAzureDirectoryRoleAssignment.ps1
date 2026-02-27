function Update-CIEMAzureDirectoryRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureDirectoryRoleAssignment])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PrincipalId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RoleName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RoleTemplateId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureDirectoryRoleAssignment[]]$InputObject,
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
                $params.role_name = $item.RoleName; $setClauses += "role_name = @role_name"
                $params.role_template_id = $item.RoleTemplateId; $setClauses += "role_template_id = @role_template_id"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_directory_role_assignments WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure directory role assignment '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ PrincipalId='principal_id'; RoleName='role_name'; RoleTemplateId='role_template_id' }
                foreach ($pn in $colMap.Keys) { if ($PSBoundParameters.ContainsKey($pn)) { $col = $colMap[$pn]; $setClauses += "$col = @$col"; $params[$col] = $PSBoundParameters[$pn] } }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureDirectoryRoleAssignment -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_directory_role_assignments SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureDirectoryRoleAssignment -Id $cId }
        }
    }
}
