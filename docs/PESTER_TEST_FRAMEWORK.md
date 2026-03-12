# Pester Test Framework

**Technology**: Pester 5.x, PowerShell 7.5+

---

## Overview

The Pester test suite validates module functions against a real SQLite database using `$TestDrive` isolation. Tests are designed to be modular, maintainable, and cross-platform.

**Key Principle:** Tests should run on ALL operating systems by default (Windows, macOS, Linux). Only restrict when genuinely required.

---

## Test Architecture

### Module Import

```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
}
```

**Critical:** Never use `Import-Module -Force` — it breaks PowerShell classes. Use `Remove-Module -Force` first, then `Import-Module` without `-Force`.

### Database Isolation

CRUD tests use a real SQLite database in `$TestDrive` (auto-cleaned by Pester):

```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    # Apply provider-specific schemas as needed
    $schema = Join-Path $PSScriptRoot '..path..' 'Data' 'schema_file.sql'
    Invoke-CIEMQuery -Query (Get-Content $schema -Raw)
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}
```

**Note:** `New-CIEMDatabase` creates only the base schema. Provider-specific schemas (e.g., `azure_schema.sql`, `discovery_schema.sql`) must be applied separately, matching what the psm1 does at module load.

### InModuleScope

PowerShell classes and private functions defined via dot-source in the psm1 are only visible inside the module scope:

```powershell
# Access classes
InModuleScope Devolutions.CIEM {
    $obj = [CIEMAzureArmResource]::new()
    $obj.PSObject.Properties.Name | Should -Contain 'Id'
}

# Access private functions (no-dash naming)
InModuleScope Devolutions.CIEM {
    Get-Command NewCIEMAzureResourceType | Should -Not -BeNullOrEmpty
}
```

**Important:** Always use `InModuleScope Devolutions.CIEM` — never use sub-folder names like `Devolutions.CIEM.Identities` (they are dot-sourced folders, not real modules).

---

## Directory Structure

```
psu-app/
├── Tests/                                    # Module-level tests
│   ├── ModuleLoad.Tests.ps1                  # Module imports, exports, deletions
│   ├── SchemaCleanup.Tests.ps1               # Database schema validation
│   ├── InvokeAzureApi429.Tests.ps1           # Structural/contract tests
│   └── InvokeCIEMScanRefactor.Tests.ps1      # Structural/contract tests
│
├── modules/Azure/Discovery/Tests/            # Discovery feature tests
│   ├── DiscoverySchema.Tests.ps1             # Schema & table existence
│   ├── CIEMAzureArmResource.Tests.ps1        # ARM CRUD
│   ├── CIEMAzureEntraResource.Tests.ps1      # Entra CRUD
│   ├── CIEMAzureDiscoveryRun.Tests.ps1       # Discovery Run CRUD
│   ├── CIEMAzureResourceType.Tests.ps1       # Resource Type Get
│   ├── CIEMAzureResourceRelationship.Tests.ps1  # Relationship CRUD
│   ├── StartCIEMAzureDiscovery.Tests.ps1     # Discovery stub
│   └── DiscoveryClasses.Tests.ps1            # Class property validation
│
└── modules/Devolutions.CIEM.Identities/Tests/  # Legacy identity tests
    ├── CIEMGraph.Tests.ps1
    └── ...
```

---

## Test Execution

### Run All Tests
```bash
pwsh -NoProfile -Command "Invoke-Pester psu-app/Tests/, psu-app/modules/Azure/Discovery/Tests/ -Output Detailed"
```

### Run Specific Test File
```bash
pwsh -NoProfile -Command "Invoke-Pester psu-app/modules/Azure/Discovery/Tests/CIEMAzureArmResource.Tests.ps1 -Output Detailed"
```

### Run Tests by Tag
```bash
pwsh -NoProfile -Command "Invoke-Pester psu-app/Tests/ -Tag 'CRUD' -Output Detailed"
```

### Run with Verbosity
```bash
pwsh -NoProfile -Command "Invoke-Pester psu-app/Tests/ -Output Diagnostic"
```

---

## Test Categories

Tests are independent but logically grouped:

| Category | Tests | DB Needed |
|----------|-------|-----------|
| **Structural** | ModuleLoad, Psm1Structure, PSUIntegration, InvokeAzureApi429, InvokeCIEMScanRefactor | No |
| **Schema** | SchemaCleanup, DiscoverySchema | Yes |
| **Classes** | DiscoveryClasses | No (InModuleScope) |
| **CRUD** | ArmResource, EntraResource, DiscoveryRun, ResourceType, ResourceRelationship | Yes |
| **Stubs** | StartCIEMAzureDiscovery | No |

---

## Troubleshooting Failed Tests

Follow these steps in order:

### 1. Check CIEM Boot Log
```bash
# The module logs errors during initialization
tail -50 psu-app/data/ciem.log
grep -i "error\|exception\|fail" psu-app/data/ciem.log
```

### 2. Run Test with Diagnostic Output
```bash
pwsh -NoProfile -Command "Invoke-Pester path/to/test.Tests.ps1 -Output Diagnostic"
```

### 3. Verify Database Schema
```powershell
# Check if tables exist in test DB
Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"

# Check table structure
Invoke-CIEMQuery -Query "PRAGMA table_info(azure_arm_resources)"
```

### 4. Check Module Exports
```powershell
# Verify function is exported
Get-Command -Module Devolutions.CIEM | Where-Object Name -eq 'New-CIEMAzureArmResource'

# List all exports
Get-Command -Module Devolutions.CIEM | Sort-Object Name
```

### 5. Fix Test Code
If the issue is in the test (2-3 attempts max), fix it. After 2 failed fixes, STOP and present options.

### 6. Flag Source Code Bugs
- Add comment describing the issue
- Create a tracking issue
- **NEVER skip the test to hide the failure**

---

## Test Removal Policy

**CRITICAL: NEVER remove or comment out tests without explicit user approval.**

### Mandatory Requirements

1. **User approval is REQUIRED** — ask before removing ANY test
2. **Prefer refactoring over removal** — if a test has structural issues, FIX it
3. **Document justification** — if removal is approved, document why

### When Tests Fail

1. **First**: Analyze and attempt to fix/refactor the test
2. **Second**: If unfixable, explain the issue and propose options
3. **Third**: Only remove after explicit user approval

### Anti-Patterns (NEVER DO)

- Removing tests because they fail due to test pollution
- Removing tests because they're "fundamentally flawed" without user approval
- Commenting out tests to make the test suite pass
- Assuming removal is acceptable based on analysis alone

---

## Common Gotchas

| Issue | Solution |
|-------|----------|
| `Import-Module -Force` breaks classes | Use `Remove-Module -Force` then `Import-Module` (no `-Force`) |
| `InModuleScope Devolutions.CIEM.Identities` fails | Use `InModuleScope Devolutions.CIEM` — sub-folders aren't real modules |
| Test DB missing tables | Apply all required schema files after `New-CIEMDatabase` |
| `$script:` variables not shared | Use `$script:` scope consistently across `run_before`/`assertion` |
| Class not found in tests | Use `InModuleScope` — classes are only visible inside module scope |
| Private function not found | Use `InModuleScope` with `Get-Command FunctionName` (no dash = private) |
| Data bleeds between Contexts | Use `BeforeEach` to reset DB state in write-operation Contexts |
| `Should -Not -Exist` vs `Test-Path` | Always use `Should -Not -Exist` for filesystem assertions |
