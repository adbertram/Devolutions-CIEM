function GetCIEMGraphEntity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity,

        [Parameter()]
        [hashtable]$Filters = @{}
    )

    $ErrorActionPreference = 'Stop'

    $config = GetCIEMGraphEntityConfig -Entity $Entity
    $query = "SELECT $($config.SelectColumns -join ', ') FROM $($config.Table)"
    $conditions = [System.Collections.Generic.List[string]]::new()
    $parameters = @{}

    foreach ($filterName in ($Filters.Keys | Sort-Object)) {
        if (-not $config.FilterColumns.ContainsKey($filterName)) {
            throw "GetCIEMGraphEntity: unknown filter '$filterName' for entity '$Entity'."
        }

        $column = $config.FilterColumns[$filterName]
        $conditions.Add("$column = @$column")
        $parameters[$column] = $Filters[$filterName]
    }

    if ($conditions.Count -gt 0) {
        $query += "`nWHERE " + ($conditions -join ' AND ')
    }

    $rows = @(Invoke-CIEMQuery -Query $query -Parameters $parameters)
    @(foreach ($row in $rows) {
        ConvertCIEMGraphEntityRow -Entity $Entity -Row $row
    })
}
