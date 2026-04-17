<required_reading>
- [references/agent-knowledge.md](../references/agent-knowledge.md)
- [references/ciem-project.md](../references/ciem-project.md)
</required_reading>

<process>
<step_1>
For bugs or failing tests, write or identify the failing test first according to the project TDD rules. Do not start by changing implementation code.
</step_1>

<step_2>
Use local logs and read-only inspection tools. For CIEM logs, use `./scripts/ciem-log.sh`. For Azure PSU logs and file inspection, use `scripts/download-psu-logs.sh`, `scripts/azure_psu_file_manager.sh`, and `scripts/invoke_command_in_azure_webapp.sh`.
</step_2>

<step_3>
Search `docs/psu-docs` for exact error text, cmdlet names, API paths, settings, or job/cache concepts involved in the failure.
</step_3>

<step_4>
Fix the root cause. Do not modify PSU `database.db` directly. Do not use unauthenticated bare `curl` against local `/api/v1/*` admin endpoints.
</step_4>

<step_5>
Run the relevant tests and PSU runtime validation before declaring the issue resolved.
</step_5>
</process>

<success_criteria>
- [ ] The failure is reproduced or covered by a test
- [ ] The root cause is fixed at the source
- [ ] Logs and docs used are cited
- [ ] Relevant tests and runtime validation pass
</success_criteria>

