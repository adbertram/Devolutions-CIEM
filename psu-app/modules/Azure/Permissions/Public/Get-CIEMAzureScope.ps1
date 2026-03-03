function Get-CIEMAzureScope {
    [CmdletBinding()]
    [OutputType('CIEMAzureScope[]')]
    param(
        [Parameter()][int]$Id,
        [Parameter()][int]$ProviderApiId,
        [Parameter()][string]$Scope,
        [Parameter()][string]$ResourceTypeId
    )

    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}

    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('ProviderApiId')) { $conditions += "provider_api_id = @provider_api_id"; $params.provider_api_id = $ProviderApiId }
    if ($PSBoundParameters.ContainsKey('Scope')) { $conditions += "scope = @scope"; $params.scope = $Scope }
    if ($PSBoundParameters.ContainsKey('ResourceTypeId')) { $conditions += "resource_type_id = @resource_type_id"; $params.resource_type_id = $ResourceTypeId }

    $query = "SELECT * FROM azure_scopes"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureScope]::new()
        $obj.Id = $row.id
        $obj.ProviderApiId = $row.provider_api_id
        $obj.Scope = $row.scope
        $obj.ResourceTypeId = $row.resource_type_id
        $obj
    })
}
