#Requires -Version 7.0

<#
.SYNOPSIS
    Publish Devolutions.CIEM module to PowerShell Gallery
.DESCRIPTION
    Automatically bumps the version and publishes the Devolutions.CIEM module to
    PowerShell Gallery. Once published, the module appears in PSU Gallery (any PSU
    server) due to the 'PowerShellUniversal' tag.

    Users install via: PSU Admin Console > Platform > Gallery > Search "Devolutions.CIEM"

    The module structure:
    - Devolutions.CIEM/
      - .universal/
        - dashboards.ps1    (PSU auto-discovery - uses -Module/-Command pattern)
      - Checks/, Public/, Private/
      - config.json
      - Devolutions.CIEM.psd1 (with PowerShellUniversal + app tags)
      - Devolutions.CIEM.psm1 (exports New-DevolutionsCIEMApp function)

.PARAMETER NuGetApiKey
    PowerShell Gallery API key. If not provided, checks $env:NUGET_API_KEY
.PARAMETER ModulePath
    Path to Devolutions.CIEM module (optional, auto-detected if not specified)
.PARAMETER BumpVersion
    Version component to increment: Patch (default), Minor, or Major.
    - Patch: 0.2.0 -> 0.2.1
    - Minor: 0.2.0 -> 0.3.0
    - Major: 0.2.0 -> 1.0.0
.PARAMETER WhatIf
    Show what would be published without actually publishing
.PARAMETER SkipValidation
    Skip module validation (not recommended)
.EXAMPLE
    ./Publish-ToGallery.ps1
    # Auto-bumps patch version and publishes (uses $env:NUGET_API_KEY)
.EXAMPLE
    ./Publish-ToGallery.ps1 -BumpVersion Minor
    # Bumps minor version (0.2.0 -> 0.3.0) and publishes
.EXAMPLE
    ./Publish-ToGallery.ps1 -WhatIf
    # Shows what version would be published without actually publishing
.NOTES
    Author: Adam Bertram
    Version: 7.0.0

    Prerequisites:
    - PowerShell Gallery API key (get from https://www.powershellgallery.com/account/apikeys)
    - PSResourceGet module (Microsoft.PowerShell.PSResourceGet)

    Why PSResourceGet?
    - PowerShellGet v2's Publish-Module uses Get-ChildItem WITHOUT -Force
    - This excludes hidden directories (starting with .) like .universal on Unix
    - PSResourceGet uses .NET Directory methods which include all files
    - See: https://github.com/PowerShell/PowerShellGetv2/blob/master/src/PowerShellGet/public/psgetfunctions/Publish-Module.ps1

    After publishing:
    - Module appears in PowerShell Gallery within minutes
    - Module appears in PSU Gallery within ~5 minutes (cached)
    - Users install via PSU Admin Console > Platform > Gallery
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$NuGetApiKey,

    [Parameter()]
    [string]$ModulePath,

    [Parameter()]
    [ValidateSet('Patch', 'Minor', 'Major')]
    [string]$BumpVersion = 'Patch',

    [Parameter()]
    [switch]$SkipValidation
)

$ErrorActionPreference = 'Stop'

# Auto-detect module path if not specified
if (-not $ModulePath) {
    $ScriptRoot = $PSScriptRoot
    $ProjectRoot = Split-Path $ScriptRoot -Parent
    $ModulePath = Join-Path $ProjectRoot 'Devolutions.CIEM'
}

Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Devolutions CIEM - PowerShell Gallery Publisher' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host "Module: $ModulePath"
Write-Host ''

# ============================================================================
# Step 1: Validate Module Structure
# ============================================================================
Write-Host 'Step 1: Validating module structure...' -ForegroundColor Yellow

if (-not (Test-Path $ModulePath)) {
    throw "Module not found: $ModulePath"
}

$ManifestPath = Join-Path $ModulePath 'Devolutions.CIEM.psd1'
if (-not (Test-Path $ManifestPath)) {
    throw "Module manifest not found: $ManifestPath"
}

# Check required files for PSU
$requiredFiles = @(
    @{ Path = '.universal/dashboards.ps1'; Desc = 'PSU app registration' }
    @{ Path = 'Devolutions.CIEM.psm1'; Desc = 'Module script (exports New-DevolutionsCIEMApp)' }
    @{ Path = 'config.json'; Desc = 'Configuration file' }
)

foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $ModulePath $file.Path
    if (Test-Path $fullPath) {
        Write-Host "  [OK] $($file.Path)" -ForegroundColor Green
    } else {
        throw "Missing required file: $($file.Path) ($($file.Desc))"
    }
}

# ============================================================================
# Step 2: Read Current Version and Bump
# ============================================================================
Write-Host ''
Write-Host 'Step 2: Reading and bumping version...' -ForegroundColor Yellow

