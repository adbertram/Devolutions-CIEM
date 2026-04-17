---
name: psu
description: >
  MANDATORY: Use this skill for ALL PowerShell Universal (PSU) v5 work, questions, troubleshooting, app/API/automation/configuration, licensing, marketplace, deployment, and Devolutions CIEM PSU workflows. DO NOT web search for PSU behavior before checking bundled local references and the verified local PSU docs mirror. Triggers: PowerShell Universal, PSU, PSU app, PSU server, PSU dashboard, PSU API, Universal Dashboard, PSU automation, PSU script, PSU config, PSU licensing, PSU marketplace, sell PSU app, monetize PSU.
---

<objective>
Provide project-local PowerShell Universal (PSU) v5 expertise without web lookup by combining the extracted `psu-expert` agent operating knowledge with the verified local PSU documentation mirror at `docs/psu-docs`.
</objective>

<quick_start>
1. Read [references/agent-knowledge.md](references/agent-knowledge.md) for the extracted PSU expert rules.
2. Route to the matching workflow below.
3. Use `docs/psu-docs/SUMMARY.md` first, then `rg` inside `docs/psu-docs` for exact terms, cmdlets, API routes, settings, and components.
4. Cite the local documentation files used. Do not web search unless the user explicitly asks for information newer than the local docs.
</quick_start>

<essential_principles>
- The local source of truth for PSU product behavior is `docs/psu-docs`.
- The source of truth for Devolutions CIEM PSU workflows is this repo's `AGENTS.md`, `Devolutions.CIEM.Admin`, `scripts/`, and the extracted `psu-expert` rules.
- For PSU questions, search local docs before answering. If the local docs do not contain the answer, say which local files were checked and ask before using web search.
- For PSU code changes in this repo, follow the project TDD rules and load the required testing skills before writing, changing, or running tests.
</essential_principles>

<routing>
| Response | Action |
|----------|--------|
| PSU facts, cmdlets, settings, APIs, components, licensing, hosting, or architecture | Read [workflows/answer-question.md](workflows/answer-question.md) |
| Create or change PSU apps, APIs, scripts, automation, dashboards, or config | Read [workflows/build-or-change.md](workflows/build-or-change.md) |
| Debug PSU errors, logs, module loading, app startup, jobs, cache, API calls, or Azure runtime issues | Read [workflows/troubleshoot.md](workflows/troubleshoot.md) |
| Devolutions CIEM local/Azure PSU publishing, validation, reset, app creation, or runtime workflows | Read [workflows/ciem-project.md](workflows/ciem-project.md) |
</routing>

<success_criteria>
- [ ] Uses `docs/psu-docs` before any external source
- [ ] Applies the extracted PSU safety and workflow rules
- [ ] Cites local files used for PSU facts
- [ ] Uses CIEM project tooling for CIEM-specific PSU runtime work
</success_criteria>
