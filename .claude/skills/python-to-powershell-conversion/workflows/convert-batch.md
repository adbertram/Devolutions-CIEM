<required_reading>
Before starting, read these references:
- [references/python-powershell-mapping.md](../references/python-powershell-mapping.md)
- [references/prowler-check-anatomy.md](../references/prowler-check-anatomy.md)
</required_reading>

<process>

<step name="inventory">
Collect all Python files to convert. Accept input as:
- A directory path (glob for `*.py` files, exclude `__init__.py` and `*_client.py`)
- A list of file paths
- A service name to scan (e.g., "all entra checks")

Present the list to the user for confirmation before proceeding.
</step>

<step name="analyze-patterns">
Read ALL Python files first. Identify shared patterns across the batch:
- Common service clients used
- Repeated property access patterns → candidate for a shared helper function
- Consistent iteration patterns (subscription → resources)
- Common status message formats

Group checks by conversion pattern:
1. **Simple helper-delegated** checks (single property check → call existing helper)
2. **Multi-resource iteration** checks (loop over resources, per-resource result)
3. **Complex logic** checks (counting, array searching, conditional branching)
</step>

<step name="identify-helpers">
Before converting individual checks, identify if any should become shared helper functions:
- 3+ checks with the same iteration + property check pattern → parameterized helper
- Common boolean policy checks → single helper with property name parameter
- Common expiration checks → single helper with item type parameter

Propose helpers to the user. Create helpers first, then convert checks to use them.
</step>

<step name="convert-sequentially">
Convert each check following the convert-single workflow process (steps 2-4).

**Maintain consistency across the batch:**
- Same naming convention for all functions
- Same comment style and help format
- Same error handling approach
- Same result creation pattern
- Reuse helpers identified in the previous step

Track progress: report `[N/total] Converting: check_name` as you go.
</step>

<step name="batch-review">
After all conversions complete, submit the FULL batch to `powershell-expert` for review:

```
Task tool call:
  subagent_type: "powershell-expert"
  prompt: "Review this batch of N PowerShell functions converted from Python Prowler checks.
    Focus on:
    1. Consistency across all functions (naming, style, patterns)
    2. Helper function design (correct parameterization, reusability)
    3. Idiomatic PowerShell in each function
    4. Strict mode safety
    [paste all converted code or list file paths]"
```

Fix issues across the batch. Ensure consistency is maintained.
</step>

<step name="deliver">
Present final results:
- List of all converted files with paths
- Any shared helpers created
- Summary of patterns found and decisions made
- Count: total converted, any skipped (with reasons)
</step>

<step name="enable-checks">
After all conversions are complete, enable the converted checks in `ciem_checks.json`:

```bash
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Manager; @('check-id-1','check-id-2') | Enable-CIEMCheck"
```

This marks the checks as active so they run in scans and become selectable in the PSU app UI.
</step>

</process>

<success_criteria>
- All checks in the batch are converted
- Shared patterns extracted into reusable helpers
- Consistent style across all converted functions
- Batch passes `powershell-expert` review as a cohesive set
- No semantic drift between Python originals and PowerShell conversions
</success_criteria>
