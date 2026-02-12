# Common Pitfalls in Python → PowerShell Conversion

Known gotchas, mistakes, and edge cases when converting Python code to PowerShell.

---

## 1. Boolean/Truthiness Differences

**Python `not value` catches multiple falsy values:**
- `None`, `False`, `0`, `""`, `[]`, `{}`

**PowerShell `-not $value` also catches multiple falsy values:**
- `$null`, `$false`, `0`, `""`, `@()`

**Pitfall:** Python `if not value:` and PowerShell `if (-not $value)` are similar but NOT identical:
- Python empty dict `{}` is falsy → PowerShell empty hashtable `@{}` is **truthy**
- Python empty list `[]` is falsy → PowerShell empty array `@()` is **falsy**

**Fix:** Be explicit about what you're checking:
```powershell
# Instead of: if (-not $value)
# Be specific: if ($null -eq $value)
#          or: if ($value.Count -eq 0)
```

---

## 2. Null Comparison Order

**Python:** `if x is None:` — order doesn't matter
**PowerShell:** `if ($null -eq $x)` — **$null MUST be on the left**

```powershell
# WRONG - behaves differently with arrays
if ($items -eq $null) { }  # Filters array, returns null elements!

# CORRECT
if ($null -eq $items) { }  # Checks if variable is null
```

---

## 3. String Comparison Case Sensitivity

**Python:** `==` is case-sensitive by default
**PowerShell:** `-eq` is case-**insensitive** by default

```python
# Python: case-sensitive
if status == "PASS":  # "pass" would NOT match
```

```powershell
# PowerShell: case-insensitive by default
if ($status -eq "PASS") { }  # "pass" WOULD match
# Use -ceq for case-sensitive
if ($status -ceq "PASS") { }
```

**When it matters:** Usually it doesn't for Prowler checks (status values are uppercase). But watch for resource names or string comparisons where case matters.

---

## 4. Property Access on Null

**Python:** `obj.prop` throws `AttributeError` if obj is None
**PowerShell:** `$null.prop` returns `$null` silently (unless strict mode)

**With `Set-StrictMode -Version Latest`:** Accessing a property on `$null` throws an error.

**Fix:** Always check for null before accessing properties:
```powershell
if ($null -ne $obj -and $obj.PSObject.Properties['prop']) {
    $obj.prop
}
```

---

## 5. Array vs Scalar Return Values

**Python:** Functions explicitly return lists
**PowerShell:** Functions that emit a single item return a scalar, not an array

```python
# Python: always returns a list
return [item]  # Returns list with one element
```

```powershell
# PowerShell: single output = scalar
function Get-Items {
    "one item"  # Returns string, not array
}

# Fix: wrap in @() at call site if you need array
$results = @(Get-Items)  # Always an array
```

**Pitfall in checks:** A check that finds only one resource returns a single result object, not an array. The caller must handle this with `@()` wrapping.

---

## 6. getattr() Default Value Semantics

**Python `getattr(obj, 'prop', default)`:**
- Returns `default` if property doesn't exist
- Returns the property value even if it's `None`

**Common mistake in PowerShell:**
```powershell
# WRONG: this also applies default when value is $null
$value = if ($obj.PSObject.Properties['prop']) { $obj.prop } else { $default }
# If obj.prop exists but is $null, this returns $null (correct!)

# But if you want to match Python's getattr exactly:
# getattr returns the value (even None) if attr exists, default only if attr missing
$value = if ($null -ne $obj.PSObject.Properties['prop']) {
    $obj.prop  # Could be $null - that's correct
} else {
    $default
}
```

---

## 7. for/else Pattern

**Python has `for...else`:**
```python
for item in items:
    if condition:
        break
else:
    # Runs only if loop completed without break
    print("not found")
```

**PowerShell has no `for...else`:**
```powershell
$found = $false
foreach ($item in $items) {
    if ($condition) {
        $found = $true
        break
    }
}
if (-not $found) {
    Write-Output "not found"
}
```

---

## 8. Dictionary Modification During Iteration

**Python:** Can't modify dict during iteration (raises RuntimeError)
**PowerShell:** Can't modify hashtable during enumeration either, but error message is different

**Fix for both:** Iterate over `.Keys` copied to array first:
```powershell
foreach ($key in @($dict.Keys)) {  # @() copies the key list
    $dict.Remove($key)  # Safe now
}
```

---

## 9. Implicit Output Pollution

**PowerShell functions return ALL uncaptured output**, not just explicit returns.

```powershell
# WRONG: This returns BOTH the List and the intended results
function Get-Results {
    $list = [System.Collections.Generic.List[string]]::new()  # Emits nothing (constructor returns void)
    $list.Add("item")     # .Add() returns void - OK
    $dict = @{}
    $dict.Add("key", 1)   # .Add() returns void - OK

    # But ArrayList.Add() returns the index!
    $al = [System.Collections.ArrayList]::new()
    $al.Add("item")       # Returns 0 - THIS POLLUTES OUTPUT!
}

# FIX: Capture or suppress unwanted output
$null = $al.Add("item")   # Suppress with $null =
[void]$al.Add("item")     # Or cast to [void]
$al.Add("item") | Out-Null  # Or pipe to Out-Null (slower)
```

**Common offenders:**
- `[ArrayList].Add()` → returns index (use `[List[T]].Add()` which returns void)
- `[HashSet[T]].Add()` → returns bool
- `[Dictionary[K,V]].Add()` → returns void (safe)
- `.Remove()` methods → often return bool

---

## 10. Async/Await → Synchronous

**Python Prowler services use async/await extensively.**
**PowerShell is synchronous by default.**

No conversion needed — just call APIs synchronously. PowerShell cmdlets like `Invoke-RestMethod` and `Invoke-AzRestMethod` are already synchronous.

If parallelism is needed, use `ForEach-Object -Parallel` (PowerShell 7+).

---

## 11. Pydantic Models → PSCustomObject

**Python Prowler uses Pydantic `BaseModel` for typed data:**
```python
class User(BaseModel):
    id: str
    name: str
    is_mfa_capable: bool
```

**PowerShell equivalent:** Just use the raw API response (PSCustomObject from `ConvertFrom-Json`) or create explicit PSCustomObjects:
```powershell
[PSCustomObject]@{
    Id           = $user.id
    Name         = $user.displayName
    IsMfaCapable = $user.isMfaCapable
}
```

Don't create PowerShell classes to mirror Pydantic models unless the project architecture requires it.

---

## 12. Snake_case → camelCase/PascalCase

**Python uses `snake_case` everywhere.** Converting to PowerShell requires attention to multiple conventions:

| Context | Python | PowerShell |
|---------|--------|-----------|
| Function names | `check_function_name` | `Test-CheckFunctionName` (PascalCase verb-noun) |
| Variables | `my_variable` | `$myVariable` (camelCase) or `$MyVariable` (PascalCase) |
| Parameters | `my_param` | `$MyParam` (PascalCase) |
| Properties | `is_enabled` | `.IsEnabled` (PascalCase) or `.isEnabled` (from JSON) |
| Constants | `MAX_COUNT` | `$MaxCount` (PascalCase) |

**Pitfall with API properties:** Azure API responses use `camelCase` (`enableRbacAuthorization`), not `snake_case` (`enable_rbac_authorization`). When converting Python property access, map to the actual API field name, not a PascalCase conversion of the Python name.
