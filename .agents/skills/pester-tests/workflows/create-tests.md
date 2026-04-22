# Create Tests Workflow

<required_reading>
- [references/test-definitions.md](../references/test-definitions.md) — Test structure, rules, Should operators
- [references/test-framework.md](../references/test-framework.md) — Module import, DB isolation, InModuleScope
</required_reading>

<process>

## Step 1: Identify What Needs Tests

| Code Change | Test Type | Test Location |
|-------------|-----------|---------------|
| New public function | Full parameter coverage | `[ModuleArea]/Tests/Unit/FunctionName.Tests.ps1` |
| New CRUD table | Full CRUD lifecycle | `[ModuleArea]/Tests/Unit/ClassName.Tests.ps1` |
| Bug fix | Reproduce-then-fix | Existing test file for that area |
| New private function | InModuleScope existence + params | Parent feature's test file |
| New class | Property validation | `DiscoveryClasses.Tests.ps1` or area equivalent |
| Refactor | Existing tests must still pass | No new file needed unless coverage gaps |

## Step 2: Read Source Code (MANDATORY)

Before writing any test, read the implementation:
1. Check parameter sets (`[CmdletBinding()]`, `[Parameter()]` attributes)
2. Check mandatory vs optional parameters
3. Check return types (`[OutputType()]`)
4. Check error paths (`throw`, `Write-Error`)
5. Check SQL queries for CRUD functions
6. Check pipeline support (`ValueFromPipeline`, `ValueFromPipelineByPropertyName`)

## Step 3: Check Existing Tests

Read tests in the same file/directory to avoid duplicating coverage. Each test must verify unique behavior.

## Step 4: Determine Test Sub-Type

Choose the correct pattern based on what is being tested:

### Source Assertion Tests (NO module import)
For tests that only read source files and check patterns:
```powershell
BeforeAll {
    $script:Source = Get-Content (Join-Path $PSScriptRoot '..path..' 'SomeFile.ps1') -Raw
}

Describe 'Source File Patterns' {
    It 'Contains expected pattern' {
        $script:Source | Should -Match 'expectedPattern'
    }
}
```

### Command/Class Structure Tests (import + mock)
For tests that validate exports, parameters, or class properties:
```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Function Structure' {
    It 'Exports Get-Something' {
        Get-Command -Module Devolutions.CIEM -Name 'Get-Something' | Should -Not -BeNullOrEmpty
    }
}
```

### CRUD Tests (import + $TestDrive DB + mock)
For tests that exercise database operations:
```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    # Apply provider-specific schemas
    $schema = Join-Path $PSScriptRoot '..path..' 'Data' 'schema_file.sql'
    Invoke-CIEMQuery -Query (Get-Content $schema -Raw)
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}
```

## Step 5: Write Test Following TDD

1. **Write the test FIRST** — describe expected behavior
2. **Run it** — confirm it FAILS (red phase)
3. **Implement the code** — make the test pass
4. **Run again** — confirm it PASSES (green phase)
5. **Run full suite** — confirm no regressions

## Step 6: CRUD Test Completeness Checklist

For every CRUD function set, verify these tests exist:

### New- (Create)
- [ ] Creates successfully with required parameters
- [ ] Returns correctly typed object
- [ ] Throws on duplicate (if UNIQUE constraint)
- [ ] Accepts -InputObject parameter set
- [ ] Mandatory parameters validated

### Get- (Read)
- [ ] Returns all records when no filter
- [ ] Returns correctly typed objects (`.GetType().Name`)
- [ ] Filters by each parameter (-Id, -Type, -Name, etc.)
- [ ] Returns empty array when no match

### Update- (Partial Update)
- [ ] Updates specified fields only (partial update)
- [ ] Does not overwrite unspecified fields
- [ ] Returns nothing without -PassThru
- [ ] Returns updated object with -PassThru
- [ ] Accepts -InputObject for full object update

### Save- (Upsert)
- [ ] Inserts new record (upsert)
- [ ] Updates existing record (upsert)
- [ ] Accepts -InputObject via pipeline

### Remove- (Delete)
- [ ] Removes by -Id
- [ ] Removes by scope-appropriate bulk param (e.g., -Type, -All)
- [ ] Removes via -InputObject
- [ ] No-ops when Id does not exist

### AUTOINCREMENT Tables (discovery_runs, resource_relationships)
- [ ] New- does NOT specify id in INSERT
- [ ] New- retrieves id via `last_insert_rowid()`
- [ ] Returned object has `Id > 0`
- [ ] Consecutive creates return incrementing Ids

## Step 7: Data Cleanup Between Contexts

Write-operation Contexts need `BeforeEach` cleanup:
```powershell
Context 'New-CIEMAzureArmResource' {
    BeforeEach {
        InModuleScope Devolutions.CIEM {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
        }
    }
    It 'Creates a resource' { ... }
}
```

Read-only Contexts can use `BeforeAll` for seeding.

## Step 8: Run and Verify

```bash
# Run the new test file
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path path/to/NewTest.Tests.ps1

# Run the full area suite
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Azure/Discovery/Tests/

# Run the full module suite
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit
```

</process>

<success_criteria>
- Source code read before writing any test
- Test sub-type correctly chosen (source-only, structure, or CRUD)
- CRUD completeness checklist satisfied
- All tests pass with 0 failures, 0 errors
- No regressions in existing tests
- Test names describe observable behavior
</success_criteria>
