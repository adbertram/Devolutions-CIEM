function RemoveCIEMAzureEntity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity,

        [Parameter()]
        [hashtable]$Filters = @{},

        [Parameter()]
        [switch]$All,

        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    $config = GetCIEMAzureEntityConfig -Entity $Entity
    if ($All -and $Filters.Count -gt 0) {
        throw "RemoveCIEMAzureEntity: entity '$Entity' cannot combine -All with filters."
    }
    if (-not $All -and $Filters.Count -eq 0) {
        throw "RemoveCIEMAzureEntity: entity '$Entity' requires filters or -All."
    }

    $parameters = @{}
    $whereClauses = [System.Collections.Generic.List[string]]::new()

    foreach ($filterName in ($Filters.Keys | Sort-Object)) {
        if (-not $config.FilterColumns.ContainsKey($filterName)) {
            throw "RemoveCIEMAzureEntity: unknown filter '$filterName' for entity '$Entity'."
        }

        $column = $config.FilterColumns[$filterName]
        $whereClauses.Add("$column = @$column")
        $parameters[$column] = $Filters[$filterName]
    }

    $query = "DELETE FROM $($config.Table)"
    if ($whereClauses.Count -gt 0) {
        $query += " WHERE " + ($whereClauses -join ' AND ')
    }

    if ($Connection) {
        Invoke-PSUSQLiteQuery -Connection $Connection -Query $query -Parameters $parameters -AsNonQuery | Out-Null
    } else {
        Invoke-CIEMQuery -Query $query -Parameters $parameters -AsNonQuery | Out-Null
    }
}
