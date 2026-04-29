function GetCIEMGraphEntityPropertyToColumnMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$EntityConfig
    )

    $ErrorActionPreference = 'Stop'

    $map = @{}
    foreach ($column in $EntityConfig.PropertyMap.Keys) {
        $map[$EntityConfig.PropertyMap[$column]] = $column
    }

    $map
}

function GetCIEMGraphEntityItemValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Item,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$ColumnName
    )

    $ErrorActionPreference = 'Stop'

    if ($Item -is [System.Collections.IDictionary]) {
        if ($Item.Contains($PropertyName)) {
            return $Item[$PropertyName]
        }
        if ($Item.Contains($ColumnName)) {
            return $Item[$ColumnName]
        }
        return $null
    }

    $property = $Item.PSObject.Properties[$PropertyName]
    if ($property) {
        return $property.Value
    }

    $property = $Item.PSObject.Properties[$ColumnName]
    if ($property) {
        return $property.Value
    }

    $null
}

function AssertCIEMGraphEntitySaveItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Entity,

        [Parameter(Mandatory)]
        [hashtable]$EntityConfig,

        [Parameter(Mandatory)]
        [object]$Item
    )

    $ErrorActionPreference = 'Stop'

    if ($null -eq $Item) {
        throw "SaveCIEMGraphEntity: entity '$Entity' cannot save a null item."
    }

    $propertyToColumn = GetCIEMGraphEntityPropertyToColumnMap -EntityConfig $EntityConfig

    if ($Item -is [System.Collections.IDictionary]) {
        $allowedKeys = @(@($EntityConfig.WritableColumns) + @($EntityConfig.InsertColumns) | Sort-Object -Unique)
        foreach ($key in @($Item.Keys)) {
            if ([string]$key -notin $allowedKeys) {
                throw "SaveCIEMGraphEntity: unknown writable value '$key' for entity '$Entity'."
            }
        }
    }

    foreach ($requiredValue in @($EntityConfig.RequiredSaveValues)) {
        if (-not $propertyToColumn.ContainsKey($requiredValue)) {
            throw "SaveCIEMGraphEntity: required value '$requiredValue' for entity '$Entity' has no column mapping."
        }

        $column = $propertyToColumn[$requiredValue]
        $value = GetCIEMGraphEntityItemValue -Item $Item -PropertyName $requiredValue -ColumnName $column
        if ($null -eq $value) {
            throw "SaveCIEMGraphEntity: entity '$Entity' requires value '$requiredValue'."
        }

        if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
            throw "SaveCIEMGraphEntity: entity '$Entity' requires value '$requiredValue'."
        }
    }
}

function SaveCIEMGraphEntity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    if ($null -eq $Items -or $Items.Count -eq 0) {
        return
    }

    $config = GetCIEMGraphEntityConfig -Entity $Entity
    foreach ($item in $Items) {
        AssertCIEMGraphEntitySaveItem -Entity $Entity -EntityConfig $config -Item $item
    }

    InvokeCIEMBatchInsert -Table $config.Table -Columns $config.InsertColumns -Items $Items -Connection $Connection
}
