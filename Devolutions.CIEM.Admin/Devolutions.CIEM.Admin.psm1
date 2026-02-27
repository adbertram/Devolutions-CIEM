$script:AdminRoot = $PSScriptRoot

# Path to the PSU app module's Checks sub-folder (for output directories and check data)
$script:ChecksRoot = Join-Path $PSScriptRoot '../psu-app/modules/Devolutions.CIEM.Checks'

# GitHub API cache (shared across Get-GitHubRepoTree calls within a session)
$script:GitHubTreeCache = @{}

# --- Load private functions ---
foreach ($file in (Get-ChildItem "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# --- Load public functions ---
foreach ($file in (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# --- Export public functions ---
$exportFunctions = (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue).BaseName
Export-ModuleMember -Function $exportFunctions
