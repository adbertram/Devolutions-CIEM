# Devolutions CIEM

@/Users/adam/.claude/skills/testing-methodology/SKILL.md

## CRITICAL: Test-Driven Development (TDD) -- MANDATORY

**YOUR FIRST ACTION on ANY code change request MUST be identifying and writing tests. Do NOT read source code, do NOT explore implementation, do NOT plan changes. Go directly to the relevant test files and test definitions first.**

- **MUST** include tests for every code change: Pester for PowerShell/module logic, Playwright E2E for PSU UI behavior, and both when a change crosses those boundaries
- **MUST** write tests BEFORE implementation code or debugging (red-green-refactor)
- **MUST** cover all scenarios where the issue could manifest -- not just the reported case
- **MUST** run all relevant tests and confirm green before marking work complete
- **MUST NOT** begin investigating or fixing code before writing failing tests
- **MUST NOT** submit, commit, or declare any change "done" without passing tests
- **MUST NOT** pipe test output through filters (head, tail, grep) -- show FULL output

**SEQUENCE CHECK:** If your first tool call after a code change request is Read/Bash on a source file (not a test file), you are already violating TDD. Stop and start over with tests. A PreToolUse hook (`enforce-tdd.sh`) will DENY source code edits until test files have been touched.

**MANDATORY TDD workflow:**

1. **Identify which tests are needed** (Pester unit/integration tests, Playwright E2E tests, or both)
2. **Load the `testing-expert` skill BEFORE writing, reviewing, or running any test.** Load `pester-tests` as well for Pester-specific work. NEVER write a test file without loading the relevant skill first.
3. **Write ALL failing tests first** -- tests MUST exist and fail before ANY implementation or debugging
4. **Tests must cover all relevant scenarios** -- edge cases and related code paths where the same issue can manifest
5. **Then and ONLY then** begin implementation or troubleshooting
6. **Run ALL relevant test types** before declaring done:
   - [ ] Pester tests (if PowerShell/module/data code changed): `pwsh -NoProfile -Command "Invoke-Pester psu-app/ -Output Detailed"`
   - [ ] Playwright E2E tests (if PSU UI pages/interactions changed): `cd psu-app/ui/e2e && npx playwright test`
   - [ ] Both Pester and Playwright when module behavior is surfaced in the UI
   - [ ] `Invoke-TestCommand` when PSU runtime context matters; this is additional validation, not a substitute for tests

**CRITICAL FOR BUG FIXES:** Do NOT jump into the code to investigate. First, write failing tests that reproduce the bug. The tests define what "fixed" means.

Detailed TDD rules, test layer conventions, and what requires tests: `.claude/rules/tdd-enforcement.md` (auto-loaded for `psu-app/` and `e2e/` paths).

---

## Default PSU Instance (CRITICAL)

**"Local" PSU = the always-on adam-server instance** (Mac Mini). There is NO MacBook PSU. Code is pushed to adam-server via SSH/rsync. Default to this "local" instance for all operations unless the user explicitly says "Azure" or "production":

- **Opening PSU:** URL from `LOCAL_PSU_URL` in `.env` (LAN IP, e.g., `http://192.168.86.30:5001`)
- **Publishing modules:** `Publish-PSUModule -LocalOnly` (pushes via SSH/rsync to publish point, restarts adam-server app)
- **Testing commands:** `Invoke-TestCommand -Environment local` (default)
- **`Connect-PSU`:** `Connect-PSU -Local` (reads `LOCAL_PSU_URL` and `LOCAL_PSU_TOKEN` from `.env`)

## Project Context

This project is a CIEM (Cloud Infrastructure Entitlement Management) solution built on PowerShell Universal (PSU).

### Developer Context

- **Role**: Devolutions contractor (25 hrs/week), full-time dev since March 2025 (previously split with product marketing)
- **Focus**: CIEM project exclusively — PSU app, PowerShell module, identity security
- **Previous work**: RDM Pester tests, PAM AnyIdentity providers/propagation scripts, content/datasheets
- **PSU Ownership**: PowerShell Universal is owned by Devolutions (acquired from Ironman Software)

### CIEM Business Model

Key context from discussions with Marc-André Moreau:

