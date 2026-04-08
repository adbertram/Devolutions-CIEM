# Code Coverage Analysis

## Workflow Overview

```
Phase 1: Analysis    →  Phase 2: Planning    →  Phase 3: Review    →  Phase 4: Remediation
Coverage Reviewer       Plan Generator          Test Reviewer          Remediator
{area}-{group}.md       {area}-{group}-plan.md  validated/             Tests written
```

## Phase 1: Coverage Review

For each function under test:
1. **Read source code** — identify parameters, parameter sets, return types, error paths
2. **Read existing tests** — map which parameters and scenarios are covered
3. **Identify gaps** — uncovered parameters, missing error paths, untested combinations
4. **Generate report** — document gaps with priority levels

## Phase 2: Plan Generation

1. **Prioritize gaps** — P1 (critical), P2 (important), P3 (nice-to-have)
2. **Design test definitions** — one per gap, following test definition rules
3. **Estimate count** — total new tests needed

## Phase 3: Test Review

Validate new test definitions against framework rules:
1. Block purity — no assertions in setup, no creation in assertions
2. Naming convention — describes observable outcome
3. Database isolation — uses $TestDrive, proper cleanup
4. No duplicates — each test verifies unique behavior

## Phase 4: Remediation

1. Write test files following test definition structure
2. Run tests — verify pass (or fail as expected for TDD)
3. Document progress in REMEDIATION_PROGRESS.md

## Priority Levels

| Priority | Meaning | Criteria |
|----------|---------|----------|
| **P1** | Critical | Core CRUD operations, mandatory parameters, primary error conditions |
| **P2** | Important | Filter parameters, -PassThru, -InputObject pipeline, partial updates |
| **P3** | Nice-to-have | Edge cases, rare parameter combinations, advanced scenarios |

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

## Summary
| Function | Covered | Gaps | Total |
|----------|---------|------|-------|
| New-CIEMAzureArmResource | 3 | 2 | 5 |
```

## Implementation Plan Format

```markdown
# Implementation Plan: {Area} - {Group}

## P1 Tests (Critical)

### Test 1: New-CIEMAzureArmResource accepts InputObject
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
    }
}
```

## Quick Coverage Check

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
```

## Per-Function Coverage

For each function, compare:
1. **Parameters** (from source) vs. **tests exercising each parameter**
2. **Error paths** (`throw`, `Write-Error`) vs. **tests triggering errors**
3. **Return types** vs. **assertion coverage on returned objects**

## Directory Structure

```
code_coverage_reports/
├── {area}-{group}.md          # Coverage report
├── {area}-{group}-plan.md     # Implementation plan
└── validated/                 # Completed plans
```

## After Remediation

Move completed plans to `validated/`:
```bash
mv code_coverage_reports/{area}-{group}-plan.md code_coverage_reports/validated/
```