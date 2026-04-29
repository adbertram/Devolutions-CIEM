function GetCIEMAzureEntityConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity
    )

    $ErrorActionPreference = 'Stop'

    if (-not $script:CIEMAzureEntitiesConfig) {
        throw 'GetCIEMAzureEntityConfig: $script:CIEMAzureEntitiesConfig is not loaded. Module init failed.'
    }

    if (-not $script:CIEMAzureEntitiesConfig.ContainsKey($Entity)) {
        $known = ($script:CIEMAzureEntitiesConfig.Keys | Sort-Object) -join ', '
        throw "GetCIEMAzureEntityConfig: unknown entity '$Entity'. Known entities: $known"
    }

    $config = $script:CIEMAzureEntitiesConfig[$Entity]
    foreach ($requiredKey in 'Table', 'Class', 'KeyColumns', 'SelectColumns', 'InsertColumns', 'FilterColumns', 'WritableColumns', 'PropertyMap') {
        if (-not $config.ContainsKey($requiredKey)) {
            throw "GetCIEMAzureEntityConfig: entity '$Entity' is missing required key '$requiredKey'."
        }
    }

    $config
}
