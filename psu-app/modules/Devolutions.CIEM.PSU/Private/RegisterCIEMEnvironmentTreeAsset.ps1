function RegisterCIEMEnvironmentTreeAsset {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    if ($script:CIEMEnvironmentTreeAssetId) {
        return $script:CIEMEnvironmentTreeAssetId
    }

    $assetServiceType = [type]::GetType('UniversalDashboard.Services.AssetService, UniversalDashboard', $false)
    if (-not $assetServiceType) {
        throw 'UniversalDashboard AssetService is required to register the CIEM Environment Tree component.'
    }

    $distPath = Join-Path $script:PSURoot 'Components/EnvironmentTree/dist'
    if (-not (Test-Path -LiteralPath $distPath)) {
        throw "CIEM Environment Tree component dist folder not found: $distPath"
    }

    $bundle = Get-ChildItem -LiteralPath $distPath -Filter 'index*.bundle.js' |
        Sort-Object Name |
        Select-Object -First 1
    if (-not $bundle) {
        throw "CIEM Environment Tree component bundle not found in: $distPath"
    }

    $assetRoot = Join-Path $script:DataRoot 'assets'
    if (-not (Test-Path -LiteralPath $assetRoot)) {
        New-Item -Path $assetRoot -ItemType Directory -Force | Out-Null
    }

    $hash = (Get-FileHash -LiteralPath $bundle.FullName -Algorithm SHA256).Hash.Substring(0, 12).ToLowerInvariant()
    $assetFileName = "ciem-environment-tree-$hash.bundle.js"
    $assetPath = Join-Path $assetRoot $assetFileName
    if (-not (Test-Path -LiteralPath $assetPath)) {
        Copy-Item -LiteralPath $bundle.FullName -Destination $assetPath -Force
    }

    $script:CIEMEnvironmentTreeAssetId = [UniversalDashboard.Services.AssetService]::Instance.RegisterAsset($assetPath)
    return $script:CIEMEnvironmentTreeAssetId
}
