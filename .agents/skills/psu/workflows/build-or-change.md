<required_reading>
- [references/agent-knowledge.md](../references/agent-knowledge.md)
- [references/ciem-project.md](../references/ciem-project.md)
</required_reading>

<process>
<step_1>
If the task changes code in this repo, follow the project TDD workflow first. Load the required testing skills before writing, reviewing, or running tests.
</step_1>

<step_2>
Use `docs/psu-docs/SUMMARY.md` and targeted `rg` searches under `docs/psu-docs` to confirm the PSU API, cmdlet, component, or configuration behavior before implementation.
</step_2>

<step_3>
Keep PSU implementations aligned with standard PSU file structure and this repo's CIEM publishing model. Ask where files should be created if the target path is not already clear from the request or surrounding code.
</step_3>

<step_4>
For CIEM runtime behavior, validate with Pester or Playwright as required, then use `Invoke-TestCommand` when PSU runtime context matters.
</step_4>
</process>

<success_criteria>
- [ ] Tests are written before implementation for code changes
- [ ] PSU behavior is verified from local docs
- [ ] CIEM publishing and validation rules are followed
- [ ] Relevant tests and runtime validation pass
</success_criteria>

