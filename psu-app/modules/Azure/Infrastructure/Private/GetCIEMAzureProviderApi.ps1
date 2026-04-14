function GetCIEMAzureProviderApi {
    [CmdletBinding()]
    [OutputType('CIEMAzureProviderApi[]')]
    param(
        [Parameter()][int]$Id,
        [Parameter()][string]$Name,
        [Parameter()][string]$Service,
        [Parameter()][switch]$HasPermissions
    )

    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}

    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('Name')) { $conditions += "name = @name"; $params.name = $Name }
    if ($PSBoundParameters.ContainsKey('Service')) { $conditions += "service = @service"; $params.service = $Service }
    if ($HasPermissions) { $conditions += "permissions IS NOT NULL" }

    $query = "SELECT * FROM azure_provider_apis"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureProviderApi]::new()
        $obj.Id = $row.id
        $obj.Name = $row.name
        $obj.BaseUrl = $row.base_url
        $obj.Version = $row.version
        $obj.Service = $row.service
        $obj.Path = $row.path
        $obj.Disabled = [bool]$row.disabled
        if ($row.permissions) {
            $obj.Permissions = $row.permissions | ConvertFrom-Json -AsHashtable
        }
        $obj
    })
}
