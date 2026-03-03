function Save-CIEMAzureAuthenticationProfile {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Name,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Method,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$IsActive = $true,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$TenantId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ManagedIdentityClientId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$SecretType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureAuthenticationProfile[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) {
                $p = @{ id=$item.Id; provider_id=$item.ProviderId; name=$item.Name; method=$item.Method; is_active=if($item.IsActive){1}else{0}; tenant_id=$item.TenantId; client_id=$item.ClientId; managed_identity_client_id=$item.ManagedIdentityClientId; secret_name=$item.SecretName; secret_type=$item.SecretType; now=$now }
            } else {
                $p = @{ id=$Id; provider_id=$ProviderId; name=$Name; method=$Method; is_active=if($IsActive){1}else{0}; tenant_id=$TenantId; client_id=$ClientId; managed_identity_client_id=$ManagedIdentityClientId; secret_name=$SecretName; secret_type=$SecretType; now=$now }
            }
            Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO azure_authentication_profiles (id, provider_id, name, method, is_active, tenant_id, client_id, managed_identity_client_id, secret_name, secret_type, created_at, updated_at)
VALUES (@id, @provider_id, @name, @method, @is_active, @tenant_id, @client_id, @managed_identity_client_id, @secret_name, @secret_type, @now, @now)
"@ -Parameters $p -AsNonQuery | Out-Null
        }
    }
}
