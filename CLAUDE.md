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

## PSU Research Delegation (MANDATORY)

**ALL PowerShell Universal research tasks MUST be delegated to the `psu-expert` agent.**

Do NOT attempt to answer PSU questions by:
- Using WebSearch to find PSU documentation
- Using microsoft_docs_search or other MCP tools
- Guessing based on general PowerShell knowledge

Instead, invoke the psu-expert agent via the Task tool. The psu-expert has:
- Local PSU v5 documentation at `docs/psu-docs/`
- Access to the Azure PSU server filesystem
- Deep knowledge of PSU APIs, cmdlets, and configuration

**Examples of questions to delegate:**
- "How do I programmatically import modules in PSU?"
- "What REST API endpoints does PSU provide?"
- "How do I configure PSU app authentication?"
- "Why isn't my PSU dashboard loading?"

**When to delegate:** Any question about PSU features, APIs, configuration, troubleshooting, or best practices.

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

## Check Management Functions

Development-only functions for managing CIEM checks, syncing Prowler checks, and provisioning Azure infrastructure. These are exported from the Checks module (`psu-app/modules/Devolutions.CIEM.Checks/`) and available after importing `Devolutions.CIEM`.

### Prowler Sync & Check Management

| Function | Purpose |
|----------|---------|
| `Sync-ProwlerCheck` | Sync Prowler checks from GitHub (sparse checkout) |
| `Get-ProwlerCheck` | List/filter Prowler checks from the upstream repo |
| `Enable-CIEMCheck` | Enable a check (set disabled flag to false) |
| `Disable-CIEMCheck` | Disable a check (set disabled flag to true) |
| `Compare-ProwlerCheck` | Diff upstream Prowler checks vs local CIEM checks |
| `Convert-ProwlerCheck` | Convert a Prowler check directory to CIEM format |

### Azure Infrastructure Provisioning

| Function | Purpose |
|----------|---------|
| `New-CIEMAzureManagedIdentity` | Configure Azure managed identity with CIEM permissions |
| `New-PSUAzureServicePrincipal` | Create Azure service principal for PSU |

### When to Use

- **Adding/removing/syncing checks:** `Sync-ProwlerCheck`, `Enable-CIEMCheck`, `Disable-CIEMCheck`
- **Querying check metadata:** `Get-CIEMCheck -Provider Azure -Service Entra`
- **Checking required permissions:** `Get-CIEMRequiredPermission -Service KeyVault`
- **Provisioning Azure resources:** `New-CIEMAzureManagedIdentity`, `New-PSUAzureServicePrincipal`

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

**Always test before publishing.** Use `local` (default) for development, `azure` to validate in production.

---

## Troubleshooting (CRITICAL)

**ALWAYS check `psu-app/data/ciem.log` FIRST** when debugging any CIEM issue. This file contains boot-time errors, module load failures, and all `Write-CIEMLog` output.

```bash
# Check recent log entries
tail -50 psu-app/data/ciem.log

# Search for errors
grep -i "error\|exception\|fail" psu-app/data/ciem.log
```

The log captures issues that PSU's own logs miss (module initialization, provider registration, schema application). If `ciem.log` doesn't explain the problem, then check PSU logs via `./scripts/download-psu-logs.sh --local`.

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

### Azure Configuration

The following environment variables are configured:

- `WEBSITES_ENABLE_APP_SERVICE_STORAGE=true` - Persistent storage for `/home`
- `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` - Reverse proxy header handling
- `Jwt__SigningKey` - Secure JWT signing key (auto-generated)
- `Api__Url` - Set to the app's public URL
- `NodeName` - Set to `devolutions-ciem-psu`

### Infrastructure

The Bicep template used for deployment is located at `_temp/psu-deploy.bicep`.

To redeploy or update:

```bash
# Generate new JWT key and deploy
JWT_KEY=$(openssl rand -base64 48 | tr -d '\n')
az deployment group create \
  --resource-group devolutions-ciem-rg \
  --template-file _temp/psu-deploy.bicep \
  --parameters jwtSigningKey="$JWT_KEY" servicePlanPricingTier="S1"
```

To update PSU version, modify the `version` parameter:

```bash
az deployment group create \
  --resource-group devolutions-ciem-rg \
  --template-file _temp/psu-deploy.bicep \
  --parameters jwtSigningKey="$JWT_KEY" version="5.5.0"
```

### Management Commands

```bash
# Restart the app
az webapp restart --resource-group devolutions-ciem-rg --name devolutions-ciem-psu

# View app settings
az webapp config appsettings list --resource-group devolutions-ciem-rg --name devolutions-ciem-psu

# Delete all resources
az group delete --name devolutions-ciem-rg --yes
```

### PSU File Manager

Use `scripts/azure_psu_file_manager.sh` to access the PSU server filesystem. Supports `--local` for local PSU.

