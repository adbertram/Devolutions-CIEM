function TestCIEMGraphEntityRegistry {
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Registry = $script:CIEMGraphEntitiesConfig
    )

    $ErrorActionPreference = 'Stop'

    if ($null -eq $Registry -or $Registry.Count -eq 0) {
        throw 'Graph entity registry is empty.'
    }

    $allowedFields = @(
        'Table',
        'Class',
        'KeyColumns',
        'SelectColumns',
        'InsertColumns',
        'FilterColumns',
        'WritableColumns',
        'RequiredSaveValues',
        'PropertyMap'
    )

    foreach ($entity in @($Registry.Keys | Sort-Object)) {
        if ([string]::IsNullOrWhiteSpace([string]$entity)) {
            throw 'Graph entity registry contains an empty entity name.'
        }

        $config = $Registry[$entity]
        if ($null -eq $config) {
            throw "Graph entity '$entity' has no registry entry."
        }

        $fields = @($config.Keys | Sort-Object)
        $expectedFields = @($allowedFields | Sort-Object)
        $unexpectedFields = @($fields | Where-Object { $_ -notin $expectedFields })
        if ($unexpectedFields.Count -gt 0) {
            throw "Graph entity '$entity' has unknown field(s): $($unexpectedFields -join ', ')."
        }

        $missingFields = @($expectedFields | Where-Object { $_ -notin $fields })
        if ($missingFields.Count -gt 0) {
            throw "Graph entity '$entity' is missing required field(s): $($missingFields -join ', ')."
        }

        if ([string]::IsNullOrWhiteSpace([string]$config.Table)) {
            throw "Graph entity '$entity' has an empty Table."
        }

        if ([string]::IsNullOrWhiteSpace([string]$config.Class)) {
            throw "Graph entity '$entity' has an empty Class."
        }

        if (-not ([string]$config.Class -as [type])) {
            throw "Graph entity '$entity' references unloaded class '$($config.Class)'."
        }

        foreach ($fieldName in @('KeyColumns', 'SelectColumns', 'InsertColumns', 'WritableColumns', 'RequiredSaveValues')) {
            if (@($config[$fieldName]).Count -eq 0) {
                throw "Graph entity '$entity' has empty $fieldName."
            }
        }

        if ($config.FilterColumns.Count -eq 0) {
            throw "Graph entity '$entity' has no FilterColumns."
        }

        if ($config.PropertyMap.Count -eq 0) {
            throw "Graph entity '$entity' has no PropertyMap."
        }

        foreach ($column in @($config.SelectColumns)) {
            if (-not $config.PropertyMap.ContainsKey($column)) {
                throw "Graph entity '$entity' select column '$column' has no PropertyMap entry."
            }
        }

        foreach ($column in @($config.InsertColumns)) {
            if (-not $config.PropertyMap.ContainsKey($column)) {
                throw "Graph entity '$entity' insert column '$column' has no PropertyMap entry."
            }
        }

        foreach ($valueName in @($config.RequiredSaveValues)) {
            if ($valueName -notin @($config.WritableColumns)) {
                throw "Graph entity '$entity' required save value '$valueName' is not writable."
            }
        }
    }

    $true
}

function GetCIEMGraphEntityConfig {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Entity
    )

    $ErrorActionPreference = 'Stop'

    TestCIEMGraphEntityRegistry | Out-Null
    if ([string]::IsNullOrWhiteSpace($Entity)) {
        return $script:CIEMGraphEntitiesConfig
    }

    if (-not $script:CIEMGraphEntitiesConfig.ContainsKey($Entity)) {
        throw "Unknown graph entity '$Entity'."
    }

    $script:CIEMGraphEntitiesConfig[$Entity]
}
