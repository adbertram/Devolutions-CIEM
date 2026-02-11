---
name: review-powershell-work
description: Reviews PowerShell code against community best practices using the powershell-expert agent. Use when reviewing pending git changes or specific PowerShell files for standards compliance, with optional remediation. Triggers on "review powershell", "ps review", "check powershell code", "powershell standards".
---

<objective>
Reviews PowerShell code for compliance with community best practices and coding standards. Delegates the actual review to the powershell-expert agent which has comprehensive knowledge of PowerShell conventions including module structure, function organization, naming, and Pester testing patterns.
</objective>

<quick_start>
1. Ask user what to review (default: pending git changes)
2. Ask if remediation is desired
3. Invoke powershell-expert agent with review task
4. Present findings and remediate if requested
</quick_start>

<intake>
Use AskUserQuestion to gather:

1. **What to review** (header: "Scope")
   - "Pending git changes (Recommended)" - Review all modified .ps1/.psm1/.psd1 files in git status
   - "Specific file or folder" - User provides path
   - "Entire module" - Review complete module structure

2. **Remediation preference** (header: "Remediate")
   - "Review only" - Report issues without making changes
   - "Review and fix (Recommended)" - Automatically remediate issues found
</intake>

<workflow>
After gathering inputs:

1. **Identify files to review**
   - If pending git changes: Run `git status --porcelain` and filter for .ps1, .psm1, .psd1 files
   - If specific path: Validate path exists
   - If entire module: Find module root with .psd1 manifest

2. **Invoke powershell-expert agent**
   Use the Task tool with:
   ```
   subagent_type: powershell-expert
   prompt: |
     Review the following PowerShell files for standards compliance:
     [list files]

     Check for:
     - Module structure (functions in Public/Private, not PSM1)
     - Function naming (Verb-Noun with approved verbs)
     - Parameter declarations and validation
     - Comment-based help
     - Error handling patterns
     - Pester test structure (if tests exist)
     - Class type leakage (see Class Type Isolation rule below)

     [If remediation requested]: Fix any issues found.
     [If review only]: Report issues without making changes.

     Provide a summary table of findings with:
     | File | Issue | Severity | Status |
   ```

3. **Report results**
   Present the agent's findings to the user.
</workflow>

<class_type_isolation>
## Class Type Isolation Rule

PowerShell classes defined inside a module are scoped to that module. Callers
(including PSU endpoint runspaces) cannot reference them via `[TypeName]` syntax
because the type literal is resolved at parse time, before `Import-Module` runs.

**Rule:** Public functions MUST NOT require module-defined class types as
parameters. Accept simple types (strings, hashtables, bools) in the public API
and construct typed objects internally within the function (which runs in module
scope where the classes are available).

**Applies to:**
- `[Parameter()] [SomeModuleClass]$Param` in public function signatures
- Requiring callers to do `[SomeModuleClass]::new()` before calling a function
- Returning typed objects that callers must pass back as parameters

**Acceptable:**
- Returning typed objects for read-only consumption (e.g. `Get-*` functions)
- Using class types in Private/internal functions (module scope)
- Using class types between functions within the module

**Flag as:** Severity HIGH — causes runtime "Unable to find type" errors in PSU.
</class_type_isolation>

<success_criteria>
This skill is complete when:
- [ ] User's scope preference was gathered
- [ ] Remediation preference was gathered
- [ ] powershell-expert agent was invoked with appropriate files
- [ ] Findings were presented to user
- [ ] If remediation requested: issues were fixed
</success_criteria>
