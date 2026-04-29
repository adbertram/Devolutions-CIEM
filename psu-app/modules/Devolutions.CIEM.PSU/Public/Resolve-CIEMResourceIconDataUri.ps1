function Resolve-CIEMResourceIconDataUri {
    param(
        [AllowNull()]
        [string]$NodeType,

        [AllowNull()]
        [string]$AzureResourceType,

        [AllowNull()]
        [string]$EntraType,

        [AllowNull()]
        [string]$GraphKind,

        [AllowNull()]
        [string]$PropertiesJson
    )

    $ErrorActionPreference = 'Stop'

    $getManifest = {
        $ErrorActionPreference = 'Stop'

        $manifestPath = Join-Path $script:PSURoot 'Data/icons/resource-icon-map.json'

        if (-not $script:CIEMResourceIconManifest) {
            if (-not (Test-Path -LiteralPath $manifestPath)) {
                throw "Resource icon manifest not found: $manifestPath"
            }

            $script:CIEMResourceIconManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
            $script:CIEMResourceIconBasePath = Split-Path -Parent $manifestPath
            $script:CIEMResourceIconDataUriCache = @{}
        }

        return $script:CIEMResourceIconManifest
    }

    $getMapValue = {
        param(
            [Parameter(Mandatory)]
            [object]$Map,

            [Parameter(Mandatory)]
            [string]$Key
        )

        $ErrorActionPreference = 'Stop'

        $property = $Map.PSObject.Properties[$Key]
        if ($property) {
            return [string]$property.Value
        }

        return $null
    }

    $getDataUri = {
        param(
            [Parameter(Mandatory)]
            [string]$RelativePath
        )

        $ErrorActionPreference = 'Stop'

        & $getManifest | Out-Null

        if ($script:CIEMResourceIconDataUriCache.ContainsKey($RelativePath)) {
            return $script:CIEMResourceIconDataUriCache[$RelativePath]
        }

        $iconPath = Join-Path $script:CIEMResourceIconBasePath $RelativePath
        if (-not (Test-Path -LiteralPath $iconPath)) {
            throw "Resource icon file not found: $iconPath"
        }

        $bytes = [System.IO.File]::ReadAllBytes($iconPath)
        $dataUri = "data:image/svg+xml;base64,$([Convert]::ToBase64String($bytes))"
        $script:CIEMResourceIconDataUriCache[$RelativePath] = $dataUri

        return $dataUri
    }

    $manifest = & $getManifest
    $relativePath = $null

    if (-not [string]::IsNullOrWhiteSpace($PropertiesJson)) {
        $properties = $PropertiesJson | ConvertFrom-Json -ErrorAction Stop
        $armTypeProperty = $properties.PSObject.Properties['arm_type']
        if ($armTypeProperty -and -not [string]::IsNullOrWhiteSpace([string]$armTypeProperty.Value)) {
            $AzureResourceType = [string]$armTypeProperty.Value
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($AzureResourceType)) {
        $relativePath = & $getMapValue -Map $manifest.azureResourceTypeIcons -Key $AzureResourceType.ToLowerInvariant()
    }

    if (-not $relativePath -and -not [string]::IsNullOrWhiteSpace($EntraType)) {
        $relativePath = & $getMapValue -Map $manifest.entraTypeIcons -Key $EntraType
    }

    if (-not $relativePath -and -not [string]::IsNullOrWhiteSpace($GraphKind)) {
        $relativePath = & $getMapValue -Map $manifest.graphKindIcons -Key $GraphKind
    }

    if (-not $relativePath -and -not [string]::IsNullOrWhiteSpace($NodeType)) {
        $relativePath = & $getMapValue -Map $manifest.nodeTypeIcons -Key $NodeType
    }

    if (-not $relativePath) {
        $relativePath = & $getMapValue -Map $manifest.graphKindIcons -Key 'AzureResource'
    }

    return & $getDataUri -RelativePath $relativePath
}
