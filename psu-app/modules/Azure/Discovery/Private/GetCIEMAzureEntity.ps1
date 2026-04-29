function GetCIEMAzureEntity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity,

        [Parameter()]
        [hashtable]$Filters = @{}
    )

    $ErrorActionPreference = 'Stop'

    $config = GetCIEMAzureEntityConfig -Entity $Entity
    $query = "SELECT $($config.SelectColumns -join ', ') FROM $($config.Table)"
    $conditions = [System.Collections.Generic.List[string]]::new()
    $parameters = @{}

    foreach ($filterName in ($Filters.Keys | Sort-Object)) {
        if (-not $config.FilterColumns.ContainsKey($filterName)) {
            throw "GetCIEMAzureEntity: unknown filter '$filterName' for entity '$Entity'."
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
        ConvertCIEMAzureEntityRow -Entity $Entity -Row $row
    })
}
