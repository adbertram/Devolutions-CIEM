#Requires -Version 7.4

Set-StrictMode -Version Latest

# Resolve the Devolutions.CIEM module root for functions that operate on check files
$ciemModule = Get-Module -Name 'Devolutions.CIEM' -ListAvailable | Select-Object -First 1
if ($ciemModule) {
    $script:CIEMModuleRoot = $ciemModule.ModuleBase
} else {
    # Fallback: assume sibling directory layout (repo development)
    $script:CIEMModuleRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'Devolutions.CIEM'
}

if (-not (Test-Path $script:CIEMModuleRoot)) {
    Write-Warning "Devolutions.CIEM module root not found at: $script:CIEMModuleRoot. Functions that modify check files will fail."
}

# GitHub tree cache - reduces API calls from 67+ to 1 per ref (unauthenticated limit: 60/hr)
$script:GitHubTreeCache = @{}

# Get private and public function definition files
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'

$Private = @()
$Public = @()

if (Test-Path -Path $privatePath) {
    $Private = @(Get-ChildItem -Path $privatePath -Filter '*.ps1' -ErrorAction Stop)
}

if (Test-Path -Path $publicPath) {
    $Public = @(Get-ChildItem -Path $publicPath -Filter '*.ps1' -ErrorAction Stop)
}

# Dot source the files (private first, then public)
foreach ($import in @($Private + $Public)) {
    try {
        Write-Verbose "Importing $($import.FullName)"
        . $import.FullName
    } catch {
        Write-Error "Failed to import function $($import.FullName): $_"
        throw
    }
}

# Export public functions
foreach ($file in $Public) {
    Export-ModuleMember -Function $file.BaseName
}