$manifest = Import-PowerShellDataFile -Path $ManifestPath
$currentVersion = [version]$manifest.ModuleVersion
Write-Host "  Current version: $currentVersion" -ForegroundColor Gray

# Calculate new version
$newVersion = switch ($BumpVersion) {
    'Major' { [version]::new($currentVersion.Major + 1, 0, 0) }
    'Minor' { [version]::new($currentVersion.Major, $currentVersion.Minor + 1, 0) }
    'Patch' { [version]::new($currentVersion.Major, $currentVersion.Minor, $currentVersion.Build + 1) }
}

Write-Host "  New version: $newVersion ($BumpVersion bump)" -ForegroundColor Green

# Update the manifest file
$manifestContent = Get-Content -Path $ManifestPath -Raw
$updatedContent = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$newVersion'"

if ($PSCmdlet.ShouldProcess($ManifestPath, "Update ModuleVersion to $newVersion")) {
    Set-Content -Path $ManifestPath -Value $updatedContent -NoNewline
    Write-Host "  [OK] Updated $ManifestPath" -ForegroundColor Green
}

# Re-read manifest to get updated values
$manifest = Import-PowerShellDataFile -Path $ManifestPath
$tags = $manifest.PrivateData.PSData.Tags
Write-Host "  [OK] Tags: $($tags -join ', ')" -ForegroundColor Green

# ============================================================================
# Step 3: Get API Key
# ============================================================================
Write-Host ''
Write-Host 'Step 3: Checking API key...' -ForegroundColor Yellow

if (-not $NuGetApiKey) {
    $NuGetApiKey = $env:NUGET_API_KEY
}

# Try to load from .env file if not set
if (-not $NuGetApiKey) {
    $envFile = Join-Path $ProjectRoot '.env'
    if (Test-Path $envFile) {
        Write-Host '  Loading from .env file...' -ForegroundColor Gray
        $envContent = Get-Content $envFile -ErrorAction SilentlyContinue
        foreach ($line in $envContent) {
            if ($line -match '^NUGET_API_KEY=(.+)$') {
                $NuGetApiKey = $Matches[1].Trim()
                break
            }
        }
    }
}

if (-not $NuGetApiKey) {
    Write-Host ''
    Write-Host 'ERROR: NuGet API key required.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Yellow
    Write-Host '  1. Pass as parameter: -NuGetApiKey ''your-key''' -ForegroundColor Cyan
    Write-Host '  2. Set environment variable: $env:NUGET_API_KEY = ''your-key''' -ForegroundColor Cyan
    Write-Host '  3. Add NUGET_API_KEY=your-key to .env file' -ForegroundColor Cyan
    Write-Host '  4. Get a key from: https://www.powershellgallery.com/account/apikeys' -ForegroundColor Cyan
    Write-Host ''
    throw 'NuGet API key required for publishing'
}

Write-Host '  [OK] API key provided' -ForegroundColor Green

# ============================================================================
# Step 4: Check PowerShell Gallery
# ============================================================================
Write-Host ''
Write-Host 'Step 4: Checking PowerShell Gallery...' -ForegroundColor Yellow

$moduleName = 'Devolutions.CIEM'
$moduleVersion = $newVersion.ToString()
if ($manifest.PrivateData.PSData.Prerelease) {
    $fullVersion = "$moduleVersion-$($manifest.PrivateData.PSData.Prerelease)"
} else {
    $fullVersion = $moduleVersion
}

try {
    $existing = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  [INFO] Latest published version: $($existing.Version)" -ForegroundColor Cyan
    } else {
        Write-Host '  [INFO] Module not yet published (first release)' -ForegroundColor Cyan
    }
} catch {
    Write-Host '  [INFO] Module not yet published (first release)' -ForegroundColor Cyan
}

Write-Host "  [OK] Publishing version: $fullVersion" -ForegroundColor Green

# ============================================================================
# Step 5: Publish to PowerShell Gallery (using PSResourceGet)
# ============================================================================
Write-Host ''
Write-Host 'Step 5: Publishing to PowerShell Gallery...' -ForegroundColor Yellow
Write-Host '  Using Publish-PSResource (PSResourceGet) to include hidden directories' -ForegroundColor Gray