- **Distribution**: PSU app published to the PSU Gallery (not standalone deployment)
- **Business Model**: Free add-on for PSU customers (no additional cost beyond PSU license)
- **Strategic Purpose**: Lead generation for Devolutions PAM solution; CIEM is a Gartner inclusion criteria for PAM
- **Differentiation**: CIEM is niche and valuable — CSPM is a commodity already bundled free in cloud platforms
- **Action Flow**: CIEM identifies findings → users are redirected to Devolutions PAM to take action

### Product Purpose And Expected Features

- `docs/ciem-feature-todos.md` is the source of truth for the project's purpose and expected product capabilities. Treat it as project direction, not an optional idea list.
- CIEM should discover cloud and identity entitlement data, build the environment hierarchy, detect attack paths, detect exposure changes over time, and make findings actionable through existing security and PAM workflows.
- Expected discovery priorities are scheduled discovery scans, exposure change detection, AWS effective access graph, least-privilege recommendation previews, privilege drift detection, sensitive resource access inventory, expanded attack path patterns, and discovery coverage reporting.
- Expected action and connector priorities are outbound risk signal delivery, finding-to-action queue, PAM-backed JIT access requests, manual approval and evidence capture, least-privilege change packages, controlled role or policy updates, and automatic expiration or revocation.
- Discovery remains read-only by default. Action, connector, PAM, SIEM, ticketing, IdP, or cloud write workflows require explicit re-scoping before implementation.

### CSPM vs CIEM Positioning (CRITICAL)

Per Simon Chalifoux's detailed review (March 2026): the initial implementation was CSPM (CIS best-practice checks), not true CIEM. CSPM is a commodity — Azure Defender for Cloud offers it free. The project must focus on **CIEM-specific features** that differentiate from free tools:

- **Identity-first data model (CRITICAL)** — The entire system is modeled around **identities**, not resources. Graph/control relationships are the right representation, but the primary axis is identity → entitlements. This is how real CIEMs work.
- **Identity drill-down view** — Users must be able to drill down from an identity to all entitlements it holds, surfacing compound risk (e.g., "this VM has a managed identity with Owner role on the subscription, a public IP, and RDP open on the network")
- **Dormant permission detection** — Users/service principals with unused privileged roles (via sign-in logs)
- **Role right-sizing** — Propose least-privilege custom roles to replace overly broad assignments
- **Control relationship discovery** — Map identity-to-resource relationships and surface attack paths
- **Risk-to-PAM mapping** — Connect findings to Devolutions PAM privileged roles

Existing Prowler-ported CSPM checks are retained as a secondary feature but are NOT the differentiator.

