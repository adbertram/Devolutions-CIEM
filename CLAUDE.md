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

## PowerShell Universal (PSU) Server

A PSU v5 server is deployed in Azure for this project.

### Access Details

| Property | Value |
|----------|-------|
| **URL** | https://devolutions-ciem-psu.azurewebsites.net |
| **Azure Resource Group** | `devolutions-ciem-rg` |
| **Location** | West US 2 |
| **App Service Plan** | Standard S1 (Linux) |
| **PSU Version** | 5.4.4 |
| **Container Image** | `ironmansoftware/universal:5.4.4-azure` |

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
# View app logs
az webapp log tail --resource-group devolutions-ciem-rg --name devolutions-ciem-psu

# Restart the app
az webapp restart --resource-group devolutions-ciem-rg --name devolutions-ciem-psu

# View app settings
az webapp config appsettings list --resource-group devolutions-ciem-rg --name devolutions-ciem-psu

# Delete all resources
az group delete --name devolutions-ciem-rg --yes
```

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
