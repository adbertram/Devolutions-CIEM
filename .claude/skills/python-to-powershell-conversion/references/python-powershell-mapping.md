# Python → PowerShell Mapping Reference

Comprehensive translation table for converting Python patterns to idiomatic PowerShell.

## Table of Contents
- [String Operations](#string-operations)
- [Collections](#collections)
- [Control Flow Gotchas](#control-flow-gotchas)
- [Functions](#functions)
- [Classes → Functions](#classes--functions)
- [Error Handling](#error-handling)
- [Property Access](#property-access)
- [Iteration Patterns](#iteration-patterns)
- [Comprehensions and Generators](#comprehensions-and-generators)
- [Common Standard Library](#common-standard-library)
- [SDK Patterns](#sdk-patterns)

---

## String Operations

| Python | PowerShell | Notes |
|--------|-----------|-------|
| `f"Hello {name}"` | `"Hello $name"` or `"Hello {0}" -f $name` | Use `-f` for complex formatting |
| `f"Count: {len(items)}"` | `"Count: $($items.Count)"` | Subexpression for method calls |
| `"text".upper()` | `"text".ToUpper()` | .NET methods |
| `"text".lower()` | `"text".ToLower()` | |
| `"text".startswith("t")` | `"text".StartsWith("t")` or `"text" -like "t*"` | |
| `"text".endswith("t")` | `"text".EndsWith("t")` or `"text" -like "*t"` | |
| `"text".replace("a", "b")` | `"text".Replace("a", "b")` or `"text" -replace "a", "b"` | `-replace` uses regex |
| `"a,b,c".split(",")` | `"a,b,c".Split(",")` or `"a,b,c" -split ","` | `-split` uses regex |
| `",".join(list)` | `$list -join ","` | |
| `"text".strip()` | `"text".Trim()` | |
| `"text" in other_string` | `$otherString -match "text"` or `$otherString.Contains("text")` | `-match` is regex |
| `re.match(pattern, text)` | `$text -match $pattern` | Result in `$Matches` |

## Collections

### Lists / Arrays

| Python | PowerShell |
|--------|-----------|
| `items = []` | `$items = @()` or `$items = [System.Collections.Generic.List[object]]::new()` |
| `items.append(x)` | `$items += $x` (array) or `$items.Add($x)` (List) |
| `items.extend(other)` | `$items += $other` or `$items.AddRange($other)` |
| `len(items)` | `$items.Count` or `@($items).Count` (null-safe) |
| `items[0]` | `$items[0]` |
| `items[-1]` | `$items[-1]` |
| `items[1:3]` | `$items[1..2]` |
| `x in items` | `$x -in $items` or `$items -contains $x` |
| `x not in items` | `$x -notin $items` or `$items -notcontains $x` |
| `sorted(items)` | `$items \| Sort-Object` |
| `sorted(items, key=lambda x: x.name)` | `$items \| Sort-Object -Property Name` |
| `items.reverse()` | `[array]::Reverse($items)` |

### Dictionaries / Hashtables

| Python | PowerShell |
|--------|-----------|
| `d = {}` | `$d = @{}` |
| `d = {'key': 'value'}` | `$d = @{ key = 'value' }` |
| `d['key']` | `$d['key']` or `$d.key` |
| `d.get('key', default)` | `if ($d.ContainsKey('key')) { $d['key'] } else { $default }` |
| `d.keys()` | `$d.Keys` |
| `d.values()` | `$d.Values` |
| `d.items()` | `$d.GetEnumerator()` |
| `'key' in d` | `$d.ContainsKey('key')` |
| `d.update(other)` | `foreach ($kv in $other.GetEnumerator()) { $d[$kv.Key] = $kv.Value }` |
| `del d['key']` | `$d.Remove('key')` |

## Control Flow Gotchas

**Critical difference - null comparison order:**
```powershell
# Python: if x is None    → works either way
# PowerShell: ALWAYS put $null on the LEFT
if ($null -eq $x) { }     # Correct
if ($x -eq $null) { }     # Works but bad practice (arrays behave differently)
```

## Functions

| Python | PowerShell |
|--------|-----------|
| `def func(arg):` | `function Func { param($arg)` |
| `def func(arg='default'):` | `function Func { param($arg = 'default')` |
| `def func(*args):` | `function Func { param([Parameter(ValueFromRemainingArguments)]$args)` |
| `def func(**kwargs):` | Use `[hashtable]$Params` or splatting |
| `return value` | `return $value` or just `$value` (implicit output) |
| `@decorator` | No direct equivalent; use wrapper functions |

**PowerShell implicit output:** Every non-captured expression in a function is returned. This is the idiomatic way to accumulate results (no explicit `return` needed for each item).

```python
# Python: accumulate into list, return list
findings = []
for item in items:
    findings.append(result)
return findings
```

```powershell
# PowerShell: just emit objects (implicit output collection)
foreach ($item in $items) {
    $result  # This is returned automatically
}
```

## Classes → Functions

Prowler checks are Python classes; PowerShell equivalents are advanced functions.

```python
# Python Prowler check
class check_name(Check):
    def execute(self) -> Check_Report_Azure:
        findings = []
        # ... logic ...
        findings.append(report)
        return findings
```

```powershell
# PowerShell equivalent
function Test-CheckName {
    [CmdletBinding()]
    [OutputType([ResultType[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # ... logic ...
    # Emit results directly (implicit output)
    [ResultType]::Create($Check, 'PASS', 'message', 'id', 'name')
}
```

## Error Handling

| Python | PowerShell |
|--------|-----------|
| `try: ... except Exception as e:` | `try { ... } catch { $_ }` |
| `try: ... except SpecificError:` | `try { ... } catch [SpecificException] { }` |
| `try: ... finally:` | `try { ... } finally { }` |
| `raise ValueError("msg")` | `throw "msg"` or `throw [System.ArgumentException]::new("msg")` |
| `except Exception as e: logger.error(e)` | `catch { Write-Error $_ }` or `catch { Write-Warning $_ }` |

**`$ErrorActionPreference = 'Stop'`** — Set this at the top of every function to make non-terminating errors into terminating errors (equivalent to Python's default behavior where exceptions propagate).

## Property Access

### Safe attribute access (critical for strict mode)

| Python | PowerShell |
|--------|-----------|
| `getattr(obj, 'prop', default)` | See pattern below |
| `obj.prop` (known to exist) | `$obj.prop` |
| `hasattr(obj, 'prop')` | `$null -ne $obj.PSObject.Properties['prop']` |

**Strict-mode-safe getattr equivalent:**
```powershell
# Python: getattr(obj, 'prop', default)
# PowerShell:
$value = if ($obj.PSObject.Properties['prop']) {
    $obj.prop
} else {
    $default
}
```

**Nested property navigation:**
```powershell
# Python: obj.properties.enable_rbac if obj.properties else None
# PowerShell (strict-mode-safe):
$value = $obj
foreach ($segment in 'properties', 'enableRbacAuthorization') {
    if ($null -eq $value) { break }
    if ($value.PSObject.Properties[$segment]) {
        $value = $value.$segment
    } else {
        $value = $null
        break
    }
}
```

## Iteration Patterns

### Dictionary iteration (most common in Prowler)

```python
# Python: iterate dict of tenant → resource
for tenant, security_default in client.security_default.items():
    report = Check_Report_Azure(metadata=self.metadata(), resource=security_default)
```

```powershell
# PowerShell: iterate hashtable keys
foreach ($tenant in $service.SecurityDefault.Keys) {
    $securityDefault = $service.SecurityDefault[$tenant]
    # create result
}
```

### Nested iteration (subscription → resources)

```python
# Python
for subscription, storage_accounts in storage_client.storage_accounts.items():
    for storage_account in storage_accounts:
        # check each account
```

```powershell
# PowerShell
foreach ($subscriptionId in $storageService.Keys) {
    $data = $storageService[$subscriptionId]
    foreach ($account in $data.StorageAccounts) {
        # check each account
    }
}
```

## Comprehensions and Generators

| Python | PowerShell |
|--------|-----------|
| `[x.name for x in items]` | `$items \| ForEach-Object { $_.name }` or `$items.name` (member enumeration) |
| `[x for x in items if x.active]` | `$items \| Where-Object { $_.active }` |
| `any(cond for x in list)` | `$null -ne ($list \| Where-Object { $cond } \| Select-Object -First 1)` |
| `all(cond for x in list)` | `$null -eq ($list \| Where-Object { -not $cond } \| Select-Object -First 1)` |
| `sum(x.value for x in items)` | `($items \| Measure-Object -Property value -Sum).Sum` |
| `{x.id: x for x in items}` | `$dict = @{}; $items \| ForEach-Object { $dict[$_.id] = $_ }` |

**any() with complex generator (common in Prowler):**
```python
# Python
if any(
    "ManagePermissionGrantsForSelf" in policy
    for policy in getattr(perms, 'policies_assigned', [])
):
```

```powershell
# PowerShell
$policies = if ($perms.PSObject.Properties['policies_assigned']) {
    $perms.policies_assigned
} else {
    @()
}
$hasMatch = $policies | Where-Object { $_ -match 'ManagePermissionGrantsForSelf' } |
    Select-Object -First 1
if ($hasMatch) {
```

## Common Standard Library

| Python | PowerShell |
|--------|-----------|
| `json.loads(text)` | `$text \| ConvertFrom-Json` |
| `json.dumps(obj)` | `$obj \| ConvertTo-Json -Depth 10` |
| `datetime.now()` | `[datetime]::Now` or `Get-Date` |
| `datetime.utcnow()` | `[datetime]::UtcNow` or `(Get-Date).ToUniversalTime()` |
| `os.path.join(a, b)` | `Join-Path $a $b` |
| `os.path.exists(path)` | `Test-Path $path` |
| `os.environ['VAR']` | `$env:VAR` |
| `logging.info("msg")` | `Write-Verbose "msg"` |
| `logging.error("msg")` | `Write-Error "msg"` or `Write-Warning "msg"` |
| `logging.debug("msg")` | `Write-Debug "msg"` |

## SDK Patterns

### Azure Graph API

```python
# Python (msgraph SDK)
users_response = await client.users.get()
for user in users_response.value:
    user.display_name
```

```powershell
# PowerShell (Invoke-AzRestMethod or Microsoft.Graph module)
$response = Invoke-MgGraphRequest -Uri '/v1.0/users' -Method GET
foreach ($user in $response.value) {
    $user.displayName
}
```

### Azure Resource Manager

```python
# Python (azure SDK)
storage_accounts = storage_client.storage_accounts.list()
for account in storage_accounts:
    account.name
```

```powershell
# PowerShell (Az module or REST)
$accounts = Get-AzStorageAccount
# or via REST:
$response = Invoke-AzRestMethod -Path "/subscriptions/$sub/providers/Microsoft.Storage/storageAccounts?api-version=2023-05-01"
$accounts = ($response.Content | ConvertFrom-Json).value
```

### AWS (boto3)

```python
# Python
iam = boto3.client('iam')
users = iam.list_users()['Users']
```

```powershell
# PowerShell (AWS.Tools)
$users = Get-IAMUserList
# or via AWS CLI:
$users = (aws iam list-users | ConvertFrom-Json).Users
```
