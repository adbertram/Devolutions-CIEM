function Publish-PSUModule {
    <#
    .SYNOPSIS
        Publishes a PowerShell module to the PowerShell Gallery.

    .DESCRIPTION
        Bumps the local manifest version and publishes that version to PowerShell
        Gallery. Modules with the 'PowerShellUniversal' tag appear in the PSU Gallery.

        This cmdlet does NOT install the module into any PSU instance. Use
        Deploy-PSUModule for that.

    .PARAMETER ModulePath
        Path to the module directory. Required.

    .PARAMETER NuGetApiKey
        PowerShell Gallery API key. If not provided, checks NUGET_API_KEY from
        environment variable or .env file.

    .PARAMETER BumpVersion
        Version component to increment: Patch (default), Minor, or Major.

    .PARAMETER SkipValidation
        Skip module structure validation (not recommended).

    .PARAMETER EnvFilePath
        Path to .env file for loading NuGetApiKey.

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app -BumpVersion Minor

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'CLI tooling requires colored user feedback for step progress and status messages')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$ModulePath,

        [Parameter()]
        [string]$NuGetApiKey,

        [Parameter()]
        [ValidateSet('Patch', 'Minor', 'Major')]
        [string]$BumpVersion = 'Patch',

        [Parameter()]
        [switch]$SkipValidation,

        [Parameter()]
        [string]$EnvFilePath
    )

    $ErrorActionPreference = 'Stop'

    $ModulePath = Resolve-Path $ModulePath -ErrorAction Stop | Select-Object -ExpandProperty Path

    $manifestFile = Get-ChildItem -Path $ModulePath -Filter '*.psd1' -File | Select-Object -First 1
    if (-not $manifestFile) {
        throw "No .psd1 manifest found in: $ModulePath"
    }
    $manifestPath = $manifestFile.FullName
    $moduleName = $manifestFile.BaseName
    $galleryUrl = "https://www.powershellgallery.com/packages/$moduleName"

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Publishing $moduleName to PowerShell Gallery" -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Module: $ModulePath"
    Write-Host ''

    if (-not $SkipValidation) {
        Write-Host 'Step 1: Validating module structure...' -ForegroundColor Yellow

        $requiredFiles = @(
            "$moduleName.psm1"
            'setup.ps1'
            '.universal/dashboards.ps1'
            '.universal/scripts.ps1'
            'modules/PSUSQLite/PSUSQLite.psd1'
        )

        foreach ($file in $requiredFiles) {
            $fullPath = Join-Path $ModulePath $file
            if (Test-Path $fullPath) {
                Write-Host "  [OK] $file" -ForegroundColor Green
            }
            else {
                throw "Missing required file: $file"
            }
        }

        $psuFiles = @('config.json')
        foreach ($file in $psuFiles) {
            $fullPath = Join-Path $ModulePath $file
            if (Test-Path $fullPath) {
                Write-Host "  [OK] $file (PSU)" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host 'Step 1: Skipping validation...' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host 'Step 2: Resolving package version...' -ForegroundColor Yellow

    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $localVersion = [version]$manifest.ModuleVersion
    Write-Host "  Local manifest version: $localVersion" -ForegroundColor Gray

    $newVersion = GetBumpedVersion -Base $localVersion -Component $BumpVersion
    if ($newVersion.Major -ne 0 -or $newVersion.Minor -ne 2) {
        throw "Publish-PSUModule requires a 0.2.x manifest version after increment. Current manifest version: $localVersion; incremented version: $newVersion"
    }

    Write-Host "  Incremented manifest version: $newVersion ($BumpVersion bump)" -ForegroundColor Green

    $galleryVersion = $null
    try {
        $existing = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction Stop
        if ($existing) {
            $versionString = $existing.Version -replace '-.*$', ''
            $galleryVersion = [version]$versionString
            Write-Host "  Gallery version: $galleryVersion" -ForegroundColor Cyan
        }
        else {
            Write-Host '  Gallery version: Not published yet (first release)' -ForegroundColor Cyan
        }
    }
    catch {
        throw "Failed to query PowerShell Gallery for module '$moduleName'. Error: $_"
    }

    if (Test-CIEMPSGalleryPackageVersion -Name $moduleName -Version $newVersion) {
        throw "PowerShell Gallery version $moduleName $newVersion already exists and cannot be republished. Update the manifest version before publishing."
    }

    $delistVersion = $null
    if ($galleryVersion) {
        if ($galleryVersion.Build -lt 0) {
            throw "Gallery version must include a patch component. Current Gallery version: $galleryVersion"
        }

        $expectedLocalVersion = [version]::new($galleryVersion.Major, $galleryVersion.Minor, $galleryVersion.Build + 1)
        if ($newVersion -eq $expectedLocalVersion) {
            Write-Host "  Incremented manifest is one patch above Gallery version $galleryVersion" -ForegroundColor Green
        }
        else {
            $delistVersion = $galleryVersion
            Write-Host "  Incremented manifest is not one patch above Gallery version $galleryVersion; $galleryVersion will be delisted before publish" -ForegroundColor Yellow
        }
    }

    Write-Host "  Version to publish: $newVersion" -ForegroundColor Green

    Write-Host ''
    Write-Host 'Step 3: Checking API key...' -ForegroundColor Yellow

    if (-not $NuGetApiKey) {
        $NuGetApiKey = $env:NUGET_API_KEY
    }

    if (-not $NuGetApiKey) {
        if (-not $EnvFilePath) {
            $projectRoot = Split-Path $ModulePath -Parent
            $EnvFilePath = Join-Path $projectRoot '.env'
        }

        if (Test-Path $EnvFilePath) {
            Write-Host '  Loading from .env file...' -ForegroundColor Gray
            $envContent = Get-Content $EnvFilePath -ErrorAction SilentlyContinue
            foreach ($line in $envContent) {
                if ($line -match '^NUGET_API_KEY=(.+)$') {
                    $NuGetApiKey = $Matches[1].Trim()
                    break
                }
            }
        }
    }

    if (-not $NuGetApiKey) {
        throw @"
NuGet API key required. Options:
  1. Pass as parameter: -NuGetApiKey 'your-key'
  2. Set environment variable: `$env:NUGET_API_KEY = 'your-key'
  3. Add NUGET_API_KEY=your-key to .env file
  4. Get a key from: https://www.powershellgallery.com/account/apikeys
"@
    }

    Write-Host '  [OK] API key provided' -ForegroundColor Green

    $manifestContent = Get-Content -Path $manifestPath -Raw
    $updatedContent = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$newVersion'"

    $moduleVersion = $newVersion.ToString()
    if ($manifest.PrivateData.PSData.Prerelease) {
        $fullVersion = "$moduleVersion-$($manifest.PrivateData.PSData.Prerelease)"
    }
    else {
        $fullVersion = $moduleVersion
    }

    if (-not $PSCmdlet.ShouldProcess($moduleName, "Publish version $fullVersion to PowerShell Gallery")) {
        Write-Host ''
        Write-Host '[DRY RUN] Would publish:' -ForegroundColor Yellow
        Write-Host "  Module: $moduleName"
        Write-Host "  Version: $fullVersion"
        Write-Host "  Path: $ModulePath"
        if ($delistVersion) {
            Write-Host "  Delist first: $delistVersion"
        }

        $delistedVersionText = $null
        if ($delistVersion) {
            $delistedVersionText = $delistVersion.ToString()
        }

        return [PSCustomObject]@{
            ModuleName       = $moduleName
            Version          = $fullVersion
            GalleryUrl       = $galleryUrl
            DelistedVersion  = $delistedVersionText
            Status           = 'DryRun'
        }
    }

    Set-Content -Path $manifestPath -Value $updatedContent -NoNewline
    Write-Host "  [OK] Updated $manifestPath" -ForegroundColor Green

    $tags = (Import-PowerShellDataFile -Path $manifestPath).PrivateData.PSData.Tags
    if ($tags) {
        Write-Host "  [OK] Tags: $($tags -join ', ')" -ForegroundColor Green
    }

    if ($delistVersion) {
        Write-Host "  Delisting $moduleName $delistVersion from PowerShell Gallery..." -ForegroundColor Yellow
        Unlist-CIEMPSGalleryPackageVersion -Name $moduleName -Version $delistVersion -ApiKey $NuGetApiKey
        Write-Host "  [OK] Delisted $moduleName $delistVersion" -ForegroundColor Green
    }

    Write-Host ''
    Write-Host "Step 4: Publishing version $fullVersion to PowerShell Gallery..." -ForegroundColor Yellow

    # Stage a clean copy excluding database files to avoid shipping runtime data
    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "PSUPublish_$moduleName"
    if (Test-Path $stagingDir) { Remove-Item $stagingDir -Recurse -Force }
    Copy-Item -Path $ModulePath -Destination $stagingDir -Recurse -Force
    Get-ChildItem -Path $stagingDir -Recurse -Include '*.db', '*.db-shm', '*.db-wal', '*.log' -File | Remove-Item -Force
    $stagingExcludeDirectories = @(
        Get-ChildItem -Path $stagingDir -Recurse -Directory -Force |
            Where-Object { $_.Name -in @('Tests', 'node_modules', 'playwright-report', 'test-results', 'source-packs') -or $_.FullName -like '*/ui/e2e' }
    )
    foreach ($directory in $stagingExcludeDirectories) {
        if (Test-Path -LiteralPath $directory.FullName) {
            Remove-Item -LiteralPath $directory.FullName -Recurse -Force
        }
    }
    Write-Host '  [OK] Staged clean copy (excluded *.db files, Tests/, ui/e2e/, node_modules/)' -ForegroundColor Green

    $publishParams = @{
        Path        = $stagingDir
        ApiKey      = $NuGetApiKey
        Repository  = 'PSGallery'
        ErrorAction = 'Stop'
    }

    try {
        Publish-PSResource @publishParams
    }
    finally {
        Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host 'Step 5: Verifying publication...' -ForegroundColor Yellow

    $maxRetries = 6
    $retryDelay = 10
    $verified = $false

    for ($i = 1; $i -le $maxRetries; $i++) {
        Write-Host "  Checking PowerShell Gallery (attempt $i/$maxRetries)..." -ForegroundColor Gray
        if (Test-CIEMPSGalleryPackageVersion -Name $moduleName -Version $newVersion) {
            $verified = $true
            break
        }
        if ($i -lt $maxRetries) {
            Write-Host "  Not found yet, waiting ${retryDelay}s..." -ForegroundColor Gray
            Start-Sleep -Seconds $retryDelay
        }
    }

    if ($verified) {
        Write-Host "  [OK] Verified: $moduleName $fullVersion is available" -ForegroundColor Green
    }
    else {
        Write-Host "  [WARN] Could not verify within $($maxRetries * $retryDelay)s" -ForegroundColor Yellow
        Write-Host '  The module may still be propagating.' -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Publication Successful! ($moduleName $fullVersion)" -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Cyan

    $publishedDelistedVersionText = $null
    if ($delistVersion) {
        $publishedDelistedVersionText = $delistVersion.ToString()
    }

    [PSCustomObject]@{
        ModuleName       = $moduleName
        Version          = $fullVersion
        GalleryUrl       = $galleryUrl
        DelistedVersion  = $publishedDelistedVersionText
        Status           = 'Published'
    }
}
