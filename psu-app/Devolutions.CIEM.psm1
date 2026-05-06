$script:ModuleRoot = $PSScriptRoot

# --- Resolve data root (outside module version dir so data survives upgrades) ---
if ($PSScriptRoot -match '(.*[/\\])Repository[/\\]Modules[/\\]') {
    $script:DataRoot = Join-Path $Matches[1] 'data'
} else {
    $script:DataRoot = Join-Path $PSScriptRoot 'data'
}
if (-not (Test-Path $script:DataRoot)) {
    New-Item -Path $script:DataRoot -ItemType Directory -Force | Out-Null
}

# --- Bootstrap logger (used before Write-CIEMLog is dot-sourced) ---
$script:_BootLogPath = Join-Path $script:DataRoot 'ciem.log'
function _BootLog([string]$Msg, [string]$Sev = 'INFO') {
    $ErrorActionPreference = 'Stop'
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff')] [$Sev] [ModuleInit] $Msg"
    Add-Content -Path $script:_BootLogPath -Value $entry -Encoding UTF8 -ErrorAction Stop
}

_BootLog "Module loading from: $PSScriptRoot"

# --- Sub-module directory roots (for runtime file discovery) ---
$script:CIEMModuleRootsConfig = Import-PowerShellDataFile -Path (Join-Path $script:ModuleRoot 'Data/module_roots.psdata')
$script:CIEMModuleRoots = @($script:CIEMModuleRootsConfig.Modules | Sort-Object LoadOrder)
if ($script:CIEMModuleRoots.Count -eq 0) {
    throw "CIEM module root registry contains no modules."
}

foreach ($rootEntry in $script:CIEMModuleRoots) {
    foreach ($requiredField in @('Name', 'Variable', 'Path', 'LoadOrder', 'LoadClasses')) {
        if (-not $rootEntry.ContainsKey($requiredField)) {
            throw "CIEM module root registry entry is missing required field '$requiredField'."
        }
    }

    foreach ($stringField in @('Name', 'Variable', 'Path')) {
        if ([string]::IsNullOrWhiteSpace([string]$rootEntry.$stringField)) {
            throw "CIEM module root registry entry has an empty '$stringField' field."
        }
    }

    if ([int]$rootEntry.LoadOrder -le 0) {
        throw "CIEM module root registry load order must be positive for '$($rootEntry.Name)'."
    }

    $resolvedRoot = Join-Path $PSScriptRoot ([string]$rootEntry.Path)
    if (-not (Test-Path -Path $resolvedRoot -PathType Container)) {
        throw "CIEM module root '$($rootEntry.Name)' was not found: $resolvedRoot"
    }

    Set-Variable -Name ([string]$rootEntry.Variable) -Scope Script -Value $resolvedRoot
}

$subModuleRoots = @($script:CIEMModuleRoots | ForEach-Object {
    Get-Variable -Name ([string]$_.Variable) -Scope Script -ValueOnly
})

# --- Severity catalog (single source of truth for name/rank/color/label) ---
$script:SeverityByName = @{}
$script:SeverityCatalog = @(
    Get-Content (Join-Path $script:PSURoot 'Data/severity_catalog.json') -Raw | ConvertFrom-Json
)
foreach ($s in $script:SeverityCatalog) { $script:SeverityByName[$s.name] = $s }

# --- Status catalog (single source of truth for status name/color/label) ---
$script:StatusByName = @{}
$script:StatusCatalog = @(
    Get-Content (Join-Path $script:PSURoot 'Data/status_catalog.json') -Raw | ConvertFrom-Json
)
foreach ($s in $script:StatusCatalog) { $script:StatusByName[$s.name] = $s }

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
    try { . $classPath } catch { _BootLog "FAILED to load class $className : $_" 'ERROR'; throw }
}

# Checks classes (explicit order: base types before derived)
_BootLog "Loading Checks classes..."
foreach ($className in @('CIEMServiceCache', 'CIEMProviderService', 'CIEMCheck', 'CIEMScanResult')) {
    $classFile = Join-Path $script:ChecksRoot "Classes/$className.ps1"
    if (-not (Test-Path $classFile)) {
        _BootLog "FAILED to load class $className : file not found at $classFile" 'ERROR'
        throw "Required class file not found: $classFile"
    }
    try { . $classFile } catch { _BootLog "FAILED to load class $className : $_" 'ERROR'; throw }
}

# Unordered classes (provider modules with no interdependencies)
_BootLog "Loading provider classes..."
foreach ($root in @($script:CIEMModuleRoots | Where-Object { [bool]$_.LoadClasses } | ForEach-Object {
    Get-Variable -Name ([string]$_.Variable) -Scope Script -ValueOnly
})) {
    foreach ($file in (Get-ChildItem (Join-Path $root 'Classes/*.ps1') -ErrorAction Stop)) {
        try { . $file.FullName } catch { _BootLog "FAILED to load class $($file.Name) : $_" 'ERROR'; throw }
    }
}

