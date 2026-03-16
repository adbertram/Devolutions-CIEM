# Review Tests Workflow

<required_reading>
- [references/test-definitions.md](../references/test-definitions.md) — All test rules and anti-patterns
- [references/test-framework.md](../references/test-framework.md) — Framework conventions
</required_reading>

<process>

## Scope Limitation

**Review ONLY the files explicitly provided.** Do NOT expand scope to include other files in the same directory or related test files not listed.

## Review Checklist

### Step 0: Unit vs E2E Classification
- Verify test is in correct directory (`Tests/Unit/` or `Tests/E2E/`)
- If Unit: verify no real filesystem access, no network calls, no PSU dependency
- Determine sub-type: source assertion (no import), structure (import + mock), or CRUD (import + $TestDrive + mock)

### Step 1: Module Import & Isolation
- [ ] Source-only tests: NO `Import-Module` (Rule 16)
- [ ] Other tests: `Remove-Module -Force` then `Import-Module` (no `-Force`)
- [ ] Other tests: `Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}` (Rule 17)
- [ ] `InModuleScope` uses `Devolutions.CIEM` only (Rule 1)
- [ ] CRUD tests: `$TestDrive` DB isolation (Rule 2)
- [ ] No `if (Test-Path)` guards around schema applications

### Step 2: Assertion Quality
- [ ] Assertions ONLY inside `It` blocks (Rule 3)
- [ ] No conditional logic in assertions (Rule 4)
- [ ] Native Should operators used (Rule 5)
- [ ] Test names describe observable behavior (Rule 6)
- [ ] No `-ErrorAction SilentlyContinue` in `It` blocks (Rule 11)

### Step 3: CRUD Completeness (for CRUD test files)
- [ ] All 5 operations tested: New, Get, Update, Save, Remove (Rule 7)
- [ ] Both ByProperties and InputObject parameter sets tested (Rule 15)
- [ ] AUTOINCREMENT handled correctly for applicable tables
- [ ] -PassThru behavior verified on Update
- [ ] Pipeline input tested on Save
- [ ] Empty-result test for Get

### Step 4: Data Isolation
- [ ] No data bleed between tests
- [ ] `BeforeEach` cleanup for write-operation Contexts
- [ ] No reads/writes to dev database (Rule 8)

### Step 5: Structural Tests
- [ ] File-content tests use `Get-Content -Raw` and `Should -Match` (Rule 10)
- [ ] Function existence uses `Get-Command -Module` (Rule 10)
- [ ] Filesystem tests use `Should -Exist` / `Should -Not -Exist` (Rule 12)

## Critical Violations (REJECT)

These require REJECTED verdict:
- Wrong InModuleScope target (sub-folder name instead of `Devolutions.CIEM`)
- No $TestDrive isolation for CRUD tests
- Block purity violation (assertions in setup, object creation in assertions)
- Conditional logic in assertions
- PowerShell operators with `Should -Be $true/$false` instead of native Should
- `-ErrorAction SilentlyContinue` in `It` blocks
- `Import-Module -Force` used
- Missing schema application for CRUD tests
- Unnecessary `Import-Module` in source-only tests
- Missing `Mock Write-CIEMLog` in unit tests that import
- Real environment file access in unit tests
- Conditional `if (Test-Path)` guards silently skipping schema

## Non-Blocking Observations (can still APPROVE)

- Minor style inconsistencies
- Additional coverage suggestions
- Test name improvements
- Missing -PassThru or InputObject tests
- Missing data cleanup between Contexts

## Verdict Format

Every review MUST end with one of these verdicts:

### If tests pass review:
```
VERDICT: APPROVED
```

### If tests have blocking issues:
```
VERDICT: REJECTED

BLOCKING ISSUES:
1. [File:Line] Issue description
   FIX: Specific remediation steps

2. [File:Line] Issue description
   FIX: Specific remediation steps
```

</process>

<success_criteria>
- All rules checked systematically
- Critical violations identified and flagged
- Clear APPROVED or REJECTED verdict with actionable fix instructions
- Scope limited to provided files only
</success_criteria>
