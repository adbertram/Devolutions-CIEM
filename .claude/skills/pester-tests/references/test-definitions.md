# Test Definitions

## Test Definition Structure

```powershell
@{
    name = "Descriptive test name (action + expected outcome)"
    tags = @("CRUD", "Schema")  # Optional
    run_before = {
        # Setup ONLY — use $script: for cross-block sharing
        # Use New-Guid for unique values
        # NO Should assertions here
    }
    assertion = {
        # ONLY Should assertions
        # Exception: { Cmdlet } | Should -Throw
        # NO object creation, NO conditional logic
    }
    run_after = {  # OPTIONAL — only for non-framework cleanup
        # $TestDrive auto-cleaned by Pester
    }
}
```

## Critical Rules

### Source Code First
1. Read the function implementation before writing tests
2. Verify parameter sets, mandatory/optional params, pipeline support

### Test Focus
3. One focused assertion per test — test single, specific behavior
4. Write behavioral tests — "What capability does this prove works?"

### Variable Usage
5. Use `$script:` scope ONLY for cross-block sharing
6. Reference object properties directly when possible

### Block Purity
7. No `Should` assertions in `run_before` or `run_after`
8. No `if/then` logic in assertion blocks
9. Don't assert prerequisites — only test primary behavior

### Test Integrity
10. Never skip tests — failing tests indicate bugs
11. Never modify tests to make them pass — fix source code
12. Avoid duplicate test functionality

### No Error Silencing
13. NEVER `-ErrorAction SilentlyContinue` in `run_before`
14. NEVER swallow errors in catch blocks
15. Use `-ErrorAction Stop` or let errors surface
16. Exception: `-ErrorAction SilentlyContinue` acceptable ONLY in `run_after` cleanup

### Module Import
17. Source-only tests (Get-Content + Should -Match) MUST NOT import the module
18. Tests that import the module SHOULD mock `Write-CIEMLog`

## Test Naming Convention

Apply "The Naming Test": Can you answer "what happens?" from the name?

| Quality | Example |
|---------|---------|
| Good | "Creates a resource and returns object with generated Id" |
| Good | "Returns empty array when no resources match filter" |
| Good | "Throws when resource with same Id already exists" |
| Bad | "Has Id, Type, Name properties" |
| Bad | "Function exists and is exported" |
| Bad | "Runs without error" |

## Should Operator Reference

### Use Native Operators (NOT PowerShell + Should -Be $true)

| Instead of | Use |
|------------|-----|
| `(Test-Path $p) \| Should -Be $true` | `$p \| Should -Exist` |
| `$a -contains $b \| Should -Be $true` | `$a \| Should -Contain $b` |
| `$s -match 'x' \| Should -Be $true` | `$s \| Should -Match 'x'` |
| `$s -like 'x*' \| Should -Be $true` | `$s \| Should -BeLike 'x*'` |
| `$o -is [Type] \| Should -Be $true` | `$o \| Should -BeOfType [Type]` |
| `$a.Count \| Should -Be $n` | `$a \| Should -HaveCount $n` |
| `$v \| Should -Be $null` | `$v \| Should -BeNullOrEmpty` |
| `$v \| Should -Be $true` (boolean) | `$v \| Should -BeTrue` |
| `$v \| Should -Be $false` (boolean) | `$v \| Should -BeFalse` |
| `$a -gt $b \| Should -Be $true` | `$a \| Should -BeGreaterThan $b` |
| `$a -ge $b \| Should -Be $true` | `$a \| Should -BeGreaterOrEqual $b` |
| `$a -lt $b \| Should -Be $true` | `$a \| Should -BeLessThan $b` |
| `$a -le $b \| Should -Be $true` | `$a \| Should -BeLessOrEqual $b` |
| `$b -in $arr \| Should -Be $true` | `$b \| Should -BeIn $arr` |

### All Operators Quick Reference
- **Equality:** `Should -Be` (case-insensitive), `Should -BeExactly` (case-sensitive)
- **Null:** `Should -BeNullOrEmpty`, `Should -Not -BeNullOrEmpty`
- **Numeric:** `Should -BeGreaterThan`, `-BeLessThan`, `-BeGreaterOrEqual`, `-BeLessOrEqual`
- **String:** `Should -Match` (regex), `Should -BeLike` (wildcard)
- **Collections:** `Should -Contain`, `Should -BeIn`, `Should -HaveCount`
- **Filesystem:** `Should -Exist`, `Should -Not -Exist`
- **Exceptions:** `{ Cmd } | Should -Throw`, `{ Cmd } | Should -Throw "message"`
- **Negation:** Add `-Not`: `Should -Not -BeNullOrEmpty`

## Anti-Patterns

### Object Creation in Assertions
```powershell
# WRONG — setup in assertion block
assertion = {
    $resource = New-CIEMAzureArmResource -Id 'test' ...
    $resource | Should -Not -BeNullOrEmpty
}
# RIGHT — setup in run_before
run_before = { $script:resource = New-CIEMAzureArmResource ... }
assertion = { $script:resource | Should -Not -BeNullOrEmpty }
```

### Conditional Logic in Assertions
```powershell
# WRONG
assertion = {
    if ($script:result.Type -eq 'User') {
        $script:result.DisplayName | Should -Not -BeNullOrEmpty
    }
}
# RIGHT — split into separate tests
```

### Error Silencing
```powershell
# WRONG
run_before = { $script:result = Get-X -ErrorAction SilentlyContinue }
# RIGHT
run_before = { $script:result = Get-X -ErrorAction Stop }
```

### Testing Structure Instead of Behavior
```powershell
# WRONG
@{ name = 'CIEMAzureArmResource has Id property' }
# RIGHT
@{ name = 'Creates ARM resource with specified Id' }
```

## Data Cleanup Between Contexts

Write-operation Contexts need `BeforeEach` cleanup:
```powershell
Context 'New-CIEMAzureArmResource' {
    BeforeEach {
        InModuleScope Devolutions.CIEM {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
        }
    }
}
```
Read-only Contexts can use `BeforeAll` for seeding.

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
        $script:result.CollectedAt | Should -Not -BeNullOrEmpty
    }
}
```
