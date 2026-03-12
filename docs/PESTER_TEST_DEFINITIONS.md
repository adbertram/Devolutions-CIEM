# Test Definitions - Pester Tests

**Purpose**: Test definition structure, rules, and patterns for Pester tests in this project.

---

## Test Definition Structure

Each test is a hashtable with this structure:

```powershell
@{
    name = "Descriptive test name (action + expected outcome)"
    tags = @("CRUD", "Schema", "Integration")  # Optional — for filtering/grouping
    run_before = {
        # Setup logic ONLY
        # Use $script: variables for cross-block sharing
        # Use New-Guid for unique values
        # ONLY create/configure test data here
    }
    assertion = {
        # ONLY Should assertions allowed
        # EXCEPTION: { Cmdlet } | Should -Throw for exception testing
        # NO object creation
        # NO conditional logic (no if/then)
        # NO Should assertions in setup blocks
    }
    # run_after is OPTIONAL - only for non-framework cleanup
    # $TestDrive files auto-cleaned by Pester
    run_after = {
        # Only needed for: files outside $TestDrive, system state changes, external resources
    }
}
```

---

## Critical Test Rules

### Source Code First (MUST)
1. **Source code is the single source of truth** — read the function implementation before writing tests
2. **Verify parameter sets** — check the function for mandatory/optional params, parameter sets, and pipeline support

### Test Focus (MUST)
3. **One focused assertion per test** — test single, specific behavior
4. **Write behavioral tests** — every test must answer: **"What capability does this prove works?"**
   - Good: Test what the function DOES (creates, retrieves, updates, removes, filters)
   - Bad: Test that something EXISTS (property, type, structure)

### Variable Usage (MUST)
5. **Use script-scoped variables ONLY when needed** for cross-block sharing
6. **Don't create unnecessary variables** — reference object properties directly

### Block Purity (MUST)
7. **No Should assertions in run_before or run_after blocks**
8. **No if/then logic in assertion blocks**
9. **Don't assert prerequisites** — only test the primary behavior

### Test Integrity (MUST)
10. **Never skip tests** — failing tests indicate bugs that need fixing
11. **Never modify tests to make them pass** — fix source code instead
12. **Avoid duplicate test functionality** — each test should verify unique behavior

### Failing Tests Are Signals, Not Problems to Silence

**ABSOLUTE RULE: "Skip the test" is NEVER a valid solution when troubleshooting test failures.**

Failing tests are **valuable signals** telling you something is wrong. The correct response is to fix the underlying issue, not silence the signal.

**When a test fails, the ONLY valid responses are:**

| Failure Type | Valid Response |
|--------------|----------------|
| Test code bug | Fix the test code |
| Missing prerequisite | Configure using existing functions/cmdlets |
| Source code bug | Create issue, document in test with `issue_reference` |
| Function not supported in context | Update test tags/conditions to match actual support |

### Block Purity Details

**NEVER do these to "fix" environment issues:**
- Write ad-hoc setup scripts that bypass the function layer
- Directly manipulate internal module variables (except `$script:DatabasePath` for test DB isolation)
- Create workarounds that hide real functionality gaps

**NEVER propose these as solutions:**
- "Skip the test when X is unavailable"
- "Mark test as skipped because environment lacks Y"
- "Use Set-ItResult -Skipped in run_before"
- "Comment out the test temporarily"

**If a test requires a prerequisite that doesn't exist:**
- The test is CORRECT to fail
- The prerequisite is MISSING — fix it
- Fix the environment, don't skip the test

### No Error Silencing (CRITICAL)
13. **NEVER use `-ErrorAction SilentlyContinue` in run_before** — all errors must be visible
14. **NEVER swallow errors in catch blocks**
15. **Use `-ErrorAction Stop`** or let errors surface
16. **Exception**: `-ErrorAction SilentlyContinue` is acceptable ONLY in `run_after` cleanup blocks

---

## Test Naming Convention

Test names must describe observable outcomes. Apply **"The Naming Test"**: Can you answer "what happens?" from the name?

| Quality | Example | Why |
|---------|---------|-----|
| Good | "Creates a resource and returns object with generated Id" | Describes what happens |
| Good | "Returns empty array when no resources match filter" | Observable outcome |
| Good | "Throws when resource with same Id already exists" | Error behavior |
| Bad | "Has Id, Type, Name properties" | Structure, not behavior |
| Bad | "Function exists and is exported" | Existence isn't behavior |
| Bad | "Runs without error" | No observable behavior |

---

## Database Isolation Pattern

CRUD tests need a real SQLite database but must not pollute the dev database. Use `$TestDrive` isolation:

```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    # Apply additional schema files as needed
    $schema = Join-Path $PSScriptRoot '..path..' 'Data' 'schema_file.sql'
    Invoke-CIEMQuery -Query (Get-Content $schema -Raw)
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}
```

**Important:** Never use `Import-Module -Force` — it breaks PowerShell classes. Use `Remove-Module -Force` first (safe — only unloads), then `Import-Module` without `-Force`.

---

## Data Cleanup Between Contexts

Each `Context` block must seed its own data and clean up to prevent cross-contamination:

