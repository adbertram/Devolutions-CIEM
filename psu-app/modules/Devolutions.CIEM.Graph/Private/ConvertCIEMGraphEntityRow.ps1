function ConvertCIEMGraphEntityRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity,

        [Parameter(Mandatory)]
        [object]$Row
    )

    $ErrorActionPreference = 'Stop'

    $config = GetCIEMGraphEntityConfig -Entity $Entity
    $entityType = [string]$config.Class -as [type]
    if (-not $entityType) {
        throw "ConvertCIEMGraphEntityRow: class '$($config.Class)' for entity '$Entity' is not loaded."
    }

    $result = [Activator]::CreateInstance($entityType)
    foreach ($column in $config.PropertyMap.Keys) {
        $propertyName = $config.PropertyMap[$column]
        $result.$propertyName = $Row.$column
    }

    $result
}
