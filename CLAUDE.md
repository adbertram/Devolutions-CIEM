# Devolutions CIEM

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

- **Role**: Devolutions employee, PSU developer (not a PSU user/customer)
- **PSU Ownership**: PowerShell Universal is owned by Devolutions (acquired from Ironman Software)

### CIEM Business Model

Key context from discussions with Marc-André Moreau:

- **Distribution**: PSU app published to the PSU Gallery (not standalone deployment)
- **Business Model**: Free add-on for PSU customers (no additional cost beyond PSU license)
- **Strategic Purpose**: Lead generation for Devolutions PAM solution; CIEM is a Gartner inclusion criteria for PAM
- **Differentiation**: CIEM is niche and valuable — CSPM is a commodity already bundled free in cloud platforms
- **Action Flow**: CIEM identifies findings → users are redirected to Devolutions PAM to take action

### CSPM vs CIEM Positioning (CRITICAL)

Per Marc-André's demo review: the initial implementation was CSPM (CIS best-practice checks), not true CIEM. The project must focus on **CIEM-specific features** that differentiate from free tools:

- **Dormant permission detection** — Users/service principals with unused privileged roles (via sign-in logs)
- **Role right-sizing** — Propose least-privilege custom roles to replace overly broad assignments
- **Control relationship discovery** — Map identity-to-resource relationships and surface attack paths
- **Risk-to-PAM mapping** — Connect findings to Devolutions PAM privileged roles

Existing Prowler-ported CSPM checks are retained as a secondary feature but are NOT the differentiator.

### Slack Context

Primary stakeholder conversation is with **Marc-André Moreau** (`mamoreau`) in the Devolutions Slack workspace.

To retrieve conversation history:

```bash
# Switch to Devolutions workspace and read DMs
slack workspace switch devolutions
slack dm read mamoreau --limit 50
```

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

## Test-Driven Development (CRITICAL)

**EVERY code change MUST have a corresponding test. No exceptions.** Tests are the cornerstone of all development. Changes without tests will be rejected.

### TDD Workflow (MANDATORY)

1. **Write/update tests FIRST** — before implementing the feature or fix
2. **Run tests to confirm they fail** — validates the test actually tests what you think
3. **Implement the change** — make the failing tests pass
4. **Run full test suite** — ensure no regressions

### Two Test Layers

| Layer | Framework | Location | Scope | Run Command |
|-------|-----------|----------|-------|-------------|
| **Pester** (unit/integration) | Pester v5 | `psu-app/**/Tests/*.Tests.ps1` | PowerShell functions, CRUD, classes, module structure | `Invoke-Pester <path> -Output Detailed` |
| **Playwright** (E2E) | Playwright | `psu-app/ui/e2e/pages/**/*.test.js` | PSU UI pages, navigation, user workflows | `cd psu-app/ui/e2e && npx playwright test` |

### What Requires Tests

- **New function** → Pester tests for all parameter sets, edge cases, and return types
- **New CRUD table** → Full CRUD test file (New/Get/Update/Save/Remove) per `.claude/rules/crud-convention.md`
- **Bug fix** → Test that reproduces the bug BEFORE the fix, passes AFTER
- **UI page change** → Playwright test covering the changed behavior
- **Refactor** → Existing tests must still pass; add tests if coverage gaps exist

### Test Quality Rules

- **Use `pester-test-reviewer` agent** to validate Pester test structure before committing
- **Never skip failing tests** — fix the implementation, not the test
- **Tests document expected behavior** — only update tests when requirements change
- **0 failures, 0 errors** = passing. ERROR is a failure, not a skip.

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
| Core Focus | CIEM: dormant permissions, role right-sizing, control relationships |
| CSPM Checks | Retained as secondary layer (Prowler-ported) |
| Compliance Mapping | Not in v1 |
| Historical Data | Not in v1 (snapshot per scan) |
| AD Support | Future (architected for extensibility) |
| PAM Integration | Risk-to-PAM mapping (deeper than link to docs) |



**Note:** Database CRUD convention is documented in `.claude/rules/crud-convention.md` (auto-loaded for `psu-app/` paths). Check management functions are in `.claude/rules/checks-management.md`.