```powershell
Context 'Get-CIEMAzureArmResource' {
    BeforeEach {
        InModuleScope Devolutions.CIEM {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
            # Insert test fixtures...
        }
    }
}
```

Write-operation Contexts (New/Save/Remove) should use `BeforeEach` to reset state before each `It` block. Read-only Contexts can use `BeforeAll`.

---

## Common Should Operators

### Equality
- `Should -Be` — Case-insensitive equality
- `Should -BeExactly` — Case-sensitive equality

### Null Checks
- `Should -BeNullOrEmpty`
- `Should -Not -BeNullOrEmpty`

### Numeric
- `Should -BeGreaterThan`
- `Should -BeLessThan`
- `Should -BeGreaterOrEqual`
- `Should -BeLessOrEqual`

### String Matching
- `Should -Match` — Regex matching
- `Should -BeLike` — Wildcard matching

### Collections
- `Should -Contain` — Collection contains item
- `Should -BeIn` — Item is in collection
- `Should -HaveCount` — Collection has specific count

### Filesystem
- `Should -Exist` — Path exists
- `Should -Not -Exist` — Path does not exist (use for deletion verification)

### Exceptions
- `{ SomeCmd } | Should -Throw` — Command throws
- `{ SomeCmd } | Should -Throw "message"` — Throws with specific message

### Negation
Add `-Not` between Should and operator:
```powershell
$value | Should -Not -BeNullOrEmpty
$list | Should -Not -Contain "item"
```

---

## Complete Example

```powershell
@{
    name = 'Creates ARM resource and returns object with all properties populated'
    tags = @('CRUD', 'ArmResource')
    run_before = {
        $script:resourceId = "/subscriptions/$(New-Guid)/resourceGroups/test-rg/providers/Microsoft.Compute/virtualMachines/test-vm"
        InModuleScope Devolutions.CIEM {
            $script:result = New-CIEMAzureArmResource -Id $using:resourceId -Type 'Microsoft.Compute/virtualMachines' -Name 'test-vm' -Location 'eastus' -SubscriptionId (New-Guid).ToString()
        }
    }
    assertion = {
        $script:result | Should -Not -BeNullOrEmpty
        $script:result.Id | Should -Be $script:resourceId
        $script:result.Type | Should -Be 'Microsoft.Compute/virtualMachines'
        $script:result.Name | Should -Be 'test-vm'
        $script:result.CollectedAt | Should -Not -BeNullOrEmpty
    }
}
```

---

## Anti-Patterns to Avoid

### Object Creation in Assertions
```powershell
# WRONG
assertion = {
    $resource = New-CIEMAzureArmResource -Id 'test' ...  # Should be in run_before
    $resource | Should -Not -BeNullOrEmpty
}
```

### Conditional Logic in Assertions
```powershell
# WRONG
assertion = {
    if ($script:result.Type -eq 'User') {  # No if/then logic
        $script:result.DisplayName | Should -Not -BeNullOrEmpty
    }
}
```

### Testing Implementation Details (REMOVE THESE)
```powershell
# WRONG - Tests property existence, not behavior
@{
    name = 'CIEMAzureArmResource has Id property'
    assertion = {
        $script:obj.PSObject.Properties.Name | Should -Contain 'Id'
    }
}

# RIGHT - Tests the capability
@{
    name = 'Creates ARM resource with specified Id'
    run_before = {
        $script:result = New-CIEMAzureArmResource -Id '/sub/123/...' ...
    }
    assertion = {
        $script:result.Id | Should -Be '/sub/123/...'
    }
}
```

### Error Silencing
```powershell
# WRONG
run_before = {
    $script:result = Get-CIEMAzureArmResource -Id "test" -ErrorAction SilentlyContinue
}

# CORRECT
run_before = {
    $script:result = Get-CIEMAzureArmResource -Id "test" -ErrorAction Stop
}
```

### Duplicate Test Functionality
```powershell
# If "Creates ARM resource" exists, don't add:
@{ name = "New ARM resource is created successfully" ... }  # Duplicate
```

---

## Directory Organization

Tests organized by module area:

| Directory | Tests For |
|-----------|-----------|
| `psu-app/Tests/` | Module-level tests (load, structure, schema) |
| `psu-app/modules/Azure/Discovery/Tests/` | Discovery CRUD and schema tests |
| `psu-app/modules/Azure/Infrastructure/Tests/` | Infrastructure CRUD tests |
| `psu-app/modules/Devolutions.CIEM.Checks/Tests/` | Check execution tests |

---

## Test Development Workflow

### 1. Identify Target and Scenario
- Define the function(s) to test
- Pinpoint a **single, specific use case**

### 2. Source Code Analysis (CRITICAL)
- Read the function implementation
- Identify: parameters, return types, internal logic, error handling, SQL queries

### 3. Check Existing Tests
- Review tests in the same file/group
- Don't duplicate functionality
- Focus on distinct use cases

### 4. Design Test Definition
- Structure based on source analysis
- Follow test definition format
- Use clear, specific test name

### 5. Verify Test
```bash
pwsh -NoProfile -Command "Invoke-Pester path/to/Tests/ -Output Detailed"
```