**Reference Products (from Simon Chalifoux's analysis):**
- **Delinea** Privilege Control for Cloud Entitlements
- **BeyondTrust Entitle** (2025 GigaOm Radar Leader)
- **BloodHound / AzureHound** for attack path detection methodology
- Microsoft retired **Entra Permissions Management** (formerly CloudKnox) Nov 2025, redirected to Delinea — gap to fill in Azure ecosystem
- Gartner's four CIEM pillars: Entitlement visibility, Permission right-sizing, Advanced analytics, Compliance automation

### Stakeholders & Team

**CIEM Core Team:**

| Person | Slack ID | Role |
|--------|----------|------|
| **Marc-André Moreau** | mamoreau | VP/Project Sponsor — gave CIEM vision, strategic direction, approval authority |
| **Simon Chalifoux** | schalifoux | Security Architect — gave critical CSPM-vs-CIEM feedback (March 2026), expert on Gartner CIEM pillars. Shaped the identity-first pivot. |
| **David Hervieux** | dhervieux | Engineering Lead — wants demo video, discussed JSON-first approach with Marc-André. Bilingual (FR/EN). |
| **Luc Fauvel** | lfauvel | Security — interested in CIEM, introduced by Marc-André, saw demo |
| **Adam Driscoll** | adriscoll | PSU Creator — module dependency expert, gave PSU license |

**Engineering/Management:**

| Person | Slack ID | Role |
|--------|----------|------|
| **Sébastien Duquette** | sduquette | Engineering Manager (RDM PowerShell) — gave Jira/GitHub access, aware of CIEM |
| **Maxime Bernier** | mbernier | RDM PowerShell Dev — PR reviewer |
| **Maxime Trottier** | mtrottier | Contract/HR Manager — handles SoW renewals |

### Slack Context

Use `--profile devolutions` flag on the main `slack` command for all Devolutions workspace operations.

```bash
# Read DMs with a team member
slack --profile devolutions dm read mamoreau --limit 50

# List all DMs (include group DMs with -g)
slack --profile devolutions dm list --table -g

# Read group DM by channel ID
slack --profile devolutions dm read <channel_id> --limit 50

# Send DM (use devolutions-team-member agent for drafting)
slack --profile devolutions dm send <username> "message text"
```

For representing Adam in Slack communications, use the `devolutions-team-member` agent — it knows Adam's communication style, all team relationships, and project context.

### Weekly Status Reports

All status report operations (sending + checking replies) go through the `status-reports` skill (`.claude/skills/status-reports/`). Never draft updates ad-hoc with `git log` + `slack` CLI, and never read the team group DM directly to check for replies — always load the skill.

- **Skill location:** `.claude/skills/status-reports/SKILL.md` (router with two workflows)
- **Send workflow:** `.claude/skills/status-reports/workflows/send.md` — invoked by `/send-status-report` (accepts `dryrun` arg)
- **Check-replies workflow:** `.claude/skills/status-reports/workflows/check-replies.md` — fetches team feedback on the latest report
- **Report archive:** `.claude/skills/status-reports/reports/YYYY-MM-DD/` — each week is a folder with `report.md` + full-page Playwright screenshots. Read prior reports for tone and what's already been communicated.
- **Send script:** `.claude/skills/status-reports/scripts/send-report.sh` (supports `--dryrun` to DM adbertram first before team send)
- **Team group DM:** channel `C0AFCLP7SUF` (mamoreau, schalifoux, alistek, adbertram), accessed via `slack --profile devolutions dm read C0AFCLP7SUF`
- **Content rules:** User-facing feature language only — NO git branches, commits, or developer terminology. Reports ask stakeholders for directional feedback.

---

## PSU Delegation (MANDATORY)

**ALL PowerShell Universal operations MUST be delegated to the `psu-expert` agent.** This includes research, configuration, troubleshooting, publishing, restarting, script management, job management, and any other PSU-specific action.

Do NOT:
- Run PSU API calls, cmdlets, or server operations directly
- Use WebSearch, microsoft_docs_search, or other tools for PSU questions
- Guess based on general PowerShell knowledge

Instead, invoke the psu-expert agent via the Task tool. The psu-expert has:
- Local PSU v5 documentation at `docs/psu-docs/`
- Access to the Azure PSU server filesystem
- Deep knowledge of PSU APIs, cmdlets, and configuration

**When to delegate:** Any PSU operation — research, API calls, server management, script registration, job management, troubleshooting, or configuration.

---

## Module Deployment Workflow (CRITICAL)

**NEVER upload module files directly to the Azure PSU instance.** The correct workflow is:

1. Make changes to `Devolutions.CIEM/` module
2. Publish using `Publish-PSUModule` (auto-bumps version, auto-imports to PSU)

```powershell
# Load the admin module
Import-Module ./Devolutions.CIEM.Admin

# WRONG - Never do this
./scripts/azure_psu_file_manager.sh upload Devolutions.CIEM/ Repository/Modules/

# CORRECT - Publish to PSGallery and import to production PSU
Publish-PSUModule -ModulePath ./psu-app -WhatIf  # Dry run first
Publish-PSUModule -ModulePath ./psu-app           # Publish and auto-import to PSU

# LOCAL DEV - Import to local PSU only (skips PSGallery publish)
Publish-PSUModule -ModulePath ./psu-app -LocalOnly
```

**What Publish-PSUModule does:**
1. Validates module structure
2. Queries PSGallery for current version
3. Auto-bumps version (Patch by default, use `-BumpVersion Minor|Major`)
4. Publishes to PowerShell Gallery
5. Verifies publication
6. Auto-connects to PSU (reads PROD_PSU_URL/PSU_TOKEN from .env)
7. Imports the new version to PSU

**With `-LocalOnly`:** Skips steps 2-5, connects to local PSU via `Connect-PSU -Local`, pushes the module via SSH/rsync to the publish point, and restarts the app.

**Why:** The PSU Gallery is the distribution mechanism. Direct uploads bypass version control, break the upgrade path for users, and don't follow the intended distribution model.

**Note:** The file manager scripts (`azure_psu_file_manager.sh`, `invoke_command_in_azure_webapp.sh`) are for **troubleshooting and inspection only** - never for deploying module code.

---

## Testing Commands

Use `Invoke-TestCommand` (from the `Devolutions.CIEM.Admin` module) to run PowerShell commands against the CIEM module. It handles PSU connection and credential loading automatically.

```bash
# Run on local PSU (default)
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Invoke-TestCommand -ScriptBlock { Get-CIEMProvider }"

# Run on Azure PSU
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Invoke-TestCommand -ScriptBlock { Invoke-CIEMScan -Service Entra } -Environment azure"
```

| Environment | What it does | When to use |
|-------------|-------------|-------------|
| `local` | `Connect-PSU -Local` then `Invoke-PSUCommand` | Testing in local PSU context (default) |
| `azure` | `Connect-PSU` then `Invoke-PSUCommand` | Testing against production PSU |

**Always test before publishing.** Use `local` (default) for development, `azure` to validate in production. Run `Invoke-TestCommand -ScriptBlock { ... }` to validate changes work inside PSU before publishing a new version. Do not use publish-debug-publish cycles.

**Note:** TDD rules and per-layer test conventions are in `.claude/rules/tdd-enforcement.md` (auto-loaded for `psu-app/` and `e2e/` paths).

---

## Troubleshooting (CRITICAL)

**ALWAYS use `./scripts/ciem-log.sh` to query the CIEM application log.** Do NOT hardcode paths — the script SSHs to the publish point (adam-server) to read `~/psu/data/ciem.log` by default, with a local fallback to `psu-app/data/ciem.log`.

```bash
# Recent log entries (default: 30 lines)
./scripts/ciem-log.sh

# More lines
./scripts/ciem-log.sh -n 100

# Follow log output in real-time
./scripts/ciem-log.sh -f

# Search for errors
./scripts/ciem-log.sh -g "ERROR"

# Filter by component
./scripts/ciem-log.sh -g "EnvironmentPage" -n 50

# Print the resolved log path
./scripts/ciem-log.sh --path
```

The log captures issues that PSU's own logs miss (module initialization, provider registration, schema application). If `ciem.log` doesn't explain the problem, then check PSU logs via `./scripts/download-psu-logs.sh --local`.

### Local PSU Recovery Escalation (MANDATORY ORDER)

1. `Restart-PSUApp -Name 'Devolutions CIEM'` — restart just the CIEM app
2. `ssh adam-server 'sudo launchctl kickstart -k system/com.psu.server'` — restart PSU server on adam-server
3. **STOP and ask the user** before proceeding to more destructive options

After bulk code changes, if the CIEM app shows "App is not running," investigate whether the changes broke module initialization before restarting anything. Always suppress `Connect-PSU` output when chaining commands: `$null = Connect-PSU -Local; <next command>`

---

## PowerShell Universal (PSU) Servers

### "Local" PSU Instance = adam-server (Always-On)

The "local" PSU runs on **adam-server** (Mac Mini on LAN), not on MacBook. Code is pushed to adam-server via SSH/rsync when publishing.

| Property | Value |
|----------|-------|
| **LAN URL** | `http://192.168.86.30:5001` (set in `.env` as `LOCAL_PSU_URL`) |
| **Public URL** | ngrok tunnel (use `ngrok api tunnels list` on adam-server) |
| **PSU Version** | 2026.1.0 |
| **Binary** | `~/.local/share/powershell-universal/Universal.Server` (native macOS ARM64) — on adam-server |
| **Repository** | `/Users/adam/psu/Repository` (on adam-server, pushed via SSH/rsync) |
| **Database** | `/Users/adam/Library/Application Support/PowerShellUniversal/database.db` (on adam-server) |
| **CIEM data** | `/Users/adam/psu/data/ciem.db`, `/Users/adam/psu/data/ciem.log` (on adam-server) |
| **LaunchDaemons** | `com.psu.server`, `com.ngrok.psu` (both KeepAlive) |
| **Logs** | `/var/log/psu.log`, `/var/log/ngrok-psu.log` on adam-server |

```bash
# Connect from MacBook
Connect-PSU -Local                           # Reads LOCAL_PSU_URL from .env

# Kickstart PSU on adam-server if it crashes
ssh adam-server 'sudo launchctl kickstart -k system/com.psu.server'
```

**Workflow:** Edit CIEM module on MacBook → `Publish-PSUModule -LocalOnly` pushes via SSH/rsync to adam-server → app restarts automatically.

### .env Configuration

```
LOCAL_PSU_URL=http://192.168.86.30:5001
PUBLISH_POINT_SSH=adam-server
PUBLISH_POINT_PSU_PATH=/Users/adam/psu
LOCAL_PSU_TOKEN=<any-token>  # adam-server runs in Permissive security mode
AZURE_PSU_URL=https://devolutions-ciem-psu.azurewebsites.net
AZURE_PSU_TOKEN=<azure-token>
```

`Connect-PSU` reads `AZURE_PSU_URL` by default. Use `-Local` to read `LOCAL_PSU_URL` and `LOCAL_PSU_TOKEN` from `.env`.

### Azure PSU Instance (Production)

| Property | Value |
|----------|-------|
| **URL** | https://devolutions-ciem-psu.azurewebsites.net |
| **Azure Resource Group** | `devolutions-ciem-rg` |
| **Location** | West US 2 |
| **App Service Plan** | Standard S1 (Linux) |
| **PSU Version** | 5.5.4 |
| **Container Image** | `ironmansoftware/universal:5.5.4-azure` |

### CRITICAL: Startup Time Warning

**The PSU Azure webapp is EXTREMELY SLOW.** Do NOT restart it unless absolutely necessary.

- **Cold start time:** Up to 10 minutes
- **Loading phases:** PSU loads each configuration type sequentially (Dashboard, Script, Module, Role, etc.)
- **During loading:** The `/api/v1/alive` endpoint returns `{"loading": true, "loadingInfo": "Loading configuration for X"}`

**Before restarting, consider alternatives:**
- Use `Restart-PSUApp -Name 'Devolutions CIEM'` to restart just the CIEM app (much faster)
- Use `Sync-PSUConfiguration` to reload configuration without full restart
- Test code changes via `Invoke-TestCommand` before publishing

**If you must restart:** Monitor progress with:
```bash
curl -s https://devolutions-ciem-psu.azurewebsites.net/api/v1/alive | jq '.loading, .loadingInfo'
```

### First-Time Setup

On first access, PSU will prompt you to create an admin account. Navigate to the URL above and follow the setup wizard.

**Note:** Azure config, infrastructure, file manager, logs, and troubleshooting scripts are documented in `.claude/rules/azure-infra.md` (auto-loaded for `_temp/` and `scripts/` paths) and the psu-expert agent.

---

## Known Issues

### 1. Azure PSU App Startup Must Not Register Scripts
**Symptom:** Azure `/ciem` can return HTTP 200 while the page body says `App is not running`. PSU logs can show `Failed to get dashboard. Specify a computer name or use the Connect-PSUServer command.` or `StatusCode="Cancelled"` gRPC timeout errors.
**Cause:** `New-DevolutionsCIEMApp.ps1` ran `Import-CIEMScript` from the dashboard/app startup path. PSU app startup is the dashboard render path and cannot reliably perform PSU management cmdlets such as `Get-PSUFolder`, `New-PSUFolder`, `Get-PSUScript`, or `New-PSUScript`; in Azure this fails unauthenticated or times out.
**Fix:** Keep the dashboard factory pure. Do not call `Import-CIEMScript` from `psu-app/modules/Devolutions.CIEM.PSU/Public/New-DevolutionsCIEMApp.ps1`. Run `Import-CIEMScript` as an explicit PSU management operation after `Connect-PSU`; use `Import-CIEMScript -Integrated` only from a PSU process where integrated cmdlets are verified to work.
**Verification:** Run `pwsh -NoProfile -Command "Invoke-Pester psu-app/Tests/Unit/ImportCIEMScript.Tests.ps1 -Output Detailed"`, run `Import-CIEMScript` after `Connect-PSU`, and run a Playwright browser check against `https://devolutions-ciem-psu.azurewebsites.net/ciem`; the page must show CIEM dashboard content and must not contain `App is not running`.
**Recurrence Prevention:** Keep the Pester assertion that the generated app startup script does not contain `Import-CIEMScript`. Do not add PSU management cmdlets to the app factory/startup path.

### 2. Azure PSU App Tokens Can Be Lost During Recovery
**Symptom:** `Connect-PSU` against Azure fails with HTTP 401 while `/api/v1/alive` is healthy. Publishing can succeed to PowerShell Gallery but fail during Azure import because the stored `AZURE_PSU_TOKEN` is invalid.
**Cause:** The Azure PSU database can contain zero app tokens after a recovery/reset event, invalidating the token in `.env`.
**Fix:** On the supported Azure image, set non-default `PSUDefaultAdminName` and `PSUDefaultAdminPassword` app settings from `.env`, restart the web app, wait for `/api/v1/alive` to report `loading=false`, sign in with those local admin credentials, grant a new app token, and update `.env` `AZURE_PSU_TOKEN` without printing it. Use `ResetAdminAccount=true` only as a temporary lockout recovery setting and remove it immediately after token recovery.
**Verification:** `Connect-PSU` succeeds, `Get-PSUModule` returns `Devolutions.CIEM` with the installed version, publishing can import the module into Azure, and the non-default admin credentials from `.env` can grant an app token.
**Recurrence Prevention:** If Azure `Connect-PSU` returns 401, inspect app token state before republishing. Keep `PSUDefaultAdminName` and `PSUDefaultAdminPassword` set on Azure, and do not leave `ResetAdminAccount=true` configured.

### 3. Azure PSU Get-PSUScript Name Lookup Cancels on Missing Scripts
**Symptom:** `Import-CIEMScript` can fail on Azure with `Status(StatusCode="Cancelled", Detail="No message returned from method.")` when calling `Get-PSUScript -Name` for a CIEM script that has not been registered yet.
**Cause:** Azure PSU 2026.1.5 cancels `Get-PSUScript -Name` when the script name is absent, including names such as `New-CIEMScanRun`, `DoesNotExist.ps1`, and folder-style names such as `Checks/New-CIEMScanRun`.
**Fix:** Do not use `Get-PSUScript -Name` in CIEM registration. Query `Get-PSUScript` once and match locally by normalized script name or repository path.
**Verification:** Run `pwsh -NoProfile -Command "Invoke-Pester psu-app/Tests/Unit/ImportCIEMScript.Tests.ps1 -Output Detailed"` and confirm the test asserts `Get-PSUScript` is not called with `-Name`. On Azure, `Import-CIEMScript` must return `Status = Registered` with `TotalScripts = 13`.
**Recurrence Prevention:** Keep the no-`-Name` Pester assertion in `ImportCIEMScript.Tests.ps1`; do not reintroduce named script lookups for CIEM registration.

### 4. Azure PSU 2026.1.5 Image Is Not a Supported Recovery Target
**Symptom:** A rebuilt Azure PSU instance on `ironmansoftware/universal:2026.1.5-azure` can show only a Devolutions Login first-run screen. Local admin bootstrap can return 401 for `/api/v1/accessible` and `/api/v1/apptoken/grant`, and adding `.universal/authentication.ps1` with `Set-PSUAuthenticationMethod -Type Form` can crash the container with exit code 139.
**Cause:** The 2026.1.5 Azure image changes first-run/auth behavior in a way that is not covered by the local PSU docs and blocks the documented CIEM bootstrap flow.
**Fix:** Keep the Azure CIEM PSU instance on `ironmansoftware/universal:5.5.4-azure`. If Azure keeps pulling 2026.1.5 after `linuxFxVersion` is changed, recreate the Web App with 5.5.4 as the initial image. Use `az webapp delete --keep-empty-plan` to preserve the App Service Plan; if the plan was deleted, recreate `devolutions-ciem-psu-asp` as Linux S1 in West US 2.
**Verification:** Docker logs must show `Pulling image docker.io/ironmansoftware/universal:5.5.4-azure`, `/api/v1/alive` must report `loading=false`, and `/login` must render the 5.5-era page without `?v=2026.1.5` assets.
**Recurrence Prevention:** Do not upgrade the Azure PSU container image past 5.5.4 until first-run, local-admin token grant, and CIEM module import have been tested in a separate throwaway Web App.

### 5. Local PSU Module Removal Must Delete Publish-Point Files
**Symptom:** After `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment local -Force`, local PSU can show `Devolutions.CIEM` again even though the PSU module database delete returned `Status = Removed`, or it can retain the `Devolutions CIEM` app at `/ciem` after module/script removal.
**Cause:** Local publishing installs the module under the adam-server publish point at `/Users/adam/psu/Repository/Modules/Devolutions.CIEM`. PSU adds the repository `Modules` directory to `PSModulePath`, so deleting only the PSU database entry lets PSU rediscover the module from disk. The CIEM app is a separate PSU app resource and must be removed in addition to module-owned scripts and schedules.
**Fix:** `Remove-PSUModule -Environment local` must read `PUBLISH_POINT_SSH` and `PUBLISH_POINT_PSU_PATH` from `.env`, run `ssh <publish-point> "rm -rf '<PUBLISH_POINT_PSU_PATH>/Repository/Modules/Devolutions.CIEM'"`, and then run `Sync-PSUConfiguration -Reset`. `Remove-CIEMPSUModule` must remove CIEM-owned apps, scripts, schedules, and active jobs before invoking `Remove-PSUModule`, and must pass `-Environment` and connection parameters through to `Remove-PSUModule`.
**Verification:** Run `pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path Devolutions.CIEM.Admin/Tests/Unit`, then run `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment local -Force` and verify local PSU reports module, app, script, schedule, active job, and queued job counts as `0`.
**Recurrence Prevention:** Keep the `Remove-PSUModule.Tests.ps1` local filesystem cleanup assertions and the `CIEMDeployment.Tests.ps1` assertions that `Remove-CIEMPSUModule` removes CIEM-owned apps and passes environment and env file values into `Remove-PSUModule`.

---

## Architecture Planning

The architecture planning document is at `docs/devolutions-ciem-app-architecture.md`. It covers:

- **Approach**: Native PowerShell (no Python dependency)
- **Primary Focus**: CIEM features — dormant permissions, role right-sizing, control relationships
- **Secondary**: Prowler-ported CSPM checks (retained, not the differentiator)
- **V1 Providers**: Azure + AWS
- **Distribution**: PSU Gallery module with `RequiredModules` for Az.* and AWS.Tools.*
- **PSU Integration**: PSU App with scan configuration and results viewer pages
- **Data Model**: Finding objects stored as job output (no custom tables)

`docs/ciem-feature-todos.md` is the source of truth for project purpose, expected features, product feedback, build order, and discovery/action guardrails.

Resource icons exist at `psu-app/modules/Devolutions.CIEM.PSU/Data/icons/`. The folder contains official Azure, Microsoft Entra, and AWS source packs in `source-packs/`, curated SVGs in `resources/`, and `resource-icon-map.json` for mapping CIEM resource types to icon assets.

### Key Decisions

| Aspect | Decision |
|--------|----------|
| Runtime | Pure PowerShell (no Python) |
| V1 Providers | Azure, AWS |
| Data Model Axis | Identity-first (drill identity → entitlements), not resource-first |
| Core Focus | CIEM: dormant permissions, role right-sizing, control relationships |
| CSPM Checks | Retained as secondary layer (Prowler-ported) |
| Compliance Mapping | Not in v1 |
| Historical Data | Not in v1 (snapshot per scan) |
| AD Support | Future (architected for extensibility) |
| PAM Integration | Risk-to-PAM mapping (deeper than link to docs) |



**Note:** Database CRUD convention is documented in `.claude/rules/crud-convention.md` (auto-loaded for `psu-app/` paths). Check management functions are in `.claude/rules/checks-management.md`.
