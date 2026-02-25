$script:ModuleRoot = $PSScriptRoot

# --- Load classes (order matters: base types before derived) ---
$classOrder = @(
    'CIEMAuthenticationContext'
    'CIEMProvider'
    'CIEMProviderService'
    'CIEMServiceCache'
    'CIEMIdentity'
    'CIEMResourceType'
)

foreach ($className in $classOrder) {
    $classFile = Join-Path $PSScriptRoot "Classes/$className.ps1"
    if (Test-Path $classFile) {
        . $classFile
    }
}

# --- Load private functions ---
foreach ($file in (Get-ChildItem "$PSScriptRoot/Private/*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# --- Load public functions (before services — service scripts reference public functions) ---
foreach ($file in (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# --- Service scripts are NOT dot-sourced ---
# Services/*.ps1 are standalone scripts invoked by Initialize-CIEMServiceCache at runtime.
# They have param() blocks and execute API calls — not safe to dot-source at import time.

# --- Module-scoped state ---
$script:Config = $null
$script:AuthContext = @{}
$script:ARMAccessToken = $null
$script:GraphAccessToken = $null
$script:PSUEnvironment = $null
$script:DatabasePath = $null

# --- Argument completers ---
Register-CIEMArgumentCompleters

# --- Export public functions ---
$publicFunctions = (Get-ChildItem "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue) |
    Select-Object -ExpandProperty BaseName

Export-ModuleMember -Function $publicFunctions
