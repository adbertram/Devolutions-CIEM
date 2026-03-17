$script:ModuleRoot = $PSScriptRoot

# --- Bootstrap logger (used before Write-CIEMLog is dot-sourced) ---
$script:_BootLogPath = Join-Path $PSScriptRoot 'data/ciem.log'
function _BootLog([string]$Msg, [string]$Sev = 'INFO') {
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] [$Sev] [ModuleInit] $Msg"
    try { Add-Content -Path $script:_BootLogPath -Value $entry -Encoding UTF8 -ErrorAction SilentlyContinue } catch {}
}

_BootLog "Module loading from: $PSScriptRoot"

# --- Sub-module directory roots (for runtime file discovery) ---
$script:AzureRoot           = Join-Path $PSScriptRoot 'modules/Azure/Infrastructure'
$script:AzureDiscoveryRoot  = Join-Path $PSScriptRoot 'modules/Azure/Discovery'
$script:AWSRoot             = Join-Path $PSScriptRoot 'modules/AWS/Infrastructure'
$script:ChecksRoot          = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.Checks'
$script:PSURoot             = Join-Path $PSScriptRoot 'modules/Devolutions.CIEM.PSU'

# All sub-module roots in load order
$subModuleRoots = @(
    $script:AzureRoot
    $script:AzureDiscoveryRoot
    $script:AWSRoot
    $script:ChecksRoot
    $script:PSURoot
)

# --- Import PSUSQLite (bundled dependency) ---
_BootLog "Importing PSUSQLite..."
Import-Module (Join-Path $PSScriptRoot 'modules/PSUSQLite/PSUSQLite.psd1') -Global
_BootLog "PSUSQLite imported"

# --- Load classes in dependency order ---
# IMPORTANT: All dot-source calls MUST remain at the psm1 top level.
# Wrapping dot-source in a helper function scopes class and function
# definitions to that function, making them invisible to the module.

# Base classes (must load first - other classes depend on these)
_BootLog "Loading base classes..."
foreach ($className in @('CIEMAuthenticationContext', 'CIEMProvider')) {
    $classPath = Join-Path $PSScriptRoot "Classes/$className.ps1"
    try { . $classPath } catch { _BootLog "FAILED to load class $className : $_" 'ERROR' }
}

# Checks classes (explicit order: base types before derived)
_BootLog "Loading Checks classes..."
foreach ($className in @('CIEMServiceCache', 'CIEMProviderService', 'CIEMCheck', 'CIEMScanResult')) {
    $classFile = Join-Path $script:ChecksRoot "Classes/$className.ps1"
    if (Test-Path $classFile) { try { . $classFile } catch { _BootLog "FAILED to load class $className : $_" 'ERROR' } }
}

# Unordered classes (Azure, Azure Discovery, AWS - no interdependencies)
_BootLog "Loading provider classes..."
foreach ($root in @($script:AzureRoot, $script:AzureDiscoveryRoot, $script:AWSRoot)) {
    foreach ($file in (Get-ChildItem (Join-Path $root 'Classes/*.ps1') -ErrorAction SilentlyContinue)) {
        try { . $file.FullName } catch { _BootLog "FAILED to load class $($file.Name) : $_" 'ERROR' }
    }
}

# --- Load private and public functions (base + all sub-modules) ---
$_loadedCount = 0
$_failedCount = 0
foreach ($subdir in @('Private', 'Public')) {
    foreach ($file in (Get-ChildItem "$PSScriptRoot/$subdir/*.ps1" -ErrorAction SilentlyContinue)) {
        try { . $file.FullName; $_loadedCount++ } catch { _BootLog "FAILED to load $subdir/$($file.Name) : $_" 'ERROR'; $_failedCount++ }
    }
    foreach ($root in $subModuleRoots) {
        $rootName = Split-Path $root -Leaf
        foreach ($file in (Get-ChildItem (Join-Path $root "$subdir/*.ps1") -ErrorAction SilentlyContinue)) {
            try { . $file.FullName; $_loadedCount++ } catch { _BootLog "FAILED to load $rootName/$subdir/$($file.Name) : $_" 'ERROR'; $_failedCount++ }
        }
    }
}

