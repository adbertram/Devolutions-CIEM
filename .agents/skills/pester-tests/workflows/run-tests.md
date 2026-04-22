# Run Tests Workflow

<process>

## Execution Commands

### Run All Unit Tests
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit
```

### Run Specific Area
```bash
# Discovery tests
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Azure/Discovery/Tests/Unit/

# Infrastructure tests
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Azure/Infrastructure/Tests/Unit/

# Module-level tests
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/Tests/Unit/
```

### Run Single Test File
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureArmResource.Tests.ps1
```

### Run by Tag
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Tag 'CRUD'
```

### Output Levels
| Level | Use When |
|-------|----------|
| `Detailed` | Standard development — shows pass/fail per test |
| `Diagnostic` | Debugging failures — maximum verbosity |
| `Normal` | CI/CD — summary only |

### E2E Tests (Require Running PSU)
```bash
# Pester E2E against local or Azure PSU
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite E2E -Environment local
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite E2E -Environment azure

# Playwright E2E
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Playwright -Environment local
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Playwright -Environment azure
```

## Interpreting Results

**Passing run**: 0 Failed, 0 Error. Any non-zero count = failure.

**ERROR is a failure**, not a skip. If tests ERROR instead of SKIP, that itself is a bug.

**Container failures** (file-level): Usually mean BeforeAll failed — check module import, DB setup, or missing schema application.

## Troubleshooting Failed Tests

Follow these steps in order:

### 1. Check CIEM Boot Log
```bash
tail -50 psu-app/data/ciem.log
grep -i "error\|exception\|fail" psu-app/data/ciem.log
```

### 2. Run with Diagnostic Output
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path path/to/test.Tests.ps1 -Output Diagnostic
```

### 3. Verify Database Schema
```bash
pwsh -NoProfile -Command "
    Import-Module ./psu-app/Devolutions.CIEM.psd1
    Invoke-CIEMQuery -Query \"SELECT name FROM sqlite_master WHERE type='table' ORDER BY name\"
"
```

### 4. Check Module Exports
```bash
pwsh -NoProfile -Command "
    Import-Module ./psu-app/Devolutions.CIEM.psd1
    Get-Command -Module Devolutions.CIEM | Sort-Object Name
"
```

### 5. Common Failure Causes

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Container failed" | BeforeAll threw | Check module import path, schema files |
| "Connection refused" | E2E test, PSU not running | Start local PSU or skip E2E |
| "Type not found" | Class not in scope | Use `InModuleScope Devolutions.CIEM` |
| "Table not found" | Missing schema application | Apply provider-specific `.sql` after `New-CIEMDatabase` |
| "Import-Module -Force broke classes" | `-Force` rebuilds class types | Use `Remove-Module -Force` then `Import-Module` (no `-Force`) |
| "Private function not found" | Not using InModuleScope | Wrap in `InModuleScope Devolutions.CIEM { ... }` |

### 6. Fix Protocol
- Fix the **implementation**, not the test (tests document expected behavior)
- After 2 failed fix attempts: STOP, present symptom/attempts/hypothesis, ask for direction
- **NEVER skip, comment out, or remove a failing test**

## Coverage Analysis

For detailed coverage analysis workflow, see [references/code-coverage.md](../references/code-coverage.md).

### Quick Coverage Check
```bash
# List all public functions
pwsh -NoProfile -Command "
    Import-Module ./psu-app/Devolutions.CIEM.psd1
    Get-Command -Module Devolutions.CIEM | Sort-Object Name | Format-Table Name, CommandType
"

# Count existing tests
pwsh -NoProfile -Command "
    (Get-ChildItem psu-app -Recurse -Filter '*.Tests.ps1' |
        ForEach-Object { (Get-Content \$_.FullName | Select-String 'It ''').Count } |
        Measure-Object -Sum).Sum
"

# List test files
find psu-app -name '*.Tests.ps1' -type f
```

### Per-Function Coverage
For each function, compare:
1. **Parameters** (from source) vs. **tests exercising each parameter**
2. **Error paths** (`throw`, `Write-Error`) vs. **tests triggering errors**
3. **Return types** vs. **assertion coverage on returned objects**

</process>

<success_criteria>
- All tests pass with 0 Failed, 0 Error
- Container failures investigated and resolved
- E2E failures identified as PSU-dependent (not counted as unit test failures)
- Coverage gaps documented with priority levels
</success_criteria>
