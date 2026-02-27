$script:ModuleRoot = $PSScriptRoot

# --- Sub-module directory roots (for runtime file discovery) ---
$script:AzureRoot  = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.Azure.Infrastructure'
$script:AWSRoot    = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.AWS'
$script:ChecksRoot = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.Checks'
$script:IdentitiesRoot = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.Identities'
$script:AzurePermissionsRoot = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.Azure.Permissions'
$script:PSURoot    = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.PSU'

# All sub-module roots in load order
$subModuleRoots = @(
    $script:AzureRoot
    $script:AzurePermissionsRoot
    $script:AWSRoot
    $script:ChecksRoot
    $script:IdentitiesRoot
    $script:PSURoot
)

# --- Import PSUSQLite (bundled dependency) ---
Import-Module (Join-Path $PSScriptRoot 'modules/PSUSQLite/PSUSQLite.psd1') -Global

# --- Load classes in dependency order ---
# IMPORTANT: All dot-source calls MUST remain at the psm1 top level.
# Wrapping dot-source in a helper function scopes class and function
# definitions to that function, making them invisible to the module.

# Base classes (must load first - other classes depend on these)
foreach ($className in @('CIEMAuthenticationContext', 'CIEMProvider', 'CIEMIdentity', 'CIEMResourceType')) {
    . (Join-Path $PSScriptRoot "Classes/$className.ps1")
}

# Checks classes (explicit order: base types before derived)
foreach ($className in @('CIEMServiceCache', 'CIEMProviderService', 'CIEMCheck', 'CIEMScanResult')) {
    $classFile = Join-Path $script:ChecksRoot "Classes/$className.ps1"
    if (Test-Path $classFile) { . $classFile }
}

# Identity classes (explicit order: node -> derived -> edge -> container)
foreach ($classFile in @('CIEMGraphNode.ps1', 'CIEMIdentityNodes.ps1', 'CIEMRBACNodes.ps1', 'CIEMGraphEdge.ps1', 'CIEMGraph.ps1')) {
    $path = Join-Path $script:IdentitiesRoot "Classes/$classFile"
    if (Test-Path $path) { . $path }
}

# Unordered classes (Azure, Azure Permissions, AWS - no interdependencies)
foreach ($root in @($script:AzureRoot, $script:AzurePermissionsRoot, $script:AWSRoot)) {
    foreach ($file in (Get-ChildItem (Join-Path $root 'Classes/*.ps1') -ErrorAction SilentlyContinue)) {
        . $file.FullName
    }
}

# --- Load private and public functions (base + all sub-modules) ---
foreach ($subdir in @('Private', 'Public')) {
    foreach ($file in (Get-ChildItem "$PSScriptRoot/$subdir/*.ps1" -ErrorAction SilentlyContinue)) {
        . $file.FullName
    }
    foreach ($root in $subModuleRoots) {
        foreach ($file in (Get-ChildItem (Join-Path $root "$subdir/*.ps1") -ErrorAction SilentlyContinue)) {
            . $file.FullName
        }
    }
}

# --- Load PSU page functions (must be exported for PSU's scriptblock resolution) ---
foreach ($file in (Get-ChildItem "$script:PSURoot/Pages/*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# --- Module-scoped state ---
# Base
$script:Config = $null
$script:AuthContext = @{}
$script:PSUEnvironment = $null
$script:DatabasePath = $null
$script:ProviderTypes = @{}
# Azure
$script:ARMAccessToken = $null
$script:GraphAccessToken = $null
$script:KeyVaultAccessToken = $null
# AWS
$script:AWSAuthContext = $null
# PSU
$script:RelationshipColors = @{
    'CAN_MANAGE' = '#f44336'
    'CAN_WRITE'  = '#ff9800'
    'CAN_READ'   = '#4caf50'
    'HAS_ROLE'   = '#1976d2'
}

# --- Initialize database (base + provider schemas) ---
try {
    New-CIEMDatabase
}
catch {
    Write-Warning "CIEM DB: Auto-initialization failed: $($_.Exception.Message)"
}

# Apply provider-specific schemas
foreach ($schema in @(
    @{ Path = Join-Path $script:AzureRoot 'Data/azure_schema.sql';                          Label = 'Azure' }
    @{ Path = Join-Path $script:AzurePermissionsRoot 'Data/azure_permissions_schema.sql';    Label = 'Azure Permissions' }
)) {
    try {
        $dbPath = Get-CIEMDatabasePath
        if ($dbPath -and (Test-Path $schema.Path)) {
            $conn = Open-PSUSQLiteConnection -Database $dbPath
            try {
                $schemaSql = Get-Content -Path $schema.Path -Raw
                foreach ($statement in ($schemaSql -split ';\s*\n' | Where-Object { $_.Trim() })) {
                    Invoke-PSUSQLiteQuery -Connection $conn -Query $statement.Trim() -AsNonQuery | Out-Null
                }
            }
            finally {
                $conn.Dispose()
            }
        }
    }
    catch {
        Write-Warning "CIEM $($schema.Label): Schema initialization failed: $($_.Exception.Message)"
    }
}

# --- Register provider types ---
Register-CIEMAzureProviderType
Register-CIEMAWSProviderType

# --- Argument completers ---
Register-CIEMArgumentCompleters

# --- Export all public + page functions ---
$exportDirs = @("$PSScriptRoot/Public")
foreach ($root in $subModuleRoots) {
    $exportDirs += Join-Path $root 'Public'
}
$exportDirs += "$script:PSURoot/Pages"

$exportFunctions = @()
foreach ($dir in $exportDirs) {
    $exportFunctions += (Get-ChildItem "$dir/*.ps1" -ErrorAction SilentlyContinue).BaseName
}

Export-ModuleMember -Function $exportFunctions
