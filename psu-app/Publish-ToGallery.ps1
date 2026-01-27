#Requires -Version 7.0

<#
.SYNOPSIS
    Publish Devolutions.CIEM module to PowerShell Gallery
.DESCRIPTION
    Validates and publishes the Devolutions.CIEM module to PowerShell Gallery.
    Once published, the module appears in PSU Gallery (any PSU server) due to
    the 'PowerShellUniversal' tag.

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
.PARAMETER WhatIf
    Show what would be published without actually publishing
.PARAMETER SkipValidation
    Skip module validation (not recommended)
.EXAMPLE
    ./Deploy-PSUApp.ps1 -NuGetApiKey 'your-api-key'
.EXAMPLE
    # Using environment variable
    $env:NUGET_API_KEY = 'your-api-key'
    ./Deploy-PSUApp.ps1
.EXAMPLE
    # Dry run
    ./Deploy-PSUApp.ps1 -WhatIf
.NOTES
    Author: Adam Bertram
    Version: 6.0.0

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
# Step 2: Read Module Manifest (no validation)
# ============================================================================
Write-Host ''
Write-Host 'Step 2: Reading module manifest...' -ForegroundColor Yellow

$manifest = Import-PowerShellDataFile -Path $ManifestPath
Write-Host "  [OK] Module: Devolutions.CIEM" -ForegroundColor Green
Write-Host "  [OK] Version: $($manifest.ModuleVersion)" -ForegroundColor Green
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

if (-not $NuGetApiKey) {
    Write-Host ''
    Write-Host 'ERROR: NuGet API key required.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Options:' -ForegroundColor Yellow
    Write-Host '  1. Pass as parameter: -NuGetApiKey ''your-key''' -ForegroundColor Cyan
    Write-Host '  2. Set environment variable: $env:NUGET_API_KEY = ''your-key''' -ForegroundColor Cyan
    Write-Host '  3. Get a key from: https://www.powershellgallery.com/account/apikeys' -ForegroundColor Cyan
    Write-Host ''
    throw 'NuGet API key required for publishing'
}

Write-Host '  [OK] API key provided' -ForegroundColor Green

# ============================================================================
# Step 4: Check if Version Already Exists
# ============================================================================
Write-Host ''
Write-Host 'Step 4: Checking PowerShell Gallery...' -ForegroundColor Yellow

$moduleName = 'Devolutions.CIEM'
$moduleVersion = $manifest.ModuleVersion.ToString()
if ($manifest.PrivateData.PSData.Prerelease) {
    $fullVersion = "$moduleVersion-$($manifest.PrivateData.PSData.Prerelease)"
} else {
    $fullVersion = $moduleVersion
}

try {
    $existing = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "  [INFO] Latest published version: $($existing.Version)" -ForegroundColor Cyan
        if ($existing.Version -eq $fullVersion) {
            throw "Version $fullVersion already exists in PowerShell Gallery. Bump the version in the manifest."
        }
    } else {
        Write-Host '  [INFO] Module not yet published (first release)' -ForegroundColor Cyan
    }
} catch [Microsoft.PowerShell.PackageManagement.Cmdlets.FindPackage.ModuleNotFound] {
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
        Write-Host 'PSU Installation (any PSU server):' -ForegroundColor Cyan
        Write-Host '  1. PSU Admin Console > Platform > Gallery' -ForegroundColor White
        Write-Host "  2. Search '$moduleName'" -ForegroundColor White
        Write-Host '  3. Click Install' -ForegroundColor White
        Write-Host '  4. App appears at /ciem' -ForegroundColor White
        Write-Host ''
        Write-Host 'Note: PSU Gallery syncs every ~5 minutes' -ForegroundColor DarkGray
    } catch {
        throw "Failed to publish module: $($_.Exception.Message)"
    }
} else {
    Write-Host ''
    Write-Host '[DRY RUN] Would publish:' -ForegroundColor Yellow
    Write-Host "  Module: $moduleName"
    Write-Host "  Version: $fullVersion"
    Write-Host "  Path: $ModulePath"
    Write-Host "  Repository: PSGallery"
}
