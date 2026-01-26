#Requires -Version 7.0
#Requires -Modules Microsoft.PowerShell.PSResourceGet, Universal

<#
.SYNOPSIS
    Deploy Devolutions CIEM App to Azure-hosted PowerShell Universal
.DESCRIPTION
    Creates a deployment package (NuPkg) containing the CIEM app and module,
    uploads it to PSU, and applies it.

    The deployment package structure:
    - Devolutions.CIEM.PSUApp/
      - .universal/
        - dashboards.ps1    (app registration)
      - apps/
        - DevolutionsCIEM/
          - app.ps1         (app content)
      - Modules/
        - Devolutions.CIEM/ (the CIEM PowerShell module)
      - Devolutions.CIEM.PSUApp.psd1
      - Devolutions.CIEM.PSUApp.psm1

.PARAMETER PSUServerUrl
    The URL of the PowerShell Universal server
.PARAMETER AppToken
    The PSU App Token for authentication
.PARAMETER Version
    Version of the deployment package (default: 1.0.0)
.PARAMETER DeploymentName
    Name for the deployment (default: DevolutionsCIEM)
.PARAMETER Pin
    Pin the deployment to make the configuration read-only (recommended for production)
.PARAMETER KeepPackage
    Keep the NuPkg file after deployment (for debugging)
.EXAMPLE
    ./Deploy-PSUApp.ps1
.EXAMPLE
    ./Deploy-PSUApp.ps1 -Pin -Version "1.0.1"
.NOTES
    Author: Adam Bertram
    Version: 2.0.0

    Required Modules:
    - Microsoft.PowerShell.PSResourceGet (for Compress-PSResource)
    - Universal (for deployment cmdlets)

    References:
    - PSU Deployments: docs/psu-docs/config/deployments.md
    - PSU Modules with Resources: docs/psu-docs/platform/modules.md
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PSUServerUrl = 'https://devolutions-ciem-psu.azurewebsites.net',

    [Parameter()]
    [string]$AppToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9uYW1lIjoiYWRtaW4iLCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9oYXNoIjoiZTc3MDEwNmEtOGQ0Mi00YTQwLThmNjktZDVlNTg0NTU3YmM5Iiwic3ViIjoiUG93ZXJTaGVsbFVuaXZlcnNhbCIsImh0dHA6Ly9zY2hlbWFzLm1pY3Jvc29mdC5jb20vd3MvMjAwOC8wNi9pZGVudGl0eS9jbGFpbXMvcm9sZSI6IkFkbWluaXN0cmF0b3IiLCJuYmYiOjE3Njk0NDEzNzIsImV4cCI6MTc3MjAzMzM3MiwiaXNzIjoiSXJvbm1hblNvZnR3YXJlIiwiYXVkIjoiUG93ZXJTaGVsbFVuaXZlcnNhbCJ9.R5C7qAUqjncUCgdBzCzZH9zZnYFFqS8JoGc1WO5GkL4',

    [Parameter()]
    [string]$Version = '1.0.0',

    [Parameter()]
    [string]$DeploymentName = 'DevolutionsCIEM',

    [Parameter()]
    [switch]$Pin,

    [Parameter()]
    [switch]$KeepPackage
)

$ErrorActionPreference = 'Stop'

# Paths
$ScriptRoot = $PSScriptRoot
$ProjectRoot = Split-Path $ScriptRoot -Parent
$ModuleSourcePath = Join-Path $ProjectRoot 'Devolutions.CIEM'
$AppSourcePath = Join-Path $ScriptRoot 'apps' 'DevolutionsCIEM'
$TempPath = Join-Path $ProjectRoot '_temp'
$PackageStagingPath = Join-Path $TempPath 'Devolutions.CIEM.PSUApp'

Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Devolutions CIEM - PSU Deployment' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host "Version: $Version"
Write-Host "Target: $PSUServerUrl"
Write-Host ''

# ============================================================================
# Step 1: Validate Source Files
# ============================================================================
Write-Host 'Step 1: Validating source files...' -ForegroundColor Yellow

if (-not (Test-Path $ModuleSourcePath)) {
    throw "Module source not found: $ModuleSourcePath"
}

$AppFilePath = Join-Path $AppSourcePath 'app.ps1'
if (-not (Test-Path $AppFilePath)) {
    throw "App file not found: $AppFilePath"
}

Write-Host '  [OK] Devolutions.CIEM module' -ForegroundColor Green
Write-Host '  [OK] apps/DevolutionsCIEM/app.ps1' -ForegroundColor Green

# ============================================================================
# Step 2: Create Package Staging Directory
# ============================================================================
Write-Host ''
Write-Host 'Step 2: Creating package structure...' -ForegroundColor Yellow

if (Test-Path $PackageStagingPath) {
    Remove-Item $PackageStagingPath -Recurse -Force
}

$null = New-Item -ItemType Directory -Path $PackageStagingPath -Force
$null = New-Item -ItemType Directory -Path (Join-Path $PackageStagingPath '.universal') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $PackageStagingPath 'apps' 'DevolutionsCIEM') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $PackageStagingPath 'Modules') -Force

# Copy module
Copy-Item -Path $ModuleSourcePath -Destination (Join-Path $PackageStagingPath 'Modules' 'Devolutions.CIEM') -Recurse -Force
Write-Host '  Copied: Modules/Devolutions.CIEM' -ForegroundColor Green

# Copy app
Copy-Item -Path $AppFilePath -Destination (Join-Path $PackageStagingPath 'apps' 'DevolutionsCIEM' 'app.ps1') -Force
Write-Host '  Copied: apps/DevolutionsCIEM/app.ps1' -ForegroundColor Green

