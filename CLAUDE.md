# Devolutions CIEM

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
- **Action Flow**: CIEM identifies findings → users are redirected to Devolutions PAM to take action

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
# Load the PSU management module
Import-Module ./scripts/PSUniversal.psm1

# WRONG - Never do this
./scripts/azure_psu_file_manager.sh upload Devolutions.CIEM/ Repository/Modules/

# CORRECT - Use Publish-PSUModule (auto-connects to PSU and imports the module)
Publish-PSUModule -ModulePath ./Devolutions.CIEM -WhatIf  # Dry run first
Publish-PSUModule -ModulePath ./Devolutions.CIEM          # Publish and auto-import to PSU
```

**What Publish-PSUModule does:**
1. Validates module structure
2. Queries PSGallery for current version
3. Auto-bumps version (Patch by default, use `-BumpVersion Minor|Major`)
4. Publishes to PowerShell Gallery
5. Verifies publication
6. Auto-connects to PSU (reads PSU_URL/PSU_TOKEN from .env)
7. Imports the new version to PSU

**Why:** The PSU Gallery is the distribution mechanism. Direct uploads bypass version control, break the upgrade path for users, and don't follow the intended distribution model.

**Note:** The file manager scripts (`azure_psu_file_manager.sh`, `invoke_command_in_azure_webapp.sh`) are for **troubleshooting and inspection only** - never for deploying module code.

---

## PowerShell Universal (PSU) Server

A PSU v5 server is deployed in Azure for this project.

### Access Details

| Property | Value |
|----------|-------|
| **URL** | https://devolutions-ciem-psu.azurewebsites.net |
| **Azure Resource Group** | `devolutions-ciem-rg` |
| **Location** | West US 2 |
| **App Service Plan** | Standard S1 (Linux) |
| **PSU Version** | 5.5.4 |
| **Container Image** | `ironmansoftware/universal:5.5.4-azure` |

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

Use `scripts/azure_psu_file_manager.sh` to access the PSU server filesystem via Kudu API:

```bash
# List directories
./scripts/azure_psu_file_manager.sh list                    # Root (maps to /home)
./scripts/azure_psu_file_manager.sh list Repository/Modules # PSU modules

# Read files
./scripts/azure_psu_file_manager.sh read Repository/.universal/apps.ps1

# Execute shell commands (runs in Kudu container, not PSU container)
./scripts/azure_psu_file_manager.sh exec "ls -la"
```

**Key PSU paths:**
- `Repository/Modules/` - Installed PowerShell modules
- `Repository/.universal/` - PSU configuration files
- `Repository/dashboards/` - Dashboard definitions
- `database.db` - PSU SQLite database
- `LogFiles/` - Application logs

**Note:** The `exec` command runs in the Kudu sidecar container (Debian), not the PSU container. Use `list` and `read` commands to inspect PSU files.

### PSU Log Script

Use `scripts/download-psu-logs.sh` to download logs from all PSU sources:

```bash
# Download all logs to timestamped file
./scripts/download-psu-logs.sh

# Download to specific file
./scripts/download-psu-logs.sh my-logs.log

# Then search locally with grep
grep -i "CIEM" psu-logs-*.log
grep -i "error" psu-logs-*.log
grep -i "authentication" psu-logs-*.log
```

**Log sources downloaded:**
| Source | Content | Format |
|--------|---------|--------|
| Database | App-level logs (`[App-*]` messages) | `[timestamp] [Level] [App-Name] Message` |
| Docker | Azure container stdout (ASP.NET Core) | Infrastructure logs |
| API | PSU `/api/v1/log` endpoint | Infrastructure logs |

**Note:** Database logs are the most useful for debugging app startup issues - they show `[App-Devolutions CIEM]` errors.

### PSU Troubleshooting Script

Use `scripts/invoke_command_in_azure_webapp.sh` for troubleshooting the PSU web app:

```bash
# Run shell commands (via Kudu - shares /home filesystem with app)
./scripts/invoke_command_in_azure_webapp.sh run "ls -la /home/Repository"
./scripts/invoke_command_in_azure_webapp.sh run "cat /home/LogFiles/*.log | tail -50"

# Use presets for common troubleshooting tasks
./scripts/invoke_command_in_azure_webapp.sh preset files      # List PSU config files
./scripts/invoke_command_in_azure_webapp.sh preset apps       # Show apps.ps1 config
./scripts/invoke_command_in_azure_webapp.sh preset modules    # List installed modules
./scripts/invoke_command_in_azure_webapp.sh preset logs       # Show recent logs
./scripts/invoke_command_in_azure_webapp.sh preset health     # Check PSU health endpoint
./scripts/invoke_command_in_azure_webapp.sh preset version    # Get PSU version via API

# Query PSU REST API (requires PSU_APP_TOKEN)
export PSU_APP_TOKEN="your-token-here"
./scripts/invoke_command_in_azure_webapp.sh api "/api/v1/dashboard"

# Interactive SSH (if enabled in container)
./scripts/invoke_command_in_azure_webapp.sh ssh
```

**Architecture note:** Commands run in the Kudu sidecar container, which shares the `/home` filesystem with the PSU app container. File operations work, but runtime state queries (loaded modules, running jobs) require the PSU REST API.

### Documentation

Full PSU v5 documentation for Azure hosting is available at `docs/psu-docs/config/hosting/azure.md`.

---

## Architecture Planning

The architecture planning document is at `docs/architecture-planning.md`. It covers:

- **Approach**: Native PowerShell port of Prowler identity checks (no Python dependency)
- **V1 Scope**: Azure + AWS identity-focused checks only
- **Distribution**: PSU Gallery module with `RequiredModules` for Az.* and AWS.Tools.*
- **PSU Integration**: PSU App with scan configuration and results viewer pages
- **Data Model**: Finding objects stored as job output (no custom tables)

### Key Decisions

| Aspect | Decision |
|--------|----------|
| Runtime | Pure PowerShell (no Python) |
| V1 Providers | Azure, AWS |
| Check Focus | Identity/entitlement only |
| Compliance Mapping | Not in v1 |
| Historical Data | Not in v1 (snapshot per scan) |
| AD Support | Future (architected for extensibility) |
| PAM Integration | Link to docs only (placeholder) |
