---
name: azure-psu-instance
description: >
  MANDATORY: Use this skill for ALL Azure PSU instance debugging, runtime inspection, recovery triage, cold-start analysis, token/auth drift, ARM/Kudu diagnostics, and production-environment verification in Devolutions CIEM. DO NOT troubleshoot the Azure PSU instance ad hoc without this workflow.
---

<objective>
Centralize all Azure PSU instance knowledge for the Devolutions CIEM production
web app. This skill owns deterministic preflight, debugging, recovery triage,
and inspection of the Azure-hosted PSU instance, with
`scripts/azure-psu-diagnostics.ps1` as the first tool instead of ad hoc reruns,
blind restarts, or scattered runbooks.
</objective>

<quick_start>
1. For any Azure PSU instance issue, read [workflows/debug-instance.md](workflows/debug-instance.md).
2. For "is Azure ready?" or "run Azure safely before tests or publish", read [workflows/preflight.md](workflows/preflight.md).
3. Before rerunning long diagnostics, inspect `_temp/azure-psu-diagnostics.log`. The diagnostics script overwrites that file on each run.
4. Load only the references needed for the current issue.
</quick_start>

<essential_principles>
- Start with `scripts/azure-psu-diagnostics.ps1`. It is the authoritative preflight and triage entrypoint for this instance.
- Use the last transcript log before starting another long diagnostics run.
- Separate failures into the right plane: Azure control plane, Kudu control plane, PSU runtime, or application behavior.
- Prefer app-level restart or configuration sync before `az webapp restart`.
- Use one combined `Invoke-TestCommand` probe instead of many small runtime calls.
- Never upload module files directly to Azure PSU.
- `scripts/azure_psu_file_manager.sh` and `scripts/invoke_command_in_azure_webapp.sh` are inspection-only tools.
- Do not treat known Azure PSU failures as novel. Check [references/known-issues.md](references/known-issues.md) early.
</essential_principles>

<routing>
| Request shape | Action |
|--------------|--------|
| "Is Azure ready?", "preflight Azure", "check Azure PSU health", "before tests", "before publish" | Read [workflows/preflight.md](workflows/preflight.md) |
| "Azure PSU is broken", "fix Azure auth", "401", "cold", "App is not running", "Kudu", "ARM", "module not loading", "Azure tests failing" | Read [workflows/debug-instance.md](workflows/debug-instance.md) |
| "What do we know about the Azure PSU instance?" | Read [references/source-of-truth.md](references/source-of-truth.md) and [references/instance-baseline.md](references/instance-baseline.md) |
| "How do I interpret the diagnostics output?" | Read [references/diagnostics-report.md](references/diagnostics-report.md) |
</routing>

<reference_index>
- [references/source-of-truth.md](references/source-of-truth.md): consolidated provenance and authority boundaries
- [references/instance-baseline.md](references/instance-baseline.md): fixed instance facts, expected steady state, and guardrails
- [references/diagnostics-report.md](references/diagnostics-report.md): diagnostics command, log behavior, report sections, and failure interpretation
- [references/inspection-tools.md](references/inspection-tools.md): exact inspection commands and when to use each tool
- [references/known-issues.md](references/known-issues.md): known Azure PSU failures, symptoms, causes, and deterministic actions
</reference_index>

<workflows_index>
| Workflow | Purpose |
|----------|---------|
| [workflows/preflight.md](workflows/preflight.md) | Determine whether Azure PSU is healthy enough for tests, publish verification, or runtime validation |
| [workflows/debug-instance.md](workflows/debug-instance.md) | Troubleshoot Azure PSU instance failures, classify the failure plane, and choose the next inspection or recovery step |
</workflows_index>

<success_criteria>
- [ ] The skill routes to the correct workflow without asking avoidable questions
- [ ] `scripts/azure-psu-diagnostics.ps1` or its last transcript log is used before broad reruns or restarts
- [ ] The incident is classified as Azure control plane, Kudu control plane, PSU runtime, or application behavior
- [ ] Recommended next steps are specific, reproducible, and grounded in repo-local tooling
- [ ] Azure PSU guidance stays centralized here instead of being rebuilt ad hoc
</success_criteria>