# Create dashboards.ps1
$DashboardsContent = @'
# Devolutions CIEM App Registration
New-PSUApp -Name 'DevolutionsCIEM' `
    -FilePath 'apps\DevolutionsCIEM\app.ps1' `
    -BaseUrl '/ciem' `
    -Description 'Cloud Infrastructure Entitlement Management - Security Findings Dashboard' `
    -AutoDeploy
'@
Set-Content -Path (Join-Path $PackageStagingPath '.universal' 'dashboards.ps1') -Value $DashboardsContent -Encoding UTF8
Write-Host '  Created: .universal/dashboards.ps1' -ForegroundColor Green

# Create module manifest
$ManifestContent = @"
@{
    RootModule = 'Devolutions.CIEM.PSUApp.psm1'
    ModuleVersion = '$Version'
    GUID = 'b3f8d1e4-5a6c-4d2b-9e8f-1a2b3c4d5e6f'
    Author = 'Adam Bertram'
    CompanyName = 'Devolutions Inc.'
    Copyright = '(c) 2025 Devolutions Inc. All rights reserved.'
    Description = 'PowerShell Universal App for Cloud Infrastructure Entitlement Management (CIEM)'
    PowerShellVersion = '7.4'
    RequiredModules = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '4.0.0' }
    )
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('PowerShellUniversal', 'CIEM', 'Azure', 'Security', 'Identity', 'Dashboard')
            ProjectUri = 'https://github.com/Devolutions/Devolutions-CIEM'
        }
    }
}
"@
Set-Content -Path (Join-Path $PackageStagingPath 'Devolutions.CIEM.PSUApp.psd1') -Value $ManifestContent -Encoding UTF8
Write-Host '  Created: Devolutions.CIEM.PSUApp.psd1' -ForegroundColor Green

# Create psm1
$PsmContent = @'
# Devolutions.CIEM.PSUApp - PSU deployment package
$CIEMModulePath = Join-Path $PSScriptRoot 'Modules' 'Devolutions.CIEM' 'Devolutions.CIEM.psd1'
if (Test-Path $CIEMModulePath) {
    Import-Module $CIEMModulePath -Force -ErrorAction SilentlyContinue
}
'@
Set-Content -Path (Join-Path $PackageStagingPath 'Devolutions.CIEM.PSUApp.psm1') -Value $PsmContent -Encoding UTF8
Write-Host '  Created: Devolutions.CIEM.PSUApp.psm1' -ForegroundColor Green

# ============================================================================
# Step 3: Create NuPkg Package
# ============================================================================
Write-Host ''
Write-Host 'Step 3: Creating NuPkg package...' -ForegroundColor Yellow

if (-not (Test-Path $TempPath)) {
    $null = New-Item -ItemType Directory -Path $TempPath -Force
}

$NupkgPath = Compress-PSResource -Path $PackageStagingPath -DestinationPath $TempPath -PassThru
Write-Host "  Package: $($NupkgPath.Name) ($([math]::Round($NupkgPath.Length / 1KB, 2)) KB)" -ForegroundColor Green

# ============================================================================
# Step 4: Upload Deployment
# ============================================================================
Write-Host ''
Write-Host 'Step 4: Uploading deployment...' -ForegroundColor Yellow

# Connect to PSU
Connect-PSUServer -ComputerName $PSUServerUrl -AppToken $AppToken | Out-Null

# Check if deployment already exists and remove it
$ExistingDeployment = Get-PSUDeployment | Where-Object { $_.Name -eq $DeploymentName -and $_.Version -eq $Version }
if ($ExistingDeployment) {
    Write-Host "  Removing existing deployment v$Version..." -ForegroundColor Yellow
    $ExistingDeployment | Remove-PSUDeployment
}

# Upload via REST API (multipart form)
$Form = @{
    Name        = $DeploymentName
    Version     = $Version
    Description = "Devolutions CIEM App v$Version"
    File        = Get-Item -Path $NupkgPath.FullName
}
$null = Invoke-RestMethod -Uri "$PSUServerUrl/api/v1/deployment" -Headers @{ 'Authorization' = "Bearer $AppToken" } -Method Post -Form $Form
Write-Host '  Deployment uploaded' -ForegroundColor Green

# ============================================================================
# Step 5: Apply Deployment
# ============================================================================
Write-Host ''
Write-Host 'Step 5: Applying deployment...' -ForegroundColor Yellow

$Deployment = Get-PSUDeployment | Where-Object { $_.Name -eq $DeploymentName -and $_.Version -eq $Version }
if (-not $Deployment) {
    throw "Deployment '$DeploymentName' v$Version not found after upload"
}

if ($Pin) {
    $Deployment | Select-PSUDeployment -Pin
    Write-Host '  Deployment applied and pinned' -ForegroundColor Green
} else {
    $Deployment | Select-PSUDeployment
    Write-Host '  Deployment applied' -ForegroundColor Green
}

# ============================================================================
# Cleanup
# ============================================================================
Write-Host ''
Write-Host 'Cleanup...' -ForegroundColor Yellow

Remove-Item $PackageStagingPath -Recurse -Force
Write-Host '  Removed staging directory' -ForegroundColor Green

if (-not $KeepPackage) {
    Remove-Item $NupkgPath.FullName -Force
    Write-Host '  Removed NuPkg file' -ForegroundColor Green
} else {
    Write-Host "  Package retained: $($NupkgPath.FullName)" -ForegroundColor Cyan
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Deployment Complete!' -ForegroundColor Green
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "App URL: $PSUServerUrl/ciem" -ForegroundColor Yellow
Write-Host "Admin: $PSUServerUrl/admin" -ForegroundColor Yellow
