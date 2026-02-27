function Get-CIEMAzureResourceProperty {
    [CmdletBinding()]
    [OutputType([CIEMAzureResourceProperty[]])]
    param(
        [Parameter()][string]$ResourceId,
        [Parameter()][string]$Key
    )
    $ErrorActionPreference = 'Stop'
    $conditions = @(); $params = @{}
    if ($PSBoundParameters.ContainsKey('ResourceId')) { $conditions += "resource_id = @resource_id"; $params.resource_id = $ResourceId }
    if ($PSBoundParameters.ContainsKey('Key')) { $conditions += "key = @key"; $params.key = $Key }
    $query = "SELECT * FROM azure_resource_properties"
    if ($conditions.Count -gt 0) { $query += " WHERE " + ($conditions -join ' AND ') }
    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $params)
    @(foreach ($row in $rows) {
        $obj = [CIEMAzureResourceProperty]::new()
        $obj.ResourceId = $row.resource_id; $obj.Key = $row.key; $obj.Value = $row.value
        $obj
    })
}
