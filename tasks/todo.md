# Split Devolutions.CIEM → Devolutions.CIEM.Checks + Devolutions.CIEM.PSU

## Step 1: Prep Base module
- [x] Export `Invoke-CIEMQuery` from Base (moved to Public, added to psd1)
- [x] Remove `Sync-CIEMChecksToDatabase` from Base (DB ships pre-populated)
- [x] Update `New-CIEMDatabase` to not call `Sync-CIEMChecksToDatabase`
- [x] Add `Get-CIEMRuntimeAuth` — exposes `$script:AuthContext` for Checks module
- [x] Add `Get-CIEMDatabasePath` — exposes `$script:DatabasePath` for Checks module
- [x] Export `Invoke-AzureApi`, `Invoke-AWSAPI`, `Get-AllGraphPage` (moved to Public)
- [x] Move scan-specific classes out of Base (CIEMServiceCache, CIEMProviderService, CIEMIdentity, CIEMResourceType)
- [x] Move `Initialize-CIEMServiceCache` to Checks

## Step 2: Update Graph module
- [x] Change `RequiredModules` from `Devolutions.CIEM` to `Devolutions.CIEM.Base`

## Step 3: Create Devolutions.CIEM.Checks
- [x] Create directory structure and module files (psm1, psd1)
- [x] Copy classes: CIEMCheck, CIEMScanResult + moved: CIEMServiceCache, CIEMProviderService, CIEMIdentity, CIEMResourceType
- [x] Copy public functions: Invoke-CIEMScan, Get-CIEMCheck, Get-CIEMScanRun, Get-CIEMScanResult, Get-CIEMProviderService, Get-CIEMRequiredPermission, Get-CIEMIdentity, Get-CIEMResourceType
- [x] Copy private functions: New/Save/Update-CIEMScanRun, Test-EntraAuthorizationPolicyBooleanSetting, Initialize-CIEMServiceCache
- [x] Copy Checks/ (648 scripts), Services/ (7 scripts), Data/ (2 JSON files)
- [x] Fix `Invoke-CIEMScan`: replace `$script:Config` → `Get-CIEMConfig`, `$script:AuthContext` → `Get-CIEMRuntimeAuth`, fix check scripts path
- [x] Fix `Save-CIEMScanRun`: `$script:DatabasePath` → `Get-CIEMDatabasePath`
- [x] Fix `Get-CIEMProviderService`: read from DB instead of ciem_checks.json (fixed column name too)
- [x] Fix `Initialize-CIEMServiceCache`: `[CIEMProvider]` → untyped param (cross-module class boundary)
- [x] Fix AWS check script: `$script:AuthContext` → `Get-CIEMRuntimeAuth`

## Step 4: Create Devolutions.CIEM.PSU
- [x] Create directory structure and module files (psm1, psd1)
- [x] Copy .universal/dashboards.ps1 (updated module reference)
- [x] Copy Pages/ (7 page files)
- [x] Copy Public: New-DevolutionsCIEMApp, New-CIEMUIContent, Get-PSUInstalledEnvironment, Get-CIEMRelationshipColor
- [x] Update 20 `Import-Module Devolutions.CIEM` references → `Devolutions.CIEM.PSU` across 6 page files

## Step 5: Update Invoke-TestCommand.ps1
- [x] Updated module imports to load Base + Graph + Checks

## Step 6: Delete Devolutions.CIEM
- [x] Remove entire Devolutions.CIEM/ directory
- [x] Fix CheckCount in Get-CIEMProvider (pointed to old module path)
- [x] Update Manager module path reference and Get-CIEMCheck to use DB
- [x] Update Graph module description text
- [x] Fix remaining old module name references

## Step 7: Update CLAUDE.md and memory
- [x] Update memory notes

## Step 8: Verify
- [x] All modules import without errors
- [x] No duplicate functions across modules (39 total, 0 duplicates)
- [x] Get-CIEMProvider, Get-CIEMCheck, Get-CIEMProviderService all work
- [x] All 17 key functions available via Get-Command
