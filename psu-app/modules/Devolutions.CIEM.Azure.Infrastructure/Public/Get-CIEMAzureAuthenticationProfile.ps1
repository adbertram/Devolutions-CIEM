function Get-CIEMAzureAuthenticationProfile {
    [CmdletBinding()]
    [OutputType([CIEMAzureAuthenticationProfile[]])]
    param(
        [Parameter()][string]$Id,
        [Parameter()][string]$ProviderId,
        [Parameter()][string]$Name,
        [Parameter()][string]$Method,
        [Parameter()][bool]$IsActive
    )

    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}

    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderId')) { $conditions += "provider_id = @provider_id"; $params.provider_id = $ProviderId }
    if ($PSBoundParameters.ContainsKey('Name')) { $conditions += "name = @name"; $params.name = $Name }
    if ($PSBoundParameters.ContainsKey('Method')) { $conditions += "method = @method"; $params.method = $Method }
    if ($PSBoundParameters.ContainsKey('IsActive')) { $conditions += "is_active = @is_active"; $params.is_active = if ($IsActive) { 1 } else { 0 } }

    $query = "SELECT * FROM azure_authentication_profiles"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureAuthenticationProfile]::new()
        $obj.Id = $row.id
        $obj.ProviderId = $row.provider_id
        $obj.Name = $row.name
        $obj.Method = $row.method
        $obj.IsActive = [bool]$row.is_active
        $obj.TenantId = $row.tenant_id
        $obj.ClientId = $row.client_id
        $obj.ManagedIdentityClientId = $row.managed_identity_client_id
        $obj.SecretName = $row.secret_name
        $obj.SecretType = $row.secret_type
        $obj.CreatedAt = if ($row.created_at) { [datetime]$row.created_at } else { [datetime]::MinValue }
        $obj.UpdatedAt = if ($row.updated_at) { [datetime]$row.updated_at } else { [datetime]::MinValue }
        $obj
    })
}
