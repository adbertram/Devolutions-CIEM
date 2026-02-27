function Update-CIEMAzureAuthenticationProfile {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([CIEMAzureAuthenticationProfile])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Name,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Method,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$IsActive,
        [Parameter(ParameterSetName = 'ByProperties')][string]$TenantId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ManagedIdentityClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureAuthenticationProfile[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $cId = $item.Id
                $setClauses = @("updated_at = @now"); $params = @{ id = $cId; now = $now }
                $params.name = $item.Name; $setClauses += "name = @name"
                $params.method = $item.Method; $setClauses += "method = @method"
                $params.is_active = if ($item.IsActive) { 1 } else { 0 }; $setClauses += "is_active = @is_active"
                $params.tenant_id = $item.TenantId; $setClauses += "tenant_id = @tenant_id"
                $params.client_id = $item.ClientId; $setClauses += "client_id = @client_id"
                $params.managed_identity_client_id = $item.ManagedIdentityClientId; $setClauses += "managed_identity_client_id = @managed_identity_client_id"
                $params.secret_name = $item.SecretName; $setClauses += "secret_name = @secret_name"
                $params.secret_type = $item.SecretType; $setClauses += "secret_type = @secret_type"
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_authentication_profiles WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Azure authentication profile '$cId' not found." }
                $setClauses = @("updated_at = @now"); $params = @{ id = $cId; now = $now }
                $columnMap = @{ Name='name'; Method='method'; IsActive='is_active'; TenantId='tenant_id'; ClientId='client_id'; ManagedIdentityClientId='managed_identity_client_id'; SecretName='secret_name'; SecretType='secret_type' }
                foreach ($paramName in $columnMap.Keys) {
                    if ($PSBoundParameters.ContainsKey($paramName)) {
                        $col = $columnMap[$paramName]
                        $val = $PSBoundParameters[$paramName]
                        if ($paramName -eq 'IsActive') { $val = if ($val) { 1 } else { 0 } }
                        $setClauses += "$col = @$col"; $params[$col] = $val
                    }
                }
            }
            Invoke-CIEMQuery -Query "UPDATE azure_authentication_profiles SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMAzureAuthenticationProfile -Id $cId }
        }
    }
}
