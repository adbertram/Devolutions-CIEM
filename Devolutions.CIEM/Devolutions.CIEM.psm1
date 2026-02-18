#Requires -Version 5.1

Set-StrictMode -Version Latest

# Module root path for use by all functions
$script:ModuleRoot = $PSScriptRoot

# NOTE: Auto-installs missing required modules at import time.
# This may cause delays on first import. Consider pre-installing via:
#   Install-PSResource -Name Az.Accounts, Az.Resources, Az.Websites, Microsoft.Graph.Applications
foreach ($moduleName in @('Az.Accounts', 'Az.Resources', 'Az.Websites', 'Microsoft.Graph.Applications')) {
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Write-Warning "Installing required module: $moduleName"
        Install-PSResource -Name $moduleName -Scope AllUsers -TrustRepository
    }
}

# Configuration is loaded from PSU cache after functions are dot-sourced
# (see bottom of file where Get-CIEMConfig is called)
$script:Config = $null

# Initialize authentication context (populated by Connect-CIEM)
$script:AuthContext = @{}
$script:ARMAccessToken = $null
$script:GraphAccessToken = $null

# Initialize PSU environment detection (populated on first access)
$script:PSUEnvironment = $null

# Get class, public, private, page, and check function definition files
# Note: Errors during file enumeration indicate a broken module structure and should fail loudly
$classesPath = Join-Path -Path $PSScriptRoot -ChildPath 'Classes'
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
$pagesPath   = Join-Path -Path $PSScriptRoot -ChildPath 'Pages'
$publicPath  = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$checksPath  = Join-Path -Path $PSScriptRoot -ChildPath 'Checks'

$Classes = @()
$Private = @()
$Pages   = @()
$Public  = @()
$Checks  = @()

if (Test-Path -Path $classesPath) {
    $Classes = @(Get-ChildItem -Path "$classesPath\*.ps1" -ErrorAction Stop)
}

if (Test-Path -Path $privatePath) {
    $Private = @(Get-ChildItem -Path "$privatePath\*.ps1" -ErrorAction Stop)
}

if (Test-Path -Path $pagesPath) {
    $Pages = @(Get-ChildItem -Path "$pagesPath\*.ps1" -ErrorAction Stop)
}

if (Test-Path -Path $publicPath) {
    $Public = @(Get-ChildItem -Path "$publicPath\*.ps1" -ErrorAction Stop)
}

if (Test-Path -Path $checksPath) {
    $Checks = @(Get-ChildItem -Path $checksPath -Filter '*.ps1' -Recurse -ErrorAction Stop)
}

# Dot source the files (classes first, then private, pages, checks, public)
# Pages are loaded before Public so New-DevolutionsCIEMApp can call page functions
foreach ($import in @($Classes + $Private + $Pages + $Checks + $Public)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
        throw
    }
}

# Export public functions
# Parse each public file to find all function definitions and export them
foreach ($file in $Public) {
    $content = Get-Content -Path $file.FullName -Raw
    $functionNames = [regex]::Matches($content, '(?m)^function\s+([A-Za-z0-9-]+)') | ForEach-Object { $_.Groups[1].Value }
    foreach ($funcName in $functionNames) {
        Export-ModuleMember -Function $funcName
    }
}

# Initialize configuration from PSU cache (or defaults if not in PSU)
# This must happen after functions are dot-sourced so Get-CIEMConfig is available
$script:Config = Get-CIEMConfig

# Register dynamic tab-completion for -Provider and -Name parameters
Register-CIEMArgumentCompleters