```bash
# Azure (default)
./scripts/azure_psu_file_manager.sh list                    # Root (maps to /home)
./scripts/azure_psu_file_manager.sh list Repository/Modules # PSU modules
./scripts/azure_psu_file_manager.sh read Repository/.universal/apps.ps1
./scripts/azure_psu_file_manager.sh exec "ls -la"

# Local PSU
./scripts/azure_psu_file_manager.sh --local list
./scripts/azure_psu_file_manager.sh --local list Repository/Modules
./scripts/azure_psu_file_manager.sh --local read Repository/.universal/dashboards.ps1
```

**Key PSU paths:**
- `Repository/Modules/` - Installed PowerShell modules
- `Repository/.universal/` - PSU configuration files
- `Repository/dashboards/` - Dashboard definitions
- `database.db` - PSU SQLite database
- `LogFiles/` - Application logs

**Note:** The `exec` command runs in the Kudu sidecar container (Debian), not the PSU container. Use `list` and `read` commands to inspect PSU files.

### Azure Web App Logs

Use the `azlogs` CLI tool (installed globally) to download and analyze Azure Web App logs (platform, container, application, Kudu). The original `scripts/azure_webapp_log_downloader/` was ported to this CLI.

```bash
# Download a full log package from Azure
azlogs packages download --app devolutions-ciem-psu --resource-group devolutions-ciem-rg

# List downloaded packages
azlogs packages list

# Parse and merge logs into searchable JSONL
azlogs packages parse <package-name>

# Search parsed entries
azlogs entries list <package-name> --filter "level=ERROR"

# Generate HTML report
azlogs report generate <package-name>
```

### PSU Log Script

Use `scripts/download-psu-logs.sh` to download logs. Supports `--local` for local PSU.

```bash
# Azure (default)
./scripts/download-psu-logs.sh
./scripts/download-psu-logs.sh my-logs.log

# Local PSU
./scripts/download-psu-logs.sh --local

# Then search locally with grep
grep -i "CIEM" psu-logs-*.log
grep -i "error" psu-logs-*.log
```

**Log sources downloaded:**
| Source | Content | Format |
|--------|---------|--------|
| Database | App-level logs (`[App-*]` messages) | `[timestamp] [Level] [App-Name] Message` |
| Docker | Azure container stdout (ASP.NET Core) | Infrastructure logs |
| API | PSU `/api/v1/log` endpoint | Infrastructure logs |

**Note:** Database logs are the most useful for debugging app startup issues - they show `[App-Devolutions CIEM]` errors.

### PSU Troubleshooting Script

Use `scripts/invoke_command_in_azure_webapp.sh` for troubleshooting. Supports `--local` for local PSU.

```bash
# Azure (default)
./scripts/invoke_command_in_azure_webapp.sh run "ls -la /home/Repository"
./scripts/invoke_command_in_azure_webapp.sh preset health
./scripts/invoke_command_in_azure_webapp.sh preset modules
./scripts/invoke_command_in_azure_webapp.sh api "/api/v1/dashboard"

# Local PSU
./scripts/invoke_command_in_azure_webapp.sh --local preset health
./scripts/invoke_command_in_azure_webapp.sh --local preset modules
./scripts/invoke_command_in_azure_webapp.sh --local run "ls -la Repository"
```

**Architecture note:** Azure commands run in the Kudu sidecar container. Local commands run against the `local-psu/` directory.

### Documentation

Full PSU v5 documentation for Azure hosting is available at `docs/psu-docs/config/hosting/azure.md`.

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

---

## Database CRUD Convention (MANDATORY)

**Every database table MUST have a corresponding class and full CRUD functions.**

### Required per table

1. **Class** — In the owning module's `Classes/` directory. Properties match table columns (PascalCase).
2. **New-CIEM[Azure]<Entity>** — INSERT. Fails if record exists. Returns created object.
3. **Get-CIEM[Azure]<Entity>** — SELECT with optional filter parameters. Returns `[ClassName[]]`.
4. **Update-CIEM[Azure]<Entity>** — UPDATE partial fields via `$PSBoundParameters.ContainsKey`. Supports `-PassThru`.
5. **Save-CIEM[Azure]<Entity>** — INSERT OR REPLACE (upsert). Fire-and-forget for bulk operations.
6. **Remove-CIEM[Azure]<Entity>** — DELETE with `SupportsShouldProcess`. Supports `-Id`, `-ProviderId` (bulk), and `-InputObject`.

### Parameter set pattern

Every write function (New/Update/Save/Remove) must have two parameter sets:
- **ByProperties** — Individual typed parameters for each column
- **InputObject** — Accepts `[ClassName[]]` (array) with `ValueFromPipeline` for pipeline and bulk support

### Naming

- Base module tables: `Verb-CIEM<Entity>` (e.g., `New-CIEMCheck`)
- Azure module tables: `Verb-CIEMAzure<Entity>` (e.g., `New-CIEMAzureSecurityPrincipal`)
- AWS module tables: `Verb-CIEMAWS<Entity>` (future)

### When adding a new table

1. Add schema to the appropriate `Data/*.sql` file
2. Create the class in `Classes/`
3. Create all 5 CRUD functions in `Public/`
4. Add functions to the module's `.psd1` `FunctionsToExport`
5. If the table is provider-specific collected data, integrate with the provider's `Save/Get-CIEMCollectedData`
