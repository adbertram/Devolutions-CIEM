<overview>
These are the repo-local tools for Azure PSU instance inspection. Use them in
this order: diagnostics report first, then the smallest additional tool that can
answer the remaining question.
</overview>

<tool name="azure-psu-diagnostics">
Path: `scripts/azure-psu-diagnostics.ps1`

Purpose:
- one deterministic Azure PSU preflight and triage report
- combines ARM, Kudu, PSU runtime, auth-profile, token, module, and log signal

Default command:

```powershell
pwsh -NoProfile -File scripts/azure-psu-diagnostics.ps1 -Json
```
</tool>

<tool name="download-psu-logs">
Path: `scripts/download-psu-logs.sh`

Purpose:
- collect a fuller Azure log package when the diagnostics report shows runtime
  failure or when Kudu log excerpts are insufficient

Azure command:

```bash
./scripts/download-psu-logs.sh --azure
```

After download, search locally:

```bash
grep -i "CIEM\|error\|exception\|authentication" _temp/psu-logs-*.log
```
</tool>

<tool name="invoke-command-in-azure-webapp">
Path: `scripts/invoke_command_in_azure_webapp.sh`

Purpose:
- run read-only Kudu-sidecar shell commands
- query PSU REST API endpoints from outside the app container

Recommended presets:

```bash
./scripts/invoke_command_in_azure_webapp.sh preset health
./scripts/invoke_command_in_azure_webapp.sh preset version
./scripts/invoke_command_in_azure_webapp.sh preset apps
./scripts/invoke_command_in_azure_webapp.sh preset modules
./scripts/invoke_command_in_azure_webapp.sh preset logs
./scripts/invoke_command_in_azure_webapp.sh api "/api/v1/dashboard"
```

Important boundary:
- `run` executes in the Kudu sidecar, not inside the PSU process
- do not use the `env` preset as standard repo workflow
</tool>

<tool name="azure-psu-file-manager">
Path: `scripts/azure_psu_file_manager.sh`

Purpose:
- inspect Azure PSU files through the Kudu VFS and command APIs

Examples:

```bash
./scripts/azure_psu_file_manager.sh list
./scripts/azure_psu_file_manager.sh list Repository/Modules
./scripts/azure_psu_file_manager.sh read Repository/.universal/apps.ps1
./scripts/azure_psu_file_manager.sh exec "ls -la /home/Repository"
```

Important boundary:
- inspection only
- never use it as a deployment path for module files
</tool>

<tool name="psu-runtime-checks">
Path: `Devolutions.CIEM.Admin` module commands

Purpose:
- verify what PSU itself sees after health is established

Examples:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; $null = Connect-PSU; Get-PSUInformation | Select-Object Version; Get-PSUApp -Name '*CIEM*' | Select-Object Id, Name, BaseUrl; Get-PSUModule -Name 'Devolutions.CIEM' | Sort-Object Version -Descending | Select-Object -First 1 Name, Version, Path"
```

Combined runtime probe example:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Invoke-TestCommand -Environment azure -TimeoutSeconds 300 -ScriptBlock { Get-Module Devolutions.CIEM | Select-Object Name, Version, Path; @(Get-CIEMAzureAuthenticationProfile | Select-Object Id, Name, Method, IsActive); @(Get-PSUJob -First 10 -OrderDirection Descending -HideChildren $true -HideScheduled $true -HideTriggered $true | Select-Object Id, Script, Status, StartTime, EndTime, Duration, HasErrors, HasWarnings) }"
```

Rule:
- combine related runtime checks into one `Invoke-TestCommand` call
</tool>

<unsafe_patterns>
Do not use these as normal Azure PSU triage patterns:

- broad Azure test reruns before preflight
- direct sqlite edits to PSU `database.db`
- raw environment dumps
- raw PSU job-object dumps
- direct module-file uploads to Azure PSU
</unsafe_patterns>
