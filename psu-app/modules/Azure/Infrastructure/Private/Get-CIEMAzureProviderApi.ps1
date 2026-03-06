function Get-CIEMAzureProviderApi {
    [CmdletBinding()]
    [OutputType('CIEMAzureProviderApi[]')]
    param(
        [Parameter()][int]$Id,
        [Parameter()][string]$Name
    )

    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}

    if ($PSBoundParameters.ContainsKey('Id')) { $conditions += "id = @id"; $params.id = $Id }
    if ($PSBoundParameters.ContainsKey('Name')) { $conditions += "name = @name"; $params.name = $Name }

    $query = "SELECT * FROM azure_provider_apis"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureProviderApi]::new()
        $obj.Id = $row.id
        $obj.Name = $row.name
        $obj.BaseUrl = $row.base_url
        $obj.Version = $row.version
        $obj
    })
}