# --- Load private and public functions (base + all sub-modules) ---
$_loadedCount = 0
$_failedCount = 0
foreach ($subdir in @('Private', 'Public')) {
    foreach ($file in (Get-ChildItem "$PSScriptRoot/$subdir/*.ps1" -ErrorAction Stop)) {
        try { . $file.FullName; $_loadedCount++ } catch { _BootLog "FAILED to load $subdir/$($file.Name) : $_" 'ERROR'; $_failedCount++; throw }
    }
    foreach ($root in $subModuleRoots) {
        $rootName = Split-Path $root -Leaf
        $sourceDirectory = Join-Path $root $subdir
        if (Test-Path -Path $sourceDirectory -PathType Container) {
            foreach ($file in (Get-ChildItem (Join-Path $sourceDirectory '*.ps1') -ErrorAction Stop)) {
                try { . $file.FullName; $_loadedCount++ } catch { _BootLog "FAILED to load $rootName/$subdir/$($file.Name) : $_" 'ERROR'; $_failedCount++; throw }
            }
        }
    }
}

# Switch to Write-CIEMLog now that it's available
Write-CIEMLog -Message "Loaded $_loadedCount functions ($_failedCount failures)" -Component 'ModuleInit'

# --- Load PSU page functions (must be exported for PSU's scriptblock resolution) ---
foreach ($file in (Get-ChildItem "$script:PSURoot/Pages/*.ps1" -ErrorAction Stop)) {
    try { . $file.FullName; $_loadedCount++ } catch { Write-CIEMLog "FAILED to load Page $($file.Name) : $_" -Severity ERROR -Component 'ModuleInit'; $_failedCount++; throw }
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
$script:RelationshipColors = @{}
(Get-Content (Join-Path $script:ModuleRoot 'Data/relationship_colors.json') -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object {
    $script:RelationshipColors[$_.Name] = $_.Value
}

# Risk policy constants
$script:DormantPermissionThresholdDays = 90
$script:MediumEntitlementThreshold = 5
$script:PrivilegedRoleNames = @((Get-Content (Join-Path $script:AzureDiscoveryRoot 'Data/privileged_roles.json') -Raw | ConvertFrom-Json).name)
$script:CIEMGraphEntitiesConfig = Import-PowerShellDataFile -Path (Join-Path $script:GraphRoot 'Data/entities.psdata')
$script:CIEMAttackPathRemediationTokensConfig = Import-PowerShellDataFile -Path (Join-Path $script:GraphRoot 'Data/remediation_tokens.psdata')
$script:CIEMAzureEntitiesConfig = Import-PowerShellDataFile -Path (Join-Path $script:AzureDiscoveryRoot 'Data/entities.psdata')
$script:CIEMAzureDiscoveryPhasesConfig = Import-PowerShellDataFile -Path (Join-Path $script:AzureDiscoveryRoot 'Data/discovery_phases.psdata')
# Tunables (script-scope, all defined in one place for discoverability)
# CIEMParallelThrottleLimit*: ForEach-Object -Parallel throttle for discovery vs scan workloads.
# CIEMSqlBatchSize: cap on rows per multi-row INSERT before InvokeCIEMBatchInsert further sub-divides
#   to stay under SQLite's 999 SQL parameter limit (chunk = floor(999 / column count)).
# CIEMGraphBatchSize: max sub-requests in a single Microsoft Graph $batch POST (Graph hard cap is 20).
# CIEMGraphBatchWallClockSeconds: total budget for retry-loop wall-clock time on a single Graph batch
#   chunk before throwing. Prevents indefinite stalls when sub-requests stay 429.
$script:CIEMParallelThrottleLimitDiscovery = 5
$script:CIEMParallelThrottleLimitScan = 10
$script:CIEMSqlBatchSize = 500
$script:CIEMGraphBatchSize = 20
$script:CIEMGraphBatchWallClockSeconds = 300

# --- Import-time setup ---
$setupScriptPath = Join-Path $PSScriptRoot 'setup.ps1'
if (-not (Test-Path -Path $setupScriptPath -PathType Leaf)) {
    throw "CIEM setup script was not found: $setupScriptPath"
}
try {
    . $setupScriptPath
}
catch {
    Write-CIEMLog -Message "FAILED to run setup.ps1 : $_" -Severity ERROR -Component 'ModuleInit'
    throw
}

# --- Argument completers ---
RegisterCIEMArgumentCompleters

# --- Export all public + page functions ---
$exportDirs = @("$PSScriptRoot/Public")
foreach ($root in $subModuleRoots) {
    $exportDirs += Join-Path $root 'Public'
}

$exportFunctions = @()
foreach ($dir in $exportDirs) {
    $files = Get-ChildItem "$dir/*.ps1" -ErrorAction Stop
    if ($files) { $exportFunctions += $files.BaseName }
}

$exportFunctions += @(GetCIEMPSUPageRegistry | ForEach-Object { [string]$_.factory })
$exportFunctions = @($exportFunctions | Sort-Object -Unique)

Write-CIEMLog -Message "Exporting $($exportFunctions.Count) functions" -Component 'ModuleInit'
Export-ModuleMember -Function $exportFunctions
Write-CIEMLog -Message "Module load complete" -Component 'ModuleInit'
