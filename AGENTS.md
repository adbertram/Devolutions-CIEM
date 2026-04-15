# AGENTS.md

## Project Context
- CIEM solution built on PowerShell Universal (PSU).
- PSU is owned by Devolutions.
- CIEM is distributed as a PSU Gallery add-on, not a standalone deployment.
- CIEM is a free PSU Gallery add-on that identifies findings and routes users to Devolutions PAM for action.
- The product direction is **identity-first CIEM**, not generic CSPM. Prioritize entitlements, dormant permissions, role right-sizing, and control relationships. Prowler-ported CSPM checks are secondary.

## Mandatory PSU Delegation
- Any PSU feature, API, config, publishing, restart, troubleshooting, or other PSU-specific question or operation must go through the `psu-expert` agent.
- Do not use web search or guess PSU behavior.

## PSU Instances
### Local PSU
- "Local" means the always-on PSU instance on `adam-server`, not the MacBook.
- Normal workflow is edit on MacBook, then `Publish-PSUModule -LocalOnly` pushes via SSH/rsync to adam-server.
- LAN URL: `http://192.168.86.30:5001` (set as `LOCAL_PSU_URL` in `.env`)
- `Connect-PSU -Local` reads `LOCAL_PSU_URL` and `LOCAL_PSU_TOKEN` from `.env`.
- PSU Repository on adam-server: `/Users/adam/psu/Repository` (pushed via SSH, not Dropbox-synced).

### Azure PSU
- URL: `https://devolutions-ciem-psu.azurewebsites.net`
- Resource group: `devolutions-ciem-rg`
- Location: `West US 2`
- App Service Plan: `Standard S1 (Linux)`
- PSU version: `5.5.4`
- Container image: `ironmansoftware/universal:5.5.4-azure`
- Azure restarts are slow. Prefer app-level restart or configuration sync before a full webapp restart.

## Module Deployment
- Never upload module files directly to the Azure PSU instance.
- Local publishing is automated by the `auto-publish-psu` Stop hook after `psu-app/` changes.

```powershell
Import-Module ./Devolutions.CIEM.Admin
Publish-PSUModule -ModulePath ./psu-app -WhatIf
Publish-PSUModule -ModulePath ./psu-app
Publish-PSUModule -ModulePath ./psu-app -LocalOnly
```

- Use `-LocalOnly` to push to adam-server via SSH/rsync (skips PSGallery).
- `scripts/azure_psu_file_manager.sh` and `scripts/invoke_command_in_azure_webapp.sh` are for inspection only, not deployment.

## Testing and Validation
- Use `Invoke-TestCommand` to validate CIEM code inside PSU instead of publish-debug-publish cycles.

```powershell
Import-Module ./Devolutions.CIEM.Admin
Invoke-TestCommand -ScriptBlock { Get-CIEMProvider }
Invoke-TestCommand -ScriptBlock { Invoke-CIEMScan -Service Entra } -Environment azure
```

- Use `local` by default and `azure` only when explicitly validating production behavior.

## Troubleshooting
- Always use `./scripts/ciem-log.sh` to locate and read the active CIEM log. Do not hardcode `psu-app/data/ciem.log`.
- Read-only tooling:
  - `scripts/azure_psu_file_manager.sh`
  - `scripts/invoke_command_in_azure_webapp.sh`
  - `scripts/download-psu-logs.sh`
- Local recovery order:
  1. `Restart-PSUApp -Name 'Devolutions CIEM'`
  2. Restart the PSU server only if needed
  3. Do not reset local PSU state without explicit user approval

## Reference Docs
- Architecture planning: `docs/devolutions-ciem-app-architecture.md`
- CIEM feature ideas: `docs/ciem-discovery-feature-ideas.md` - consult this when looking for new CIEM feature ideas. Discovery ideas are read-only by default; write/action ideas require explicit re-scoping before implementation.
- Resource icons: `psu-app/modules/Devolutions.CIEM.PSU/Data/icons/` contains official Azure, Entra, and AWS icon source packs, curated SVGs in `resources/`, and `resource-icon-map.json` for CIEM resource type mappings.
- PSU Azure hosting docs: `docs/psu-docs/config/hosting/azure.md`
