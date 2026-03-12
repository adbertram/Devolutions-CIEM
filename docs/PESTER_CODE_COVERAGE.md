# Code Coverage Analysis

**Purpose:** Identify untested parameters and missing test scenarios, then systematically implement the missing tests.

---

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Phase 1: Analysis          Phase 2: Planning         Phase 3: Review  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐            │
│  │ Coverage     │ ──▶ │ Plan         │ ──▶ │ Test         │            │
│  │ Reviewer     │     │ Generator    │     │ Reviewer     │            │
│  └──────────────┘     └──────────────┘     └──────────────┘            │
│        │                    │                    │                      │
│        ▼                    ▼                    ▼                      │
│  {area}-{group}.md   {area}-{group}-plan.md  validated/                │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  Phase 4: Remediation                                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐                                                       │
│  │ Remediator   │ ──▶ Implements tests from plans                      │
│  └──────────────┘                                                       │
│        │                                                                │
│        ▼                                                                │
│  REMEDIATION_PROGRESS.md                                                │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Analysis Process

### Phase 1: Coverage Review

For each function under test:

1. **Read source code** — identify all parameters, parameter sets, return types, error paths
2. **Read existing tests** — map which parameters and scenarios are already covered
3. **Identify gaps** — uncovered parameters, missing error paths, untested parameter combinations
4. **Generate report** — document gaps with priority levels

### Phase 2: Plan Generation

From the coverage report, create an implementation plan:

1. **Prioritize gaps** — P1 (critical), P2 (important), P3 (nice-to-have)
2. **Design test definitions** — one per gap, following test definition rules
3. **Estimate count** — total new tests needed

### Phase 3: Test Review

Validate new test definitions against framework rules:

1. **Block purity** — no assertions in run_before, no object creation in assertion
2. **Naming convention** — describes observable outcome, not structure
3. **Database isolation** — uses $TestDrive, proper cleanup
4. **No duplicates** — each test verifies unique behavior

### Phase 4: Remediation

Implement tests from validated plans:

1. **Write test files** — following the test definition structure
2. **Run tests** — verify they pass (or fail as expected for TDD)
3. **Document progress** — update REMEDIATION_PROGRESS.md

---

## Directory Structure

```
code_coverage_reports/
├── {area}-{group}.md          # Coverage report (analysis only)
├── {area}-{group}-plan.md     # Implementation plan (actionable)
└── validated/                 # Completed plans (moved after implementation)
```

---

## Priority Levels

| Priority | Meaning | Criteria |
|----------|---------|----------|
| **P1** | Critical | Core CRUD operations, mandatory parameters, primary error conditions |
| **P2** | Important | Filter parameters, -PassThru, -InputObject pipeline, partial updates |
| **P3** | Nice-to-have | Edge cases, rare parameter combinations, advanced scenarios |

---

## Coverage Report Format

```markdown
# Coverage Report: {Area} - {Group}

## Function: New-CIEMAzureArmResource

### Covered
- [x] Creates resource with required parameters
- [x] Returns typed object
- [x] Throws on duplicate Id

### Gaps
- [ ] P1: -InputObject parameter set not tested
- [ ] P2: CollectedAt defaults to current time when not provided
- [ ] P3: Pipeline input from Get- output

## Summary
| Function | Covered | Gaps | Total |
|----------|---------|------|-------|
| New-CIEMAzureArmResource | 3 | 3 | 6 |
```

---

## Implementation Plan Format

```markdown
# Implementation Plan: {Area} - {Group}

## P1 Tests (Critical)

### Test 1: New-CIEMAzureArmResource accepts InputObject
```powershell
@{
    name = 'Creates ARM resource via InputObject parameter set'
    tags = @('CRUD', 'ArmResource', 'P1')
    run_before = {
        InModuleScope Devolutions.CIEM {
            $obj = [CIEMAzureArmResource]::new()
            $obj.Id = "/subscriptions/$(New-Guid)/..."
            $obj.Type = 'Microsoft.Compute/virtualMachines'
            $script:result = New-CIEMAzureArmResource -InputObject $obj
        }
    }
    assertion = {
        $script:result | Should -Not -BeNullOrEmpty
        $script:result.Id | Should -Be $obj.Id
    }
}
```

## P2 Tests (Important)
...
```

---

## Running Coverage Analysis

### Manual Analysis

```bash
# List all public functions
pwsh -NoProfile -Command "
    Import-Module ./psu-app/Devolutions.CIEM.psd1
    Get-Command -Module Devolutions.CIEM | Sort-Object Name | Format-Table Name, CommandType
"

# Count existing tests
pwsh -NoProfile -Command "
    (Get-ChildItem psu-app -Recurse -Filter '*.Tests.ps1' |
        ForEach-Object { (Get-Content $_.FullName | Select-String 'It ''').Count } |
        Measure-Object -Sum).Sum
"
```

### Per-Function Analysis

For each function, compare:
1. **Parameters** (from `Get-Help` or source) vs. **tests that exercise each parameter**
2. **Error paths** (from source: `throw`, `Write-Error`) vs. **tests that trigger errors**
3. **Return types** vs. **assertion coverage on returned objects**

---

## Tracking Progress

### Finding Unaddressed Plans

```bash
# Count unaddressed plans
find code_coverage_reports -name "*-plan.md" -not -path "*/validated/*" | wc -l

# List all unaddressed plans
find code_coverage_reports -name "*-plan.md" -not -path "*/validated/*"
```

### After Remediation

When a plan is fully implemented and tests pass, move it to `validated/`:

```bash
mv code_coverage_reports/{area}-{group}-plan.md code_coverage_reports/validated/
```

---

## Typical Workflow

1. **Identify target area** — pick a module area (e.g., Azure/Discovery CRUD)
2. **Run analysis** — read source, read tests, identify gaps
3. **Generate plan** — prioritize gaps, design test definitions
4. **Review** — validate against test framework rules
5. **Implement** — write test files, run them
6. **Verify** — all tests pass (or fail as expected for TDD)
7. **Move plan** — to `validated/` when complete
