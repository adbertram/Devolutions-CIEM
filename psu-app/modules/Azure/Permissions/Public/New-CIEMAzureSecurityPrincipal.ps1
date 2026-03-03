function New-CIEMAzureSecurityPrincipal {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType('CIEMAzureSecurityPrincipal[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Type,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$DisplayName,
        [Parameter(ParameterSetName = 'ByProperties')][nullable[bool]]$Enabled,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Category,
        [Parameter(ParameterSetName = 'ByProperties')][string]$PrincipalType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$UserPrincipalName,
        [Parameter(ParameterSetName = 'ByProperties')][string]$UserType,
        [Parameter(ParameterSetName = 'ByProperties')][string]$AppId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ServicePrincipalType,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureSecurityPrincipal[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ id=$item.Id; provider_id=$item.ProviderId; type=$item.Type; display_name=$item.DisplayName; enabled=if($null -eq $item.Enabled){$null}elseif($item.Enabled){1}else{0}; category=$item.Category; principal_type=$item.PrincipalType; upn=$item.UserPrincipalName; user_type=$item.UserType; app_id=$item.AppId; sp_type=$item.ServicePrincipalType; now=$now }; $cId=$item.Id }
            else { $p = @{ id=$Id; provider_id=$ProviderId; type=$Type; display_name=$DisplayName; enabled=if($null -eq $Enabled){$null}elseif($Enabled){1}else{0}; category=$Category; principal_type=$PrincipalType; upn=$UserPrincipalName; user_type=$UserType; app_id=$AppId; sp_type=$ServicePrincipalType; now=$now }; $cId=$Id }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_security_principals WHERE id = @id" -Parameters @{ id = $cId }
            if ($existing) { throw "Azure security principal '$cId' already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_security_principals (id, provider_id, type, display_name, enabled, category, principal_type, user_principal_name, user_type, app_id, service_principal_type, collected_at) VALUES (@id, @provider_id, @type, @display_name, @enabled, @category, @principal_type, @upn, @user_type, @app_id, @sp_type, @now)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureSecurityPrincipal -Id $cId
        }
    }
}
