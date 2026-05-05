# Devolutions CIEM PSU Project Workflows

Source: `AGENTS.md` and `psu-expert` agent instructions.

## Local PSU

In this project, local PSU means the always-on PSU instance on `adam-server`, not the MacBook.

- LAN URL: `http://192.168.86.36:5001`
- `LOCAL_PSU_URL` and `LOCAL_PSU_TOKEN` live in `.env`
- PSU repository on adam-server: `/Users/adam/psu/Repository`
- Normal workflow: edit on the MacBook, then publish to adam-server with `Publish-PSUModule -LocalOnly`

## Azure PSU

- URL: `https://devolutions-ciem-psu.azurewebsites.net`
- Resource group: `devolutions-ciem-rg`
- Location: `West US 2`
- App Service Plan: `Standard S1 (Linux)`
- PSU version: `5.5.4`
- Container image: `ironmansoftware/universal:5.5.4-azure`

Prefer app-level restart or configuration sync before a full Azure web app restart.

## Publishing

Do not upload module files directly to Azure PSU.

Use:

```powershell
Import-Module ./Devolutions.CIEM.Admin
Publish-PSUModule -ModulePath ./psu-app -WhatIf
Publish-PSUModule -ModulePath ./psu-app
Publish-PSUModule -ModulePath ./psu-app -LocalOnly
```

Use `-LocalOnly` for adam-server via SSH/rsync and to skip PSGallery.

## Validation

TDD is mandatory before implementation or debugging changes.

Use `Invoke-TestCommand` for PSU runtime validation after tests are in place:

```powershell
Import-Module ./Devolutions.CIEM.Admin
Invoke-TestCommand -ScriptBlock { Get-CIEMProvider }
Invoke-TestCommand -ScriptBlock { Invoke-CIEMScan -Service Entra } -Environment azure
```

Inside `Invoke-TestCommand` script blocks, use runtime-visible CIEM and PSU
cmdlets only. The remote PSU job imports `Devolutions.CIEM`, not
`Devolutions.CIEM.Admin`, so use `Get-Module Devolutions.CIEM` to validate the
loaded module inside the job. Keep Admin cmdlets such as `Get-PSUModule` in the
external session before or after the runtime probe.

Use local by default. Use Azure only when explicitly validating production behavior.

## Logs and Troubleshooting

Use `./scripts/ciem-log.sh` to locate and read the active CIEM log. Do not hardcode `psu-app/data/ciem.log`.

Use these read-only tools for inspection:

- `scripts/download-psu-logs.sh`
- `scripts/azure_psu_file_manager.sh`
- `scripts/invoke_command_in_azure_webapp.sh`

Local recovery order:

1. `Restart-PSUApp -Name 'Devolutions CIEM'`
2. Restart the PSU server only if needed
3. Do not reset local PSU state without explicit user approval

## Azure File Access

Use `scripts/azure_psu_file_manager.sh` to inspect the Azure PSU filesystem via Kudu API:

```bash
./scripts/azure_psu_file_manager.sh list
./scripts/azure_psu_file_manager.sh list Repository/Modules
./scripts/azure_psu_file_manager.sh read Repository/.universal/apps.ps1
./scripts/azure_psu_file_manager.sh exec "ls -la"
```

Important paths:

- `Repository/Modules/` - installed PowerShell modules
- `Repository/.universal/` - PSU configuration files
- `Repository/dashboards/` - dashboard definitions
- `database.db` - PSU SQLite database
- `LogFiles/` - application logs

## Azure Runtime Inspection

Use `scripts/invoke_command_in_azure_webapp.sh` for commands that need shell features or PSU API access:

```bash
./scripts/invoke_command_in_azure_webapp.sh preset files
./scripts/invoke_command_in_azure_webapp.sh preset apps
./scripts/invoke_command_in_azure_webapp.sh preset modules
./scripts/invoke_command_in_azure_webapp.sh preset logs
./scripts/invoke_command_in_azure_webapp.sh preset health
./scripts/invoke_command_in_azure_webapp.sh preset version
./scripts/invoke_command_in_azure_webapp.sh api "/api/v1/dashboard"
```

Commands run in the Kudu sidecar container, which shares `/home` with the PSU app. File operations work there. Runtime state queries require the PSU REST API via the `api` command.
