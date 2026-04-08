# Pester Test Framework

**Technology**: Pester 5.x, PowerShell 7.5+

## Test Architecture

### Module Import Pattern
```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}
```
**Critical:** Never `Import-Module -Force` — breaks PowerShell classes.

### Database Isolation
CRUD tests use `$TestDrive` (auto-cleaned by Pester):
```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    $schema = Join-Path $PSScriptRoot '..path..' 'Data' 'schema_file.sql'
    Invoke-CIEMQuery -Query (Get-Content $schema -Raw)
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}
```
**Note:** `New-CIEMDatabase` creates base schema only. Provider-specific schemas must be applied separately.

### InModuleScope
Classes and private functions are only visible inside module scope:
```powershell
InModuleScope Devolutions.CIEM {
    $obj = [CIEMAzureArmResource]::new()
    Get-Command NewCIEMAzureResourceType | Should -Not -BeNullOrEmpty
}
```
**Always** `InModuleScope Devolutions.CIEM` — never sub-folder names.

## Directory Structure

```
psu-app/
├── Tests/Unit/                              # Module-level unit tests
│   ├── Psm1Structure.Tests.ps1              # Source assertions (no import)
│   ├── PSUIntegration.Tests.ps1             # Class/structure via InModuleScope
│   └── ModuleLoad.Tests.ps1                 # Export validation via Get-Command
│
├── modules/Azure/Discovery/Tests/Unit/      # Discovery unit tests
│   ├── CIEMAzureArmResource.Tests.ps1       # CRUD ($TestDrive DB)
│   ├── CIEMAzureEntraResource.Tests.ps1
│   ├── CIEMAzureDiscoveryRun.Tests.ps1
│   ├── CIEMAzureResourceType.Tests.ps1
│   ├── CIEMAzureResourceRelationship.Tests.ps1
│   ├── SchemaCleanup.Tests.ps1              # Schema validation ($TestDrive DB)
│   ├── DiscoveryClasses.Tests.ps1           # Class properties via InModuleScope
│   ├── StartCIEMAzureDiscovery.Tests.ps1    # Command structure + concurrency
│   ├── InvokeAzureApi429.Tests.ps1          # Source assertions (no import)
│   └── InvokeCIEMScanRefactor.Tests.ps1     # Source assertions (no import)
│
├── modules/Azure/Infrastructure/Tests/
│   ├── Unit/ConnectCIEMAzure.Tests.ps1      # Source assertions + structure
│   └── E2E/Azure/Authentication/            # E2E (requires PSU)
```

## Test Categories

| Category | Tests | DB Needed | Import Module |
|----------|-------|-----------|---------------|
| **Source Assertion** | Psm1Structure, InvokeAzureApi429, InvokeCIEMScanRefactor | No | No |
| **Structure** | ModuleLoad, PSUIntegration, ConnectCIEMAzure | No | Yes |
| **Schema** | SchemaCleanup | Yes | Yes |
| **Classes** | DiscoveryClasses | No | Yes |
| **CRUD** | ArmResource, EntraResource, DiscoveryRun, ResourceType, ResourceRelationship | Yes | Yes |
| **Command** | StartCIEMAzureDiscovery | No | Yes |
| **E2E** | certificate, service_principal | No (real) | Yes + PSU |

## Unit Test Isolation Rules

Unit tests MUST NOT:
- Read/write real filesystem paths (`ciem.log`, `ciem.db`) — use `$TestDrive` or mocks
- Make network calls to Azure, Graph, or any external API
- Depend on PSU running (`Get-PSUCache`, `Set-PSUCache`)
- Use `-ErrorAction SilentlyContinue` in `It` blocks

## Test Execution

```bash
# All tests
pwsh -NoProfile -Command "Invoke-Pester psu-app/ -Output Detailed"

# Specific file
pwsh -NoProfile -Command "Invoke-Pester path/to/test.Tests.ps1 -Output Detailed"

# By tag
pwsh -NoProfile -Command "Invoke-Pester psu-app/ -Tag 'CRUD' -Output Detailed"

# Diagnostic (max verbosity)
pwsh -NoProfile -Command "Invoke-Pester path/to/test.Tests.ps1 -Output Diagnostic"
```

## Troubleshooting

1. **Check boot log:** `tail -50 psu-app/data/ciem.log`
2. **Run diagnostic:** `-Output Diagnostic`
3. **Verify schema:** `Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table'"`
4. **Check exports:** `Get-Command -Module Devolutions.CIEM | Sort-Object Name`
5. **Fix implementation, not test** — after 2 failed fixes, STOP and present options

## Test Removal Policy

**NEVER remove or comment out tests without explicit user approval.**
1. Analyze and attempt to fix/refactor first
2. If unfixable, explain the issue and propose options
3. Only remove after explicit user approval

## Common Gotchas

| Issue | Solution |
|-------|----------|
| `Import-Module -Force` breaks classes | `Remove-Module -Force` then `Import-Module` (no `-Force`) |
| `InModuleScope Devolutions.CIEM.Identities` fails | Use `InModuleScope Devolutions.CIEM` |
| Test DB missing tables | Apply all required schema files after `New-CIEMDatabase` |
| Class not found in tests | Use `InModuleScope` |
| Private function not found | `InModuleScope` with `Get-Command FuncName` (no dash = private) |
| Data bleeds between Contexts | Use `BeforeEach` to reset state |
| `Should -Not -Exist` vs `Test-Path` | Always `Should -Not -Exist` for filesystem assertions |
| Conditional `if (Test-Path)` guards | Remove — let missing files fail loudly |