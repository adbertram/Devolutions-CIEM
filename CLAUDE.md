# Devolutions CIEM

CIEM (Cloud Infrastructure Entitlement Management) on PowerShell Universal (PSU). Identity-first, not resource-first. Strategic context, business model, stakeholders, and architecture decisions: `docs/project-context.md`. Product direction: `docs/ciem-feature-todos.md`.

@/Users/adam/.claude/skills/test-methodology/SKILL.md

## Test-Driven Development (MANDATORY)

**Your first action on any code change is to identify and write tests.** Do not read source, do not explore, do not plan changes — go to the relevant test files first. A PreToolUse hook (`enforce-tdd.sh`) DENIES source edits until test files have been touched.

- Pester for PowerShell/module logic; Playwright E2E for PSU UI; both when a change crosses boundaries
- Tests must FAIL before any implementation/debugging (red-green-refactor)
- Cover all scenarios where the issue could manifest, not just the reported case
- All relevant tests green before "done"; never pipe test output through head/tail/grep
- Bug fixes: write the failing test reproducing the bug FIRST — the test defines what "fixed" means

Load `testing-expert` skill before writing any test; load `pester-tests` for Pester work. Detailed rules in `.claude/rules/tdd-enforcement.md` (auto-loaded for `psu-app/` and `e2e/`).

Run commands:
```bash
pwsh -NoProfile -Command "Invoke-Pester psu-app/ -Output Detailed"   # Pester
cd psu-app/ui/e2e && npx playwright test                              # Playwright
```

## Default PSU Instance (CRITICAL)

**"Local" PSU = the always-on adam-server instance (Mac Mini).** There is NO MacBook PSU. Default to "local" unless the user explicitly says "Azure" or "production".

- `Connect-PSU` defaults local; reads `LOCAL_PSU_URL` / `LOCAL_PSU_TOKEN` from `.env`. Use `Connect-PSU -Azure` for production.
- `Deploy-PSUModule -Environment local` installs the current PSGallery version into adam-server PSU and restarts the app
- `Invoke-TestCommand -Environment local` (default) runs commands inside PSU

Server config, .env keys, recovery escalation, log access: `.claude/rules/psu-instances.md` (auto-loaded for PSU paths).

## PSU Delegation (MANDATORY)

**All PowerShell Universal operations are delegated to the `psu-expert` agent.** This includes research, configuration, troubleshooting, publishing, restarting, script management, and job management. Do NOT run PSU API calls directly, use WebSearch/microsoft_docs_search for PSU questions, or guess from general PowerShell knowledge. The psu-expert has local PSU v5 docs at `docs/psu-docs/` and Azure server filesystem access.

## Module Deployment (CRITICAL)

**Never upload module files directly to Azure PSU.** Publishing and deploying are now two distinct steps:

1. `Publish-PSUModule` (from `Devolutions.CIEM.Admin`) bumps the manifest and publishes to PowerShell Gallery. PSGallery-only — does not touch PSU. Use the `publish-psu-module` skill.
2. `Deploy-PSUModule` installs the current (or pinned) Gallery version into a PSU instance via `Install-PSUModule`, restarts the CIEM app, and optionally validates. Use the `deploy-psu-module` skill.

```powershell
Import-Module ./Devolutions.CIEM.Admin

# Step 1: publish to PSGallery
Publish-PSUModule -ModulePath ./psu-app -BumpVersion Patch -WhatIf  # Dry run
Publish-PSUModule -ModulePath ./psu-app -BumpVersion Patch          # Publish to Gallery

# Step 2: deploy the current PSGallery version to PSU
Deploy-PSUModule -Environment local                                  # adam-server
Deploy-PSUModule -Environment azure                                  # production
Deploy-PSUModule -Environment local -ValidateDeployment              # with end-to-end validation
```

Setup boundaries:
- `psu-app/setup.ps1` (invoked during module import) does **only** idempotent local module init (DB schema, catalog).
- `.universal/dashboards.ps1` and `.universal/scripts.ps1` own PSU resource registration. Do NOT move `New-PSUApp`, `New-PSUScript`, `Get-PSUScript` into import-time setup.

`azure_psu_file_manager.sh` and `invoke_command_in_azure_webapp.sh` are for inspection/troubleshooting only — never for deploying code.

## Testing In-PSU Behavior

`Invoke-TestCommand` (in `Devolutions.CIEM.Admin`) runs commands against the CIEM module inside PSU; handles connection and credentials.

```bash
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Invoke-TestCommand -ScriptBlock { Get-CIEMProvider }"
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Invoke-TestCommand -ScriptBlock { Invoke-CIEMScan -Service Entra } -Environment azure"
```

Use this to validate inside PSU before publishing — not as a substitute for tests, and never as a publish-debug-publish loop.

## Troubleshooting

`./scripts/ciem-log.sh` queries the CIEM application log on adam-server (with local fallback). Run `./scripts/ciem-log.sh --help` for flags. The CIEM log captures issues PSU's own logs miss (module init, provider registration, schema). If `ciem.log` doesn't explain it, check PSU logs via `./scripts/download-psu-logs.sh --local`.

Recovery escalation, .env keys, and Azure cold-start guidance: `.claude/rules/psu-instances.md`.

## Status Reports & Slack

Status reports → `status-reports` skill (`/send-status-report`). Slack DMs as Adam → `devolutions-team-member` agent. Never draft updates ad-hoc with `git log` + `slack` CLI; never read the team group DM directly.

## Other Project Rules

Auto-loaded by path:
- `.claude/rules/tdd-enforcement.md` — TDD details (psu-app/, e2e/)
- `.claude/rules/psu-instances.md` — PSU server config, .env, recovery, logs
- `.claude/rules/known-issues.md` — recurring bugs and their fixes
- `.claude/rules/azure-infra.md` — Azure infra and file manager
- `.claude/rules/crud-convention.md` — DB CRUD conventions
- `.claude/rules/checks-management.md` — check management functions
- `.claude/rules/e2e-testing.md`, `.claude/rules/error-action-preference.md`, `.claude/rules/psu-admin-cmdlets.md`
