$script:DefaultAppName = 'Devolutions CIEM'

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
        Skip PowerShell Gallery publishing entirely and push the module
        via SSH/rsync to the publish point PSU instance.

    .PARAMETER IncludeData
        Include database files (*.db, *.db-shm, *.db-wal) in the module push.
        By default (LocalOnly), DB files are excluded to preserve the PSU instance's
        runtime data. Azure/PSGallery publishes always exclude data files too.

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app -LocalOnly

    .EXAMPLE
        Publish-PSUModule -ModulePath ./psu-app -LocalOnly -IncludeData

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
        [switch]$LocalOnly,

        [Parameter()]
        [switch]$IncludeData
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
        Write-Host "Publishing $moduleName to Publish Point PSU" -ForegroundColor Cyan
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host "Module: $ModulePath"
        Write-Host ''

        # Read publish point config from .env
        $projectRoot = Split-Path $ModulePath -Parent
        $envPath = if ($EnvFilePath) { $EnvFilePath } else { Join-Path $projectRoot '.env' }
        $sshAlias = $null
        $remotePsuPath = $null
        if (Test-Path $envPath) {
            foreach ($line in (Get-Content $envPath -ErrorAction Stop)) {
                if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
                if ($line -match '^([^=]+)=(.*)$') {
                    switch ($matches[1].Trim()) {
                        'PUBLISH_POINT_SSH' { $sshAlias = $matches[2].Trim() }
                        'PUBLISH_POINT_PSU_PATH' { $remotePsuPath = $matches[2].Trim() }
                    }
                }
            }
        }
        if (-not $sshAlias) { throw "PUBLISH_POINT_SSH is required in .env (e.g., adam-server)." }
        if (-not $remotePsuPath) { throw "PUBLISH_POINT_PSU_PATH is required in .env (e.g., /Users/adam/psu)." }
        $remoteModulesDir = "$remotePsuPath/Repository/Modules"

        Write-Host 'Step 1: Connecting to local PSU...' -ForegroundColor Yellow
        $null = Connect-PSU -Local -ErrorAction Stop
        Write-Host '  [OK] Connected to local PSU' -ForegroundColor Green

        Write-Host ''
        Write-Host 'Step 2: Bumping version...' -ForegroundColor Yellow

        $manifest = Import-PowerShellDataFile -Path $manifestPath
        $localVersion = [version]$manifest.ModuleVersion

        # Check currently installed version on publish point via SSH
        $installedVersion = $null
        $remoteVersionOutput = & ssh $sshAlias "ls '$remoteModulesDir/$moduleName/' 2>/dev/null" 2>$null
        if ($LASTEXITCODE -eq 0 -and $remoteVersionOutput) {
            $versionStrings = @($remoteVersionOutput | Where-Object { $_ -match '^\d+\.\d+\.\d+' })
            if ($versionStrings) {
                $installedVersion = $versionStrings | ForEach-Object { [version]$_ } | Sort-Object -Descending | Select-Object -First 1
            }
        }

        # Check PowerShell Gallery version
        $galleryVersion = $null
        try {
            $existing = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction SilentlyContinue 3>$null
            if ($existing) {
                $galleryVersion = [version]($existing.Version -replace '-.*$', '')
            }
        } catch {}

        # Use the highest of manifest, installed, and gallery versions
        $baseVersion = $localVersion
        if ($installedVersion -and $installedVersion -gt $baseVersion) { $baseVersion = $installedVersion }
        if ($galleryVersion -and $galleryVersion -gt $baseVersion) { $baseVersion = $galleryVersion }

        Write-Host "  Manifest version:  $localVersion" -ForegroundColor Gray
        if ($installedVersion) {
            Write-Host "  Installed version: $installedVersion" -ForegroundColor Cyan
        }
        if ($galleryVersion) {
            Write-Host "  Gallery version:   $galleryVersion" -ForegroundColor Cyan
        }

        $newVersion = Get-BumpedVersion -Base $baseVersion -Component $BumpVersion

        Write-Host "  New version: $newVersion ($BumpVersion bump)" -ForegroundColor Green

        # Update manifest file
        $manifestContent = Get-Content -Path $manifestPath -Raw
        $updatedContent = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$newVersion'"
        Set-Content -Path $manifestPath -Value $updatedContent -NoNewline
        Write-Host "  [OK] Updated $manifestPath" -ForegroundColor Green

        $moduleVersion = $newVersion.ToString()

        Write-Host ''
        Write-Host 'Step 3: Pushing module to publish point via SSH...' -ForegroundColor Yellow

        if ($PSCmdlet.ShouldProcess($moduleName, "Push v$moduleVersion to $sshAlias")) {

            # Remove existing module on publish point
            & ssh $sshAlias "rm -rf '$remoteModulesDir/$moduleName'" 2>$null

            # Build rsync exclude list
            $rsyncArgs = @('-az', '--delete')
            if (-not $IncludeData) {
                $rsyncArgs += '--exclude=*.db'
                $rsyncArgs += '--exclude=*.db-shm'
                $rsyncArgs += '--exclude=*.db-wal'
            }
            $rsyncArgs += '--exclude=*.log'
            $rsyncArgs += '--exclude=modules/Devolutions.CIEM.PSU/Data/icons/source-packs/'
            $rsyncArgs += '--exclude=Tests/'
            $rsyncArgs += '--exclude=node_modules/'
            $rsyncArgs += '--exclude=playwright-report/'
            $rsyncArgs += '--exclude=test-results/'
            $rsyncArgs += '--exclude=ui/e2e/'
            $rsyncArgs += "$ModulePath/"
            $rsyncArgs += "${sshAlias}:${remoteModulesDir}/${moduleName}/${moduleVersion}/"

            Write-Verbose "rsync $($rsyncArgs -join ' ')"
            & rsync @rsyncArgs
            if ($LASTEXITCODE -ne 0) {
                throw "rsync to $sshAlias failed with exit code $LASTEXITCODE"
            }

            if (-not $IncludeData) {
                Write-Host "  [OK] Excluded *.db files (use -IncludeData to override)" -ForegroundColor Green
            }
            Write-Host "  [OK] Module pushed: $moduleName v$moduleVersion -> $sshAlias" -ForegroundColor Green

            Write-Host ''
            Write-Host 'Step 4: Restarting app...' -ForegroundColor Yellow
            $appName = $script:DefaultAppName
            $dashboardsFile = Get-ChildItem -Path $ModulePath -Filter 'dashboards.ps1' -Recurse | Where-Object { $_.Directory.Name -eq '.universal' } | Select-Object -First 1
            if ($dashboardsFile) {
                $dashboardContent = Get-Content $dashboardsFile.FullName -Raw
                if ($dashboardContent -match "New-PSUApp\s+-Name\s+'([^']+)'") {
                    $appName = $matches[1]
                }
            }
            Restart-PSUApp -Name $appName
            Write-Host "  [OK] App '$appName' restarted" -ForegroundColor Green

            Write-Host ''
            Write-Host 'Step 5: Verifying app is healthy...' -ForegroundColor Yellow
            $healthUrl = "$($script:PSUConnection.Url)/api/v1/alive"
            $healthy = $false
            for ($i = 1; $i -le 10; $i++) {
                Write-Host "  Checking health (attempt $i/10)..." -ForegroundColor Gray
                try {
                    $resp = Invoke-RestMethod -Uri $healthUrl -Headers @{ 'ngrok-skip-browser-warning' = 'true' } -Method Get -TimeoutSec 5 -ErrorAction Stop
                    if ($resp.loading -eq $false -and $resp.hasError -eq $false) {
                        $healthy = $true
                        break
                    }
                    Write-Host "  Still loading: $($resp.loadingInfo)" -ForegroundColor Gray
                }
                catch {
                    Write-Host "  Not responding yet..." -ForegroundColor Gray
                }
                Start-Sleep -Seconds 3
            }
            if (-not $healthy) {
                throw "App failed health check after restart. $healthUrl did not return healthy within 30 seconds."
            }
            Write-Host "  [OK] App is healthy" -ForegroundColor Green

            Write-Host ''
            Write-Host '========================================' -ForegroundColor Cyan
            Write-Host 'Publish Point Import Successful!' -ForegroundColor Green
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
            Write-Host '[DRY RUN] Would push to publish point:' -ForegroundColor Yellow
            Write-Host "  Module: $moduleName"
            Write-Host "  Version: $($manifest.ModuleVersion)"
            Write-Host "  Target: ${sshAlias}:${remoteModulesDir}/${moduleName}/$($manifest.ModuleVersion)/"

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
            Remove-Item -Path $directory.FullName -Recurse -Force
        }
        Write-Host "  [OK] Staged clean copy (excluded *.db files)" -ForegroundColor Green

        $publishParams = @{
            Path        = $stagingDir
            ApiKey      = $NuGetApiKey
            Repository  = 'PSGallery'
            ErrorAction = 'Stop'
        }

        try {
            Publish-PSResource @publishParams
        } finally {
            Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }

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
            $null = Connect-PSU -ErrorAction Stop
            Write-Host '  [OK] Connected to PSU' -ForegroundColor Green
        }

        Write-Host "  Importing $moduleName $fullVersion to PSU..." -ForegroundColor Gray
        Install-PSUModule -Name $moduleName -Version $fullVersion -NoSync
        Write-Host "  [OK] Module imported" -ForegroundColor Green
        $updatedPSU = $true

        $appName = $script:DefaultAppName
        $dashboardsPath = Join-Path -Path $ModulePath -ChildPath '.universal' -AdditionalChildPath 'dashboards.ps1'
        if (Test-Path $dashboardsPath) {
            $dashboardContent = Get-Content $dashboardsPath -Raw
            if ($dashboardContent -match "New-PSUApp\s+-Name\s+'([^']+)'") {
                $appName = $matches[1]
            }
        }
        Write-Host "  Restarting app '$appName'..." -ForegroundColor Gray
        Restart-PSUApp -Name $appName
        Write-Host "  [OK] App restarted" -ForegroundColor Green

        Write-Host ''
        Write-Host 'Step 8: Verifying app is healthy...' -ForegroundColor Yellow
        $healthUrl = "$($script:PSUConnection.Url)/api/v1/alive"
        $healthy = $false
        for ($i = 1; $i -le 10; $i++) {
            Write-Host "  Checking health (attempt $i/10)..." -ForegroundColor Gray
            try {
                $resp = Invoke-RestMethod -Uri $healthUrl -Headers @{ 'ngrok-skip-browser-warning' = 'true' } -Method Get -TimeoutSec 5 -ErrorAction Stop
                if ($resp.loading -eq $false -and $resp.hasError -eq $false) {
                    $healthy = $true
                    break
                }
                Write-Host "  Still loading: $($resp.loadingInfo)" -ForegroundColor Gray
            }
            catch {
                Write-Host "  Not responding yet..." -ForegroundColor Gray
            }
            Start-Sleep -Seconds 3
        }
        if (-not $healthy) {
            throw "App failed health check after restart. $healthUrl did not return healthy within 30 seconds."
        }
        Write-Host "  [OK] App is healthy" -ForegroundColor Green

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
