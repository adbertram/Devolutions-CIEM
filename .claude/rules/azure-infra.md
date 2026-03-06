---
description: Azure infrastructure and PSU deployment reference
paths: ["_temp/**", "scripts/**"]
---

# Azure PSU Infrastructure

## Azure Configuration

Environment variables configured on the Azure App Service:

- `WEBSITES_ENABLE_APP_SERVICE_STORAGE=true` - Persistent storage for `/home`
- `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` - Reverse proxy header handling
- `Jwt__SigningKey` - Secure JWT signing key (auto-generated)
- `Api__Url` - Set to the app's public URL
- `NodeName` - Set to `devolutions-ciem-psu`

## Infrastructure Deployment

The Bicep template is at `_temp/psu-deploy.bicep`.

```bash
# Generate new JWT key and deploy
JWT_KEY=$(openssl rand -base64 48 | tr -d '\n')
az deployment group create \
  --resource-group devolutions-ciem-rg \
  --template-file _temp/psu-deploy.bicep \
  --parameters jwtSigningKey="$JWT_KEY" servicePlanPricingTier="S1"

# Update PSU version
az deployment group create \
  --resource-group devolutions-ciem-rg \
  --template-file _temp/psu-deploy.bicep \
  --parameters jwtSigningKey="$JWT_KEY" version="5.5.0"
```

## Management Commands

```bash
az webapp restart --resource-group devolutions-ciem-rg --name devolutions-ciem-psu
az webapp config appsettings list --resource-group devolutions-ciem-rg --name devolutions-ciem-psu
az group delete --name devolutions-ciem-rg --yes
```

## PSU File Manager

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
```

**Key PSU paths:** `Repository/Modules/`, `Repository/.universal/`, `Repository/dashboards/`, `database.db`, `LogFiles/`

**Note:** The `exec` command runs in the Kudu sidecar container (Debian), not the PSU container.

## Azure Web App Logs

Use the `azlogs` CLI tool:

```bash
azlogs packages download --app devolutions-ciem-psu --resource-group devolutions-ciem-rg
azlogs packages list
azlogs packages parse <package-name>
azlogs entries list <package-name> --filter "level=ERROR"
azlogs report generate <package-name>
```

## PSU Log Script

```bash
./scripts/download-psu-logs.sh          # Azure (default)
./scripts/download-psu-logs.sh --local  # Local PSU
grep -i "CIEM" psu-logs-*.log
```

## PSU Troubleshooting Script

```bash
./scripts/invoke_command_in_azure_webapp.sh run "ls -la /home/Repository"
./scripts/invoke_command_in_azure_webapp.sh preset health
./scripts/invoke_command_in_azure_webapp.sh preset modules
./scripts/invoke_command_in_azure_webapp.sh api "/api/v1/dashboard"
./scripts/invoke_command_in_azure_webapp.sh --local preset health
```

**Architecture note:** Azure commands run in the Kudu sidecar container. Local commands run against `local-psu/`.
