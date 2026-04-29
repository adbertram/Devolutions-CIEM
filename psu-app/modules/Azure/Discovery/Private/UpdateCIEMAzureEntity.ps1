function UpdateCIEMAzureEntity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity,

        [Parameter(Mandatory)]
        [hashtable]$Filters,

        [Parameter(Mandatory)]
        [hashtable]$Values,

        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    $config = GetCIEMAzureEntityConfig -Entity $Entity
    if ($Filters.Count -eq 0) {
        throw "UpdateCIEMAzureEntity: entity '$Entity' requires at least one filter."
    }
    if ($Values.Count -eq 0) {
        throw "UpdateCIEMAzureEntity: entity '$Entity' requires at least one value."
    }

    $propertyToColumn = @{}
    foreach ($column in $config.PropertyMap.Keys) {
        $propertyToColumn[$config.PropertyMap[$column]] = $column
    }

    $setClauses = [System.Collections.Generic.List[string]]::new()
    $whereClauses = [System.Collections.Generic.List[string]]::new()
    $parameters = @{}

    foreach ($valueName in ($Values.Keys | Sort-Object)) {
        if ($valueName -notin $config.WritableColumns) {
            throw "UpdateCIEMAzureEntity: unknown writable value '$valueName' for entity '$Entity'."
        }

        $column = $propertyToColumn[$valueName]
        if (-not $column) {
            throw "UpdateCIEMAzureEntity: value '$valueName' for entity '$Entity' has no column mapping."
        }

        $parameterName = "set_$column"
        $setClauses.Add("$column = @$parameterName")
        $parameters[$parameterName] = $Values[$valueName]
    }

    foreach ($filterName in ($Filters.Keys | Sort-Object)) {
        if (-not $config.FilterColumns.ContainsKey($filterName)) {
            throw "UpdateCIEMAzureEntity: unknown filter '$filterName' for entity '$Entity'."
        }

        $column = $config.FilterColumns[$filterName]
        $parameterName = "where_$column"
        $whereClauses.Add("$column = @$parameterName")
        $parameters[$parameterName] = $Filters[$filterName]
    }

    $query = "UPDATE $($config.Table) SET $($setClauses -join ', ') WHERE $($whereClauses -join ' AND ')"
    if ($Connection) {
        Invoke-PSUSQLiteQuery -Connection $Connection -Query $query -Parameters $parameters -AsNonQuery | Out-Null
    } else {
        Invoke-CIEMQuery -Query $query -Parameters $parameters -AsNonQuery | Out-Null
    }
}
