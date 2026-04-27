<required_reading>
Before starting, read these references:
- [references/python-powershell-mapping.md](../references/python-powershell-mapping.md)
- [references/prowler-check-anatomy.md](../references/prowler-check-anatomy.md)
</required_reading>

<process>

<step name="read-python-source">
Read the complete Python source file. Identify:
- **Imports**: What SDKs/libraries are used (msgraph, boto3, azure SDK, pydantic)
- **Class structure**: Inheritance (`Check` base class), method names (`execute`)
- **Data access pattern**: Which service client is used, what data it provides
- **Logic pattern**: Simple boolean, counting, nested property, array search, multi-resource iteration
- **Error handling**: Try/except blocks, getattr defaults, None checks
- **Return pattern**: How findings are accumulated and returned
</step>

<step name="identify-pattern">
Classify the check into one of these conversion patterns:

| Python Pattern | PowerShell Equivalent |
|---|---|
| Simple boolean property check | Direct property comparison or helper function call |
| Count-based check (e.g., `len(members) < 5`) | `.Count` comparison |
| Nested property access with None guards | `PSObject.Properties[]` navigation |
| `any()` with generator expression | `Where-Object` pipeline or `-contains` |
| Multi-level iteration (subscription → resources) | Nested `foreach` over service dictionary |
| `getattr(obj, 'prop', default)` | Strict-mode-safe property access pattern |
| String formatting with f-strings | PowerShell `-f` operator or string interpolation |
</step>

<step name="plan-powershell-structure">
Determine the PowerShell function structure:

1. **Function name**: Convert snake_case check ID to PascalCase `Test-*` verb-noun
   - `entra_security_defaults_enabled` → `Test-EntraSecurityDefaultsEnabled`
   - `storage_secure_transfer_required_is_enabled` → `Test-StorageSecureTransferRequiredIsEnabled`

2. **Parameters**: Always `[Parameter(Mandatory)] $Check` (untyped for runspace compatibility)

3. **Data source**: Map Python service client to PowerShell data source
   - Python `entra_client.security_default` → PS `$script:EntraService.SecurityDefaults` (or project-specific variable)
   - Python `storage_client.storage_accounts` → PS `$script:StorageService[$subscriptionId].StorageAccounts`

4. **Result creation**: Map `Check_Report_Azure(...)` to project's result creation pattern

5. **Helper reuse**: Check if an existing helper function handles this pattern (ask user if unsure)
</step>

<step name="convert">
Write the PowerShell function following these rules:

**Function scaffolding:**
```powershell
function Test-CheckNameHere {
    <#
    .SYNOPSIS
        [Title from Python metadata or class docstring]
    .DESCRIPTION
        [Description from Python metadata]
    .PARAMETER Check
        Check metadata object.
    .OUTPUTS
        [ResultType[]] Array of result objects.
    #>
    [CmdletBinding()]
    [OutputType([ResultType[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # Implementation here
}
```

**Conversion rules** (see python-powershell-mapping.md for comprehensive table):
- Python `getattr(obj, 'prop', default)` → `if ($obj.PSObject.Properties['prop']) { $obj.prop } else { $default }`
- Python `for k, v in dict.items()` → `foreach ($key in $dict.Keys) { $value = $dict[$key] }`
- Python `any(cond for x in list)` → `$list | Where-Object { $cond } | Select-Object -First 1`
- Python `len(list)` → `$list.Count` (or `@($list).Count` for null-safe)
- Python `f"string {var}"` → `"string $var"` or `'format {0}' -f $var`
- Python `if not value:` → `if (-not $value)` (but watch for `$false` vs `$null` vs empty string)
- Python class with `execute()` → PowerShell function (no classes for checks)
- Python `findings.append(report)` → PowerShell implicit output collection (just emit objects)
</step>

<step name="review">
Delegate the converted PowerShell to the `powershell-expert` agent for review:

```
Task tool call:
  subagent_type: "powershell-expert"
  prompt: "Review this PowerShell function converted from Python. Check for:
    1. Idiomatic PowerShell patterns (not Python-like code)
    2. Strict mode safety (Set-StrictMode -Version Latest)
    3. Proper advanced function conventions
    4. Correct error handling
    5. Pipeline usage where appropriate
    [paste the converted code]
    Original Python for reference:
    [paste the Python source]"
```

Fix any issues the reviewer raises. Re-submit if changes are significant.
</step>

<step name="deliver">
Present the final PowerShell function to the user with:
- The converted code (written to the appropriate file if a path was specified)
- A brief summary of conversion decisions made
- Any semantic differences or limitations noted
</step>

<step name="enable-check">
After writing the converted PowerShell check to its file, enable the check in `ciem_checks.json`:

```bash
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Manager; Enable-CIEMCheck -CheckId '<check-id>'"
```

This marks the check as active so it runs in scans and becomes selectable in the PSU app UI.
</step>

</process>

<success_criteria>
- PowerShell function produces logically equivalent results to the Python source
- All branches (PASS/FAIL/SKIP/MANUAL) are preserved
- Strict-mode safe (no raw property access on potentially missing props)
- Uses idiomatic PS patterns (pipeline, splatting, proper types)
- Passes `powershell-expert` review
- Help comments match the Python check's metadata
</success_criteria>