# Switch to Write-CIEMLog now that it's available
Write-CIEMLog -Message "Loaded $_loadedCount functions ($_failedCount failures)" -Component 'ModuleInit'

# --- Load PSU page functions (must be exported for PSU's scriptblock resolution) ---
foreach ($file in (Get-ChildItem "$script:PSURoot/Pages/*.ps1" -ErrorAction SilentlyContinue)) {
    try { . $file.FullName; $_loadedCount++ } catch { Write-CIEMLog "FAILED to load Page $($file.Name) : $_" -Severity ERROR -Component 'ModuleInit'; $_failedCount++ }
}
Write-CIEMLog -Message "PSU pages loaded (total: $_loadedCount functions, $_failedCount failures)" -Component 'ModuleInit'

# --- Module-scoped state ---
# Base
$script:Config = $null
$script:AuthContext = @{}
$script:PSUEnvironment = $null
$script:DatabasePath = $null
# Azure
$script:AzureAuthContext = $null  # [CIEMAzureAuthContext] — set by Connect-CIEMAzure
$script:AzureAuthProfilesCacheKey = 'CIEM:AuthProfiles:Azure'
$script:AWSAuthProfileCacheKey    = 'CIEM:AuthProfile:AWS'
$script:CIEMConfigCacheKey        = 'CIEM:Config'
$script:ScanConfigCacheKey        = 'CIEM:ScanConfig'
# AWS
$script:AWSAuthContext = $null
# PSU
$script:RelationshipColors = @{
    'CONTAINS'             = '#1976d2'   # ARM hierarchy containment (blue)
    'member_of'            = '#9c27b0'   # Group membership (purple)
    'owner_of'             = '#f44336'   # Ownership (red)
    'has_role_member'      = '#ff9800'   # Role membership (orange)
    'transitive_member_of' = '#4caf50'   # Transitive membership (green)
}

# --- Initialize database (base + provider schemas) ---
Write-CIEMLog -Message "Initializing database..." -Component 'ModuleInit'
try {
    New-CIEMDatabase
    Write-CIEMLog -Message "Database initialized at: $(Get-CIEMDatabasePath)" -Component 'ModuleInit'
}
catch {
    Write-CIEMLog -Message "Database initialization failed: $($_.Exception.Message)" -Severity ERROR -Component 'ModuleInit'
}

# Apply provider-specific schemas
foreach ($schema in @(
    @{ Path = Join-Path $script:AzureRoot          'Data/azure_schema.sql';         Label = 'Azure' }
    @{ Path = Join-Path $script:AzureDiscoveryRoot 'Data/discovery_schema.sql';     Label = 'AzureDiscovery' }
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
        Write-CIEMLog -Message "$($schema.Label) schema failed: $($_.Exception.Message)" -Severity ERROR -Component 'ModuleInit'
    }
}

# --- Argument completers ---
Register-CIEMArgumentCompleters

# --- Export all public + page functions ---
$exportDirs = @("$PSScriptRoot/Public")
foreach ($root in $subModuleRoots) {
    $exportDirs += Join-Path $root 'Public'
}

$exportFunctions = @()
foreach ($dir in $exportDirs) {
    $files = Get-ChildItem "$dir/*.ps1" -ErrorAction SilentlyContinue
    if ($files) { $exportFunctions += $files.BaseName }
}

# Page files may define multiple functions per file — extract all function names
# (required because [scriptblock]::Create() in PSU tab/onClick only sees exported functions)
foreach ($pageFile in (Get-ChildItem "$script:PSURoot/Pages/*.ps1" -ErrorAction SilentlyContinue)) {
    $content = Get-Content $pageFile.FullName -Raw
    $fnMatches = [regex]::Matches($content, '(?m)^function\s+([\w-]+)')
    foreach ($m in $fnMatches) {
        $exportFunctions += $m.Groups[1].Value
    }
}

Write-CIEMLog -Message "Exporting $($exportFunctions.Count) functions" -Component 'ModuleInit'
Export-ModuleMember -Function $exportFunctions
Write-CIEMLog -Message "Module load complete" -Component 'ModuleInit'
