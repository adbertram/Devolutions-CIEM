<required_reading>
Before starting, read these references:
- [references/python-powershell-mapping.md](../references/python-powershell-mapping.md)
- [references/common-pitfalls.md](../references/common-pitfalls.md)
</required_reading>

<process>

<step name="gather-sources">
Collect both the Python source and the PowerShell conversion. Accept:
- Two file paths (Python original + PowerShell conversion)
- A check ID to locate both files automatically
- Pasted code for both
</step>

<step name="semantic-diff">
Compare the Python and PowerShell side-by-side. Check for:

**Logic preservation:**
- Every `if/elif/else` branch in Python has a corresponding branch in PowerShell
- Status values (PASS, FAIL, SKIP, MANUAL) are assigned under the same conditions
- Default values match (`getattr` defaults → PowerShell defaults)
- Edge cases handled identically (null data, empty collections, missing properties)

**Data flow:**
- Same data sources accessed (service client → script-scoped service variable)
- Same filtering/iteration pattern (subscriptions, resources, items)
- Same aggregation logic (per-resource results, summary results, count limits)

**Message accuracy:**
- Status messages convey equivalent information
- Variable interpolation produces the same output
- Resource names/IDs extracted from the same source fields
</step>

<step name="check-pitfalls">
Scan for common conversion mistakes (see common-pitfalls.md):

- `$false` vs `$null` confusion (Python `not value` catches both; PS `-not $value` does too, but explicit checks differ)
- Missing strict-mode-safe property access
- Array vs scalar confusion (`@()` wrapping needed?)
- String comparison case sensitivity (PS `-eq` is case-insensitive by default; Python `==` is case-sensitive)
- Off-by-one in count comparisons (`< 5` same in both, but verify)
- `continue` in Python for-loop vs `continue` in PowerShell foreach (same semantics, but verify scope)
</step>

<step name="powershell-quality">
Delegate PowerShell-specific quality check to `powershell-expert`:

```
Task tool call:
  subagent_type: "powershell-expert"
  prompt: "Review this PowerShell function for quality and best practices.
    This was converted from Python. Check for:
    1. Idiomatic patterns (not Python-translated code)
    2. Strict mode safety
    3. Advanced function conventions
    4. Pipeline usage
    5. Error handling
    [paste PowerShell code]"
```
</step>

<step name="report">
Present a structured review report:

**Semantic Accuracy:** PASS/FAIL with details
- List any logic branches missing or different
- List any edge cases not handled

**PowerShell Quality:** PASS/FAIL with details
- Issues from powershell-expert review
- Strict mode violations

**Recommendations:**
- Specific fixes needed (with code snippets)
- Improvements that would make the code more idiomatic

If issues found, offer to fix them automatically.
</step>

</process>

<success_criteria>
- Every logic branch in Python is accounted for in PowerShell
- No false positives/negatives introduced by the conversion
- PowerShell code passes powershell-expert review
- Clear, actionable report delivered to user
</success_criteria>
