#Requires -Version 7.4

Set-StrictMode -Version Latest

# Resolve the Devolutions.CIEM module path from sibling directory (repo layout)
$script:CIEMModulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Devolutions.CIEM'

if (-not (Test-Path $script:CIEMModulePath)) {
    throw "Devolutions.CIEM module not found at: $script:CIEMModulePath. The Manager module must be located alongside the Devolutions.CIEM module in the repository."
}

# GitHub tree cache - reduces API calls from 67+ to 1 per ref (unauthenticated limit: 60/hr)
$script:GitHubTreeCache = @{}

# Get private and public function definition files
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'

$Private = @()
$Public = @()

if (Test-Path -Path $privatePath) {
    $Private = @(Get-ChildItem -Path $privatePath -Filter '*.ps1' -Recurse -ErrorAction Stop)
}

if (Test-Path -Path $publicPath) {
    $Public = @(Get-ChildItem -Path $publicPath -Filter '*.ps1' -Recurse -ErrorAction Stop)
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