if ($PSCmdlet.ShouldProcess($moduleName, "Publish version $fullVersion to PowerShell Gallery")) {
    try {
        # Use Publish-PSResource instead of Publish-Module
        # PowerShellGet v2's Publish-Module uses Get-ChildItem WITHOUT -Force,
        # which excludes hidden directories like .universal on Unix systems.
        # PSResourceGet's Publish-PSResource uses .NET Directory.GetFiles/GetDirectories
        # which includes all files regardless of hidden status.
        $publishParams = @{
            Path        = $ModulePath
            ApiKey      = $NuGetApiKey
            Repository  = 'PSGallery'
            ErrorAction = 'Stop'
        }

        Publish-PSResource @publishParams

        # ============================================================================
        # Step 6: Verify Publication
        # ============================================================================
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
            Write-Host "  [OK] Verified: $moduleName $fullVersion is available in PowerShell Gallery" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] Could not verify publication within $($maxRetries * $retryDelay)s" -ForegroundColor Yellow
            Write-Host '  The module may still be propagating. Check manually:' -ForegroundColor Yellow
            Write-Host "  Find-Module -Name '$moduleName' -AllowPrerelease" -ForegroundColor Cyan
        }

        # ============================================================================
        # Step 7: Update PSU Server
        # ============================================================================
        Write-Host ''
        Write-Host 'Step 7: Updating PSU server...' -ForegroundColor Yellow

        # Load PSU credentials from .env
        $psuUrl = $env:PSU_URL
        $psuToken = $env:PSU_TOKEN

        if (-not $psuUrl -or -not $psuToken) {
            $envFile = Join-Path $ProjectRoot '.env'
            if (Test-Path $envFile) {
                $envContent = Get-Content $envFile -ErrorAction SilentlyContinue
                foreach ($line in $envContent) {
                    if ($line -match '^PSU_URL=(.+)$') {
                        $psuUrl = $Matches[1].Trim()
                    }
                    if ($line -match '^PSU_TOKEN=(.+)$') {
                        $psuToken = $Matches[1].Trim()
                    }
                }
            }
        }

        if (-not $psuUrl -or -not $psuToken) {
            Write-Host '  [SKIP] PSU_URL or PSU_TOKEN not found in environment or .env file' -ForegroundColor Yellow
            Write-Host '  Manual update required: PSU Admin Console > Platform > Gallery' -ForegroundColor Yellow
        } else {
            try {
                $headers = @{
                    'Authorization' = "Bearer $psuToken"
                    'Content-Type'  = 'application/json'
                }

                # Install/update module on PSU server
                Write-Host "  Installing $moduleName $fullVersion on PSU server..." -ForegroundColor Gray
                $moduleBody = @{ name = $moduleName; version = $fullVersion } | ConvertTo-Json
                $null = Invoke-RestMethod -Uri "$psuUrl/api/v1/module" -Method POST -Headers $headers -Body $moduleBody
                Write-Host "  [OK] Module installed" -ForegroundColor Green

                # Get the dashboard/app ID
                Write-Host '  Finding Devolutions CIEM app...' -ForegroundColor Gray
                $dashboards = Invoke-RestMethod -Uri "$psuUrl/api/v1/dashboard" -Method GET -Headers $headers
                $ciemApp = $dashboards | Where-Object { $_.name -eq 'Devolutions CIEM' }

                if ($ciemApp) {
                    $appId = $ciemApp.id
                    Write-Host "  [OK] Found app (ID: $appId)" -ForegroundColor Green

                    # Restart app (stop then start)
                    Write-Host '  Restarting app...' -ForegroundColor Gray
                    $null = Invoke-RestMethod -Uri "$psuUrl/api/v1/dashboard/$appId/status" -Method DELETE -Headers $headers
                    Start-Sleep -Seconds 2
                    $null = Invoke-RestMethod -Uri "$psuUrl/api/v1/dashboard/$appId/status" -Method PUT -Headers $headers
                    Write-Host "  [OK] App restarted" -ForegroundColor Green
                } else {
                    Write-Host '  [WARN] Devolutions CIEM app not found on PSU server' -ForegroundColor Yellow
                }
            } catch {
                Write-Host "  [ERROR] Failed to update PSU server: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host '  Manual update required: PSU Admin Console > Platform > Gallery' -ForegroundColor Yellow
            }
        }

        Write-Host ''
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host 'Publication Successful!' -ForegroundColor Green
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host ''
        Write-Host "Module: $moduleName" -ForegroundColor Yellow
        Write-Host "Version: $fullVersion" -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'PowerShell Gallery:' -ForegroundColor Cyan
        Write-Host "  https://www.powershellgallery.com/packages/$moduleName" -ForegroundColor White
        Write-Host ''
        Write-Host 'PSU Server:' -ForegroundColor Cyan
        if ($psuUrl) {
            Write-Host "  $psuUrl/ciem/ciem/findings" -ForegroundColor White
        } else {
            Write-Host '  (not configured)' -ForegroundColor Gray
        }
    } catch {
        throw "Failed to publish module: $($_.Exception.Message)"
    }
} else {
    Write-Host ''
    Write-Host '[DRY RUN] Would publish:' -ForegroundColor Yellow
    Write-Host "  Module: $moduleName"
    Write-Host "  Current version: $currentVersion"
    Write-Host "  New version: $fullVersion"
    Write-Host "  Path: $ModulePath"
    Write-Host "  Repository: PSGallery"
}
