# Devolutions CIEM

## CRITICAL: Test-Driven Development (TDD) -- MANDATORY

**YOUR FIRST ACTION on ANY code change request MUST be identifying and writing tests. Do NOT read source code, do NOT explore implementation, do NOT plan changes. Go directly to test files.**

- **MUST** write tests BEFORE implementation code (red-green-refactor)
- **MUST** cover all relevant test layers (Pester for PowerShell, Playwright for UI)
- **MUST** run all relevant tests and confirm green before marking work complete
- **MUST NOT** begin investigating or fixing code before writing failing tests
- **MUST NOT** submit, commit, or declare any change "done" without passing tests
- **MUST NOT** pipe test output through filters (head, tail, grep) -- show FULL output

**SEQUENCE CHECK:** If your first tool call after a code change request is Read/Bash on a source file (not a test file), you are already violating TDD. Stop and start over with tests. A PreToolUse hook (`enforce-tdd.sh`) will DENY source code edits until test files have been touched.

**MANDATORY TDD workflow:**

1. **Identify which tests are needed** (Pester unit tests and/or Playwright E2E)
2. **Load the `testing-expert` skill BEFORE writing any test.** NEVER write a test file without loading it first.
3. **Write ALL failing tests first** -- tests MUST exist and fail before ANY implementation
4. **Then and ONLY then** begin implementation
5. **Run ALL relevant test types** before declaring done:
   - [ ] Pester tests (if PowerShell code changed): `pwsh -NoProfile -Command "Invoke-Pester psu-app/ -Output Detailed"`
   - [ ] Playwright tests (if UI pages changed): `cd psu-app/ui/e2e && npx playwright test`

**CRITICAL FOR BUG FIXES:** Do NOT jump into the code to investigate. First, write failing tests that reproduce the bug. The tests define what "fixed" means.

Detailed TDD rules, test layer conventions, and what requires tests: `.claude/rules/tdd-enforcement.md` (auto-loaded for `psu-app/` and `e2e/` paths).

---

## Default PSU Instance (CRITICAL)

**ALWAYS default to the LOCAL PSU instance** (`http://localhost:5001`) for all operations unless the user explicitly says "Azure" or "production". This applies to:

- **Opening PSU:** Open `http://localhost:5001`, not the Azure URL
- **Publishing modules:** Use `Publish-PSUModule -LocalOnly` (not the default Azure publish)
- **Testing commands:** Use `-Environment local` (default) or `-Environment azure`
- **File manager / log scripts:** Use `--local` flag
- **`Connect-PSU`:** Use `Connect-PSU -Local`

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

**With `-LocalOnly`:** Skips steps 2-5, connects to local PSU via `Connect-PSU -Local`, and imports the module directly.

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

**ALWAYS use `./scripts/ciem-log.sh` to query the CIEM application log.** Do NOT hardcode `psu-app/data/ciem.log` — the actual log location depends on where PSU loaded the module from (working copy vs published module in `local-psu/Repository/Modules/`). The script finds the most recently modified `ciem.log` automatically.

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
2. `./scripts/setup-local-psu.sh stop && ./scripts/setup-local-psu.sh start` — restart PSU server
3. **STOP and ask the user** before proceeding to more destructive options
4. **NEVER run `setup-local-psu.sh reset` without explicit user approval** — it destroys all local PSU state (license, tokens, app registrations, dev mode settings) and requires full manual re-setup

After bulk code changes, if the CIEM app shows "App is not running," investigate whether the changes broke module initialization before restarting anything. Always suppress `Connect-PSU` output when chaining commands: `$null = Connect-PSU -Local; <next command>`

---

## PowerShell Universal (PSU) Servers

### Local PSU Instance (Development)

| Property | Value |
|----------|-------|
| **URL** | http://localhost:5001 |
| **PSU Version** | 2026.1.0 |
| **Binary** | `~/.local/share/powershell-universal/Universal.Server` (native macOS ARM64) |
| **Data** | `local-psu/` (gitignored) |
| **Database** | `local-psu/database.db` (SQLite) |

```bash
# Start/stop local PSU
./scripts/setup-local-psu.sh start          # Start and wait for ready
./scripts/setup-local-psu.sh start --no-wait  # Start without waiting
./scripts/setup-local-psu.sh stop            # Stop
./scripts/setup-local-psu.sh status          # Check health
./scripts/setup-local-psu.sh logs -f         # Follow logs
./scripts/setup-local-psu.sh reset           # Wipe all data and start fresh

# Connect from PowerShell
Connect-PSU -Local                           # Uses LOCAL_PSU_URL from .env
```

### .env Configuration

```
PROD_PSU_URL=https://devolutions-ciem-psu.azurewebsites.net
LOCAL_PSU_URL=http://localhost:5001
PSU_TOKEN=<production-token>  # Local PSU runs in dev mode (no auth needed)
```

`Connect-PSU` reads `PROD_PSU_URL` by default. Use `-Local` to connect to `LOCAL_PSU_URL`.

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

## Architecture Planning

The architecture planning document is at `docs/devolutions-ciem-app-architecture.md`. It covers:

- **Approach**: Native PowerShell (no Python dependency)
- **Primary Focus**: CIEM features — dormant permissions, role right-sizing, control relationships
- **Secondary**: Prowler-ported CSPM checks (retained, not the differentiator)
- **V1 Providers**: Azure + AWS
- **Distribution**: PSU Gallery module with `RequiredModules` for Az.* and AWS.Tools.*
- **PSU Integration**: PSU App with scan configuration and results viewer pages
- **Data Model**: Finding objects stored as job output (no custom tables)

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
