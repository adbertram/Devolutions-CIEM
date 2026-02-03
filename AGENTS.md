# AGENTS.md

## Project Context
- CIEM solution built on PowerShell Universal (PSU).
- Devolutions employee context; PSU is owned by Devolutions.
- CIEM is a free PSU add-on; findings link users to Devolutions PAM for action.

## Mandatory PSU Research Delegation
- Any PSU feature, API, config, or troubleshooting question must be delegated to the `psu-expert` agent.
- Do not use web search or guess PSU behavior.

## Module Deployment (Critical)
- Never upload module files directly to the Azure PSU instance.
- Always publish the module via `Publish-PSUModule` from `Devolutions.CIEM/`.

```powershell
Import-Module ./scripts/PSUniversal.psm1
Publish-PSUModule -ModulePath ./Devolutions.CIEM -WhatIf
Publish-PSUModule -ModulePath ./Devolutions.CIEM
```

## PSU Server
- URL: https://devolutions-ciem-psu.azurewebsites.net
- Resource group: `devolutions-ciem-rg`
- Location: West US 2
- App Service Plan: Standard S1 (Linux)
- PSU version: 5.5.4
- Container image: `ironmansoftware/universal:5.5.4-azure`

## Troubleshooting Tools (Read-Only)
- `scripts/azure_psu_file_manager.sh` for listing/reading PSU files via Kudu.
- `scripts/invoke_command_in_azure_webapp.sh` for read-only inspection and API calls.
- `scripts/download-psu-logs.sh` to collect logs.

## Reference Docs
- Architecture planning: `docs/architecture-planning.md`
- PSU Azure hosting docs: `docs/psu-docs/config/hosting/azure.md`
