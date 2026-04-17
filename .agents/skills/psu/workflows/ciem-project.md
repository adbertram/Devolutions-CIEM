<required_reading>
- [references/agent-knowledge.md](../references/agent-knowledge.md)
- [references/ciem-project.md](../references/ciem-project.md)
</required_reading>

<process>
<step_1>
Determine whether the target is local PSU on adam-server or Azure PSU. Use local by default unless the user explicitly asks for Azure or production validation.
</step_1>

<step_2>
For publishing, use `Publish-PSUModule` from `Devolutions.CIEM.Admin`. Use `-LocalOnly` for adam-server. Do not upload module files directly to Azure PSU.
</step_2>

<step_3>
For runtime checks, import `Devolutions.CIEM.Admin`, connect with `Connect-PSU` as needed, and combine related `Invoke-TestCommand` operations into one call.
</step_3>

<step_4>
For Azure inspection, use the read-only scripts from `references/ciem-project.md`. Treat Kudu shell commands as filesystem inspection; use PSU REST API for runtime state.
</step_4>
</process>

<success_criteria>
- [ ] Local vs Azure target is explicit
- [ ] Publishing uses project tooling
- [ ] Inspection tools are used read-only
- [ ] Runtime validation is done with the right environment
</success_criteria>
