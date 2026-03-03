function New-CIEMAzureAppRoleAssignment {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates data record')]
    [OutputType('CIEMAzureAppRoleAssignment[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$PrincipalId,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$PrincipalType,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$ResourceId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$ResourceDisplayName,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$AppRoleId,
        [Parameter(ParameterSetName = 'ByProperties')][string]$AppRoleValue,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureAppRoleAssignment[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            $now = (Get-Date).ToString('o')
            if ($item) { $p = @{ id=$item.Id; provider_id=$item.ProviderId; principal_id=$item.PrincipalId; principal_type=$item.PrincipalType; resource_id=$item.ResourceId; resource_display_name=$item.ResourceDisplayName; app_role_id=$item.AppRoleId; app_role_value=$item.AppRoleValue; now=$now }; $cId=$item.Id }
            else { $p = @{ id=$Id; provider_id=$ProviderId; principal_id=$PrincipalId; principal_type=$PrincipalType; resource_id=$ResourceId; resource_display_name=$ResourceDisplayName; app_role_id=$AppRoleId; app_role_value=$AppRoleValue; now=$now }; $cId=$Id }
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM azure_app_role_assignments WHERE id = @id" -Parameters @{ id = $cId }
            if ($existing) { throw "Azure app role assignment '$cId' already exists." }
            Invoke-CIEMQuery -Query "INSERT INTO azure_app_role_assignments (id, provider_id, principal_id, principal_type, resource_id, resource_display_name, app_role_id, app_role_value, collected_at) VALUES (@id, @provider_id, @principal_id, @principal_type, @resource_id, @resource_display_name, @app_role_id, @app_role_value, @now)" -Parameters $p -AsNonQuery | Out-Null
            Get-CIEMAzureAppRoleAssignment -Id $cId
        }
    }
}
