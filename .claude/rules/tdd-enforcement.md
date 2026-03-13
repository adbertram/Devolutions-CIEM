---
description: TDD enforcement for all PowerShell and UI code changes
paths: ["psu-app/**", "e2e/**"]
---

# TDD Enforcement

**YOU MUST write or update tests for every code change.** This is non-negotiable.

## Before Writing Code

1. Identify the test file(s) that cover the changed functionality
2. Write the test(s) that describe the expected behavior
3. Run the test(s) and confirm they FAIL (red phase)
4. Only THEN implement the code change
5. Run all tests and confirm they PASS (green phase)

## Pester Test Requirements (psu-app/)

### New Public Function
- Test file: `[ModuleArea]/Tests/FunctionName.Tests.ps1`
- Must cover: command exists, parameter validation, return types, happy path, error cases

### New CRUD Table
- Test file: `[ModuleArea]/Tests/ClassName.Tests.ps1`
- Must cover: New (create + duplicate), Get (all + each filter), Update (partial + PassThru), Save (insert + upsert), Remove (each parameter set + no-op)

### New Private Function
- Test via `InModuleScope Devolutions.CIEM { ... }` in the parent feature's test file
- Must verify: function exists, accepts expected parameters

### New Class
- Test in `DiscoveryClasses.Tests.ps1` or equivalent area file
- Must verify: all properties store and retrieve correctly

### Run Commands
```powershell
# Single test file
Invoke-Pester psu-app/modules/Azure/Discovery/Tests/MyTest.Tests.ps1 -Output Detailed

# Full module test suite
Invoke-Pester psu-app/ -Output Detailed

# Specific area
Invoke-Pester psu-app/modules/Azure/Discovery/Tests/ -Output Detailed
```

## Playwright Test Requirements (e2e/)

### New UI Page
- Test file: `e2e/pages/PageName/PageName.test.js`
- Helper class: `e2e/pages/PageName/PageHelpers.js` extending `BasePage`
- Must cover: page loads, key elements visible, primary user interactions

### UI Behavior Change
- Update the existing test file for that page
- Add test case covering the changed behavior

### Run Commands
```bash
# All E2E tests
cd e2e && npx playwright test

# Single page
cd e2e && npx playwright test pages/Scan/

# With UI (debug)
cd e2e && npx playwright test --headed
```

## Commit Gate

**Before committing any code change, verify:**
1. `Invoke-Pester` shows 0 failures, 0 errors for affected test files
2. If UI was changed: `npx playwright test` passes for affected page tests
3. New test count >= number of new/changed functions
