function Publish-PSUModule {
    <#
    .SYNOPSIS
        Publishes a PowerShell module to the PowerShell Gallery.

    .DESCRIPTION
        Automatically bumps the version and publishes a module to PowerShell Gallery.
        Modules with the 'PowerShellUniversal' tag appear in the PSU Gallery.

        Optionally imports the published module to a connected PSU instance.

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

    .PARAMETER LocalOnly
        Skip PowerShell Gallery publishing entirely and import the module
        directly to a local PSU instance.

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app -LocalOnly

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app -BumpVersion Minor
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
        [string]$EnvFilePath,

        [Parameter()]
        [switch]$LocalOnly
    )

    $ErrorActionPreference = 'Stop'

    $ModulePath = Resolve-Path $ModulePath -ErrorAction Stop | Select-Object -ExpandProperty Path

    $manifestFile = Get-ChildItem -Path $ModulePath -Filter '*.psd1' -File | Select-Object -First 1
    if (-not $manifestFile) {
        throw "No .psd1 manifest found in: $ModulePath"
    }
    $manifestPath = $manifestFile.FullName
    $moduleName = $manifestFile.BaseName

    # ========================================================================
    # LocalOnly Mode: Skip PSGallery entirely, import to local PSU
    # ========================================================================
    if ($LocalOnly) {
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host "Importing $moduleName to Local PSU" -ForegroundColor Cyan
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host "Module: $ModulePath"
        Write-Host ''

        Write-Host 'Step 1: Connecting to local PSU...' -ForegroundColor Yellow
        try {
            $null = Connect-PSU -Local -ErrorAction Stop
            Write-Host '  [OK] Connected to local PSU' -ForegroundColor Green
        }
        catch {
            throw "Failed to connect to local PSU: $_"
        }

        Write-Host ''
        Write-Host 'Step 2: Installing module to local PSU...' -ForegroundColor Yellow

        if ($PSCmdlet.ShouldProcess($moduleName, "Install to local PSU")) {
            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $moduleVersion = $manifest.ModuleVersion
            $projectRoot = Split-Path $ModulePath -Parent
            $localPsuModulesDir = Join-Path $projectRoot 'local-psu' 'Repository' 'Modules'
            $targetModuleDir = Join-Path $localPsuModulesDir $moduleName

            if (-not (Test-Path $localPsuModulesDir)) {
                throw "Local PSU modules directory not found: $localPsuModulesDir"
            }

            if (Test-Path $targetModuleDir) {
                Write-Verbose "Removing existing module at: $targetModuleDir"
                Remove-Item -Path $targetModuleDir -Recurse -Force
            }

            $targetVersionDir = Join-Path $targetModuleDir $moduleVersion
            Write-Verbose "Copying module to: $targetVersionDir"
            Copy-Item -Path $ModulePath -Destination $targetVersionDir -Recurse -Force

            Write-Host "  [OK] Module installed: $moduleName v$moduleVersion" -ForegroundColor Green

            $dashboardsFile = Get-ChildItem -Path $ModulePath -Filter 'dashboards.ps1' -Recurse | Where-Object { $_.Directory.Name -eq '.universal' } | Select-Object -First 1
            if ($dashboardsFile) {
                $dashboardContent = Get-Content $dashboardsFile.FullName -Raw
                if ($dashboardContent -match "New-PSUApp\s+-Name\s+'([^']+)'") {
                    $appName = $matches[1]
                    Write-Host ''
                    Write-Host 'Step 3: Restarting app...' -ForegroundColor Yellow
                    try {
                        Restart-PSUApp -Name $appName
                        Write-Host "  [OK] App '$appName' restarted" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  [WARN] Could not restart app '$appName': $_" -ForegroundColor Yellow
                    }
                }
            }

            Write-Host ''
            Write-Host '========================================' -ForegroundColor Cyan
            Write-Host 'Local Import Successful!' -ForegroundColor Green
            Write-Host '========================================' -ForegroundColor Cyan

            return [PSCustomObject]@{
                ModuleName = $moduleName
                Version    = $moduleVersion
                GalleryUrl = $null
                UpdatedPSU = $true
                Status     = 'LocalImport'
            }
        }
        else {
            Write-Host ''
            $manifest = Import-PowerShellDataFile -Path $manifestPath
            Write-Host '[DRY RUN] Would import to local PSU:' -ForegroundColor Yellow
            Write-Host "  Module: $moduleName"
            Write-Host "  Version: $($manifest.ModuleVersion)"
            Write-Host "  Path: $ModulePath"

            return [PSCustomObject]@{
                ModuleName = $moduleName
                Version    = $manifest.ModuleVersion
                GalleryUrl = $null
                UpdatedPSU = $false
                Status     = 'DryRun'
            }
        }
    }

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Publishing $moduleName to PowerShell Gallery" -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Module: $ModulePath"
    Write-Host ''

    # Step 1: Validate
    if (-not $SkipValidation) {
        Write-Host 'Step 1: Validating module structure...' -ForegroundColor Yellow

        $requiredFiles = @("$moduleName.psm1")

        foreach ($file in $requiredFiles) {
            $fullPath = Join-Path $ModulePath $file
            if (Test-Path $fullPath) {
                Write-Host "  [OK] $file" -ForegroundColor Green
            }
            else {
                throw "Missing required file: $file"
            }
        }

        $psuFiles = @('.universal/dashboards.ps1', 'config.json')
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

    # Step 2: Version bump
    Write-Host ''
    Write-Host 'Step 2: Querying PowerShell Gallery for current version...' -ForegroundColor Yellow

    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $localVersion = [version]$manifest.ModuleVersion
    Write-Host "  Local manifest version: $localVersion" -ForegroundColor Gray

    $galleryVersion = $null
    try {
        $existing = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction SilentlyContinue
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
        Write-Host '  Gallery version: Not published yet (first release)' -ForegroundColor Cyan
    }

    if ($galleryVersion) {
        $baseVersion = if ($galleryVersion -gt $localVersion) { $galleryVersion } else { $localVersion }
        Write-Host "  Base version for bump: $baseVersion" -ForegroundColor Gray
    }
    else {
        $baseVersion = $localVersion
        Write-Host "  Base version for bump: $baseVersion (local)" -ForegroundColor Gray
    }

    $newVersion = switch ($BumpVersion) {
        'Major' { [version]::new($baseVersion.Major + 1, 0, 0) }
        'Minor' { [version]::new($baseVersion.Major, $baseVersion.Minor + 1, 0) }
        'Patch' { [version]::new($baseVersion.Major, $baseVersion.Minor, $baseVersion.Build + 1) }
    }

    Write-Host "  New version: $newVersion ($BumpVersion bump)" -ForegroundColor Green

    $manifestContent = Get-Content -Path $manifestPath -Raw
    $updatedContent = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$newVersion'"

    if ($PSCmdlet.ShouldProcess($manifestPath, "Update ModuleVersion to $newVersion")) {
        Set-Content -Path $manifestPath -Value $updatedContent -NoNewline
        Write-Host "  [OK] Updated $manifestPath" -ForegroundColor Green
    }

    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $tags = $manifest.PrivateData.PSData.Tags
    if ($tags) {
        Write-Host "  [OK] Tags: $($tags -join ', ')" -ForegroundColor Green
    }

    # Step 3: API key
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
            Write-Host "  Loading from .env file..." -ForegroundColor Gray
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

    # Step 4: Publish
    Write-Host ''
    Write-Host 'Step 4: Preparing to publish...' -ForegroundColor Yellow

    $moduleVersion = $newVersion.ToString()
    if ($manifest.PrivateData.PSData.Prerelease) {
        $fullVersion = "$moduleVersion-$($manifest.PrivateData.PSData.Prerelease)"
    }
    else {
        $fullVersion = $moduleVersion
    }

    Write-Host "  [OK] Will publish version: $fullVersion" -ForegroundColor Green

    Write-Host ''
    Write-Host 'Step 5: Publishing to PowerShell Gallery...' -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess($moduleName, "Publish version $fullVersion to PowerShell Gallery")) {
        $publishParams = @{
            Path        = $ModulePath
            ApiKey      = $NuGetApiKey
            Repository  = 'PSGallery'
            ErrorAction = 'Stop'
        }

        Publish-PSResource @publishParams

        # Step 6: Verify
        Write-Host ''
        Write-Host 'Step 6: Verifying publication...' -ForegroundColor Yellow

        $maxRetries = 6
        $retryDelay = 10
        $verified = $false

        for ($i = 1; $i -le $maxRetries; $i++) {
            Write-Host "  Checking PowerShell Gallery (attempt $i/$maxRetries)..." -ForegroundColor Gray
            $published = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction SilentlyContinue
            if ($published -and $published.Version -eq $fullVersion) {
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
            Write-Host "  The module may still be propagating." -ForegroundColor Yellow
        }

        # Step 7: Update PSU
        $updatedPSU = $false
        Write-Host ''
        Write-Host 'Step 7: Updating PSU server...' -ForegroundColor Yellow

        if (-not $script:PSUConnection.Url) {
            Write-Host '  Not connected to PSU. Attempting auto-connect...' -ForegroundColor Gray
            try {
                $null = Connect-PSU -ErrorAction Stop
                Write-Host '  [OK] Connected to PSU' -ForegroundColor Green
            }
            catch {
                Write-Host "  [WARN] Could not auto-connect to PSU: $_" -ForegroundColor Yellow
                Write-Host '  Ensure AZURE_PSU_URL and AZURE_PSU_TOKEN are set in .env file' -ForegroundColor Gray
            }
        }

        if ($script:PSUConnection.Url) {
            try {
                Write-Host "  Importing $moduleName $fullVersion to PSU..." -ForegroundColor Gray
                Install-PSUModule -Name $moduleName -Version $fullVersion -NoSync
                Write-Host "  [OK] Module imported" -ForegroundColor Green
                $updatedPSU = $true

                $dashboardsPath = Join-Path -Path $ModulePath -ChildPath '.universal' -AdditionalChildPath 'dashboards.ps1'
                if (Test-Path $dashboardsPath) {
                    $dashboardContent = Get-Content $dashboardsPath -Raw
                    if ($dashboardContent -match "New-PSUApp\s+-Name\s+'([^']+)'") {
                        $appName = $matches[1]
                        Write-Host "  Restarting app '$appName'..." -ForegroundColor Gray
                        try {
                            Restart-PSUApp -Name $appName
                            Write-Host "  [OK] App restarted" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "  [WARN] Could not restart app: $_" -ForegroundColor Yellow
                        }
                    }
                }
            }
            catch {
                Write-Host "  [ERROR] Failed to update PSU: $_" -ForegroundColor Red
            }
        }

        Write-Host ''
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host 'Publication Successful!' -ForegroundColor Green
        Write-Host '========================================' -ForegroundColor Cyan

        [PSCustomObject]@{
            ModuleName  = $moduleName
            Version     = $fullVersion
            GalleryUrl  = "https://www.powershellgallery.com/packages/$moduleName"
            UpdatedPSU  = $updatedPSU
            Status      = 'Published'
        }
    }
    else {
        Write-Host ''
        Write-Host '[DRY RUN] Would publish:' -ForegroundColor Yellow
        Write-Host "  Module: $moduleName"
        Write-Host "  New version: $fullVersion"
        Write-Host "  Path: $ModulePath"

        [PSCustomObject]@{
            ModuleName  = $moduleName
            Version     = $fullVersion
            GalleryUrl  = "https://www.powershellgallery.com/packages/$moduleName"
            UpdatedPSU  = $false
            Status      = 'DryRun'
        }
    }
}
