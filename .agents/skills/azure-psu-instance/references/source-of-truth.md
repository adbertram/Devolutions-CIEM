<overview>
This skill is the source of truth for Azure PSU instance operations in the
Devolutions CIEM repo. It consolidates the Azure PSU runbooks that were
previously spread across repo instructions, PSU references, helper scripts, and
older Claude-only skills.
</overview>

<consolidated_sources>
- `AGENTS.md` Azure PSU section and Azure-specific known issues
- `.agents/skills/psu/references/ciem-project.md`
- `.agents/skills/psu/references/agent-knowledge.md`
- `scripts/azure-psu-diagnostics.ps1`
- `scripts/download-psu-logs.sh`
- `scripts/azure_psu_file_manager.sh`
- `scripts/invoke_command_in_azure_webapp.sh`
- `.claude/skills/start-psu-server/SKILL.md`
- `.claude/skills/psu-app-tester/SKILL.md`
</consolidated_sources>

<authoritative_scope>
This skill owns:

- Azure PSU instance preflight
- Azure PSU incident triage
- Cold-start analysis
- ARM and Kudu inspection boundaries
- Token and auth-drift recovery guidance
- Azure-specific PSU runtime verification
- The meaning of the diagnostics report produced by
  `scripts/azure-psu-diagnostics.ps1`
</authoritative_scope>

<handoff_boundaries>
Keep generic responsibilities where they already belong:

- Generic PSU product behavior and local PSU workflows stay in the `psu` skill.
- Semantic version selection and publish execution stay in
  `publish-psu-module`.
- Test authoring, review, and suite execution stay in `testing-expert` and
  `pester-tests`.

This skill is the gate in front of those workflows whenever the Azure instance
itself is in question.
</handoff_boundaries>

<superseded_patterns>
Do not rebuild Azure PSU troubleshooting from scattered habits such as:

- rerunning broad Azure suites before checking instance state
- restarting the whole web app before checking app-level health
- treating Kudu, ARM, and PSU runtime failures as the same thing
- assuming a 401 means the app is down
- assuming a healthy `/api/v1/alive` response means auth profiles, app tokens,
  module state, and CIEM runtime state are also healthy
</superseded_patterns>
