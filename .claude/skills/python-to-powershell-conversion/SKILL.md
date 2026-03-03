---
name: python-to-powershell-conversion
model: opus
description: >
  Converts Python code to idiomatic PowerShell, specializing in Prowler security check patterns.
  Use when converting Python scripts, functions, or classes to PowerShell equivalents,
  especially Prowler cloud security checks. Triggers: "convert python", "python to powershell",
  "port this check", "convert prowler", "translate python".
---

<objective>
Convert Python code to idiomatic, strict-mode-safe PowerShell that a senior PS developer would approve of. Specializes in Prowler security check patterns but handles general Python→PS conversion.
</objective>

<quick_start>
Provide a Python file path, pasted code, or check ID. The skill reads the Python, identifies the conversion pattern, produces idiomatic PowerShell, and delegates to `powershell-expert` for review.
</quick_start>

<essential_principles>

<principle name="idiomatic-conversion">
Never transliterate Python line-by-line. Produce PowerShell that a senior PS developer would write natively. Use PowerShell pipeline, splatting, cmdlet patterns, and advanced functions.
</principle>

<principle name="read-before-convert">
Always read the FULL Python source before writing any PowerShell. Understand the intent, data flow, edge cases, and error handling. Then produce a single clean conversion.
</principle>

<principle name="strict-mode-safe">
All generated PowerShell must survive `Set-StrictMode -Version Latest`. Use `$obj.PSObject.Properties['name']` for property existence checks, never raw dot-access on potentially missing properties.
</principle>

<principle name="review-after-convert">
After conversion, delegate to the `powershell-expert` agent (via Task tool with `subagent_type: "powershell-expert"`) for review. Fix any issues it raises before presenting final code.
</principle>

<principle name="preserve-semantics">
The PowerShell output must produce identical logical results to the Python input. Same conditions trigger same outcomes (PASS/FAIL/SKIP). Same edge cases handled. Test coverage must be equivalent.
</principle>

</essential_principles>

<intake>
What would you like to do?

1. **Convert a single Python file** to PowerShell
2. **Convert multiple Python files** (batch conversion)
3. **Review an existing conversion** for accuracy
4. Something else

Provide the Python source (file path, pasted code, or URL) along with your choice.

**Wait for response before proceeding.**
</intake>

<routing>
| Response | Workflow |
|----------|----------|
| 1, "convert", "port", "translate", single file | [workflows/convert-single.md](workflows/convert-single.md) |
| 2, "batch", "multiple", "all" | [workflows/convert-batch.md](workflows/convert-batch.md) |
| 3, "review", "validate", "check" | [workflows/review-conversion.md](workflows/review-conversion.md) |
| 4, other | Clarify intent, then select appropriate workflow |

**After reading the workflow, follow it exactly.**
</routing>

<reference_index>
All domain knowledge in `references/`:

**Language Mapping:** [python-powershell-mapping.md](references/python-powershell-mapping.md) - Comprehensive Python→PS syntax and pattern translation table
**Prowler Patterns:** [prowler-check-anatomy.md](references/prowler-check-anatomy.md) - Structure of Prowler Python checks (classes, metadata, execute methods, service clients)
**Common Pitfalls:** [common-pitfalls.md](references/common-pitfalls.md) - Known gotchas in Python→PS conversion
</reference_index>

<workflows_index>
| Workflow | Purpose |
|----------|---------|
| convert-single.md | Convert one Python file to idiomatic PowerShell |
| convert-batch.md | Convert multiple Python files maintaining consistency |
| review-conversion.md | Validate an existing conversion against its Python source |
</workflows_index>

<success_criteria>
A successful invocation:
- Produces PowerShell that passes `powershell-expert` review
- Preserves all logical branches, edge cases, and error conditions from the Python source
- Uses idiomatic PowerShell patterns (not Python-translated-to-PS syntax)
- Is strict-mode safe (`Set-StrictMode -Version Latest`)
- Follows advanced function conventions (`[CmdletBinding()]`, proper help, `[OutputType()]`)
</success_criteria>

<validated>
Validated by validate-skill on 2026-02-12 14:30
</validated>
