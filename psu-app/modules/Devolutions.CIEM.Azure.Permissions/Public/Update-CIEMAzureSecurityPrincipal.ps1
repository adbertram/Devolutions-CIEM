function Update-CIEMAzureSecurityPrincipal {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureSecurityPrincipal])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Type,
        [Parameter(ParameterSetName = 'ByProperties')][string]$DisplayName,
        [Parameter(ParameterSetName = 'ByProperties')][nullable[bool]]$Enabled,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Category,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PrincipalType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$UserPrincipalName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$UserType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$AppId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ServicePrincipalType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureSecurityPrincipal[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id; $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $params.type = $item.Type; $setClauses += "type = @type"
                $params.display_name = $item.DisplayName; $setClauses += "display_name = @display_name"
                $params.enabled = if($null -eq $item.Enabled){$null}elseif($item.Enabled){1}else{0}; $setClauses += "enabled = @enabled"
                $params.category = $item.Category; $setClauses += "category = @category"
                $params.principal_type = $item.PrincipalType; $setClauses += "principal_type = @principal_type"
                $params.upn = $item.UserPrincipalName; $setClauses += "user_principal_name = @upn"
                $params.user_type = $item.UserType; $setClauses += "user_type = @user_type"
                $params.app_id = $item.AppId; $setClauses += "app_id = @app_id"
                $params.sp_type = $item.ServicePrincipalType; $setClauses += "service_principal_type = @sp_type"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_security_principals WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure security principal '$cId' not found." }
                $setClauses = @("collected_at = @now"); $params = @{ id = $cId; now = $now }
                $colMap = @{ Type='type'; DisplayName='display_name'; Enabled='enabled'; Category='category'; PrincipalType='principal_type'; UserPrincipalName='user_principal_name'; UserType='user_type'; AppId='app_id'; ServicePrincipalType='service_principal_type' }
                foreach ($pn in $colMap.Keys) {
                    if ($PSBoundParameters.ContainsKey($pn)) {
                        $col = $colMap[$pn]; $val = $PSBoundParameters[$pn]
                        if ($pn -eq 'Enabled') { $val = if($null -eq $val){$null}elseif($val){1}else{0} }
                        $setClauses += "$col = @$col"; $params[$col] = $val
                    }
                }
            }
            if ($setClauses.Count -le 1) { if ($PassThru) { Get-CIEMAzureSecurityPrincipal -Id $cId }; continue }
            Invoke-CIEMQuery -Query "UPDATE azure_security_principals SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureSecurityPrincipal -Id $cId }
        }
    }
}
