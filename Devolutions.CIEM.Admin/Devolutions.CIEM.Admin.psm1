$script:AdminRoot = $PSScriptRoot
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

# Path to the PSU app module root and Checks sub-folder
$script:PsuAppRoot  = Join-Path $PSScriptRoot '../psu-app'
$script:ChecksRoot  = Join-Path $script:PsuAppRoot 'modules/Devolutions.CIEM.Checks'

# GitHub API cache (shared across GetGitHubRepoTree calls within a session)
$script:GitHubTreeCache = @{}

# PSU connection state
$script:PSUConnection = @{
    Url           = $null
    Token         = $null
    IsAzure       = $false
    ResourceGroup = $null
    WebAppName    = $null
}

# --- Load private functions ---
foreach ($file in (Get-ChildItem "$PSScriptRoot/Private/*.ps1" -ErrorAction Stop)) {
    . $file.FullName
}

# --- Load public functions ---
foreach ($file in (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop)) {
    . $file.FullName
}

# --- Export public functions ---
$exportFunctions = (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop).BaseName
Export-ModuleMember -Function $exportFunctions
