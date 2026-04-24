<required_reading>
- [references/source-of-truth.md](../references/source-of-truth.md)
- [references/instance-baseline.md](../references/instance-baseline.md)
- [references/diagnostics-report.md](../references/diagnostics-report.md)
- [references/inspection-tools.md](../references/inspection-tools.md)
- [references/known-issues.md](../references/known-issues.md)
</required_reading>

<process>
<step_1>
Classify the reported symptom before changing anything:

| Symptom | Primary suspicion |
|---------|-------------------|
| `/api/v1/alive` bad, page unavailable, `loading=true` | PSU runtime or cold start |
| `Connect-PSU` 401 while `alive` is healthy | token or auth drift |
| `App is not running` with HTTP 200 | app startup path or script registration issue |
| ARM or Kudu calls fail while runtime checks work | Azure or Kudu control plane |
| Azure tests fail broadly before app-level assertions | instance state, auth profile, variables, or runtime drift |
</step_1>

<step_2>
Inspect `_temp/azure-psu-diagnostics.log` first. If it does not answer the
current incident, rerun:

```powershell
pwsh -NoProfile -File scripts/azure-psu-diagnostics.ps1 -Json
```

Use the report to decide which failure plane is broken.
</step_2>

<step_3>
Choose the smallest next tool that matches the failure plane.

Azure or Kudu control plane:

```bash
./scripts/invoke_command_in_azure_webapp.sh preset health
./scripts/invoke_command_in_azure_webapp.sh preset version
./scripts/invoke_command_in_azure_webapp.sh preset apps
./scripts/invoke_command_in_azure_webapp.sh preset modules
./scripts/invoke_command_in_azure_webapp.sh preset logs
./scripts/azure_psu_file_manager.sh read Repository/.universal/apps.ps1
```

PSU runtime:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; $null = Connect-PSU; Get-PSUInformation | Select-Object Version; Get-PSUApp -Name '*CIEM*' | Select-Object Id, Name, BaseUrl; Get-PSUModule -Name 'Devolutions.CIEM' | Sort-Object Version -Descending | Select-Object -First 1 Name, Version, Path"
```

Fuller logs:

```bash
./scripts/download-psu-logs.sh --azure
```
</step_3>

<step_4>
Handle the common high-value branches explicitly.

401 with healthy `alive`:
- check `AppTokens.Count`
- check auth profiles and required variables in the diagnostics runtime section
- use [references/known-issues.md](../references/known-issues.md) for token-loss
  recovery; do not print token values

`App is not running`:
- inspect `apps.ps1`, module presence, and startup script generation
- verify the app startup path is not registering PSU scripts

Wrong image or broken first-run auth:
- check `LinuxFxVersion`
- if it is not `ironmansoftware/universal:5.5.4-azure`, treat that as a
  primary root cause

Broad Azure suite failures:
- stop rerunning broad suites
- confirm instance preflight, active auth profile, required variables, module
  load, and recent PSU job state first
</step_4>

<step_5>
Restart only with evidence.

Recovery order:
1. `Restart-PSUApp -Name 'Devolutions CIEM'` when the runtime is reachable but
   the app state is stale
2. configuration sync or explicit PSU management action if the issue is app
   registration or module import
3. `az webapp restart` only when runtime is unreachable, genuinely cold, or the
   control plane indicates the host needs a recycle

Do not use a full web app restart as the first move.
</step_5>

<step_6>
Once the instance is healthy, hand the work back to the right owner:
- use `testing-expert` or `pester-tests` for test execution
- use `publish-psu-module` for publish and import workflows
- use the generic `psu` skill for non-Azure-instance PSU product questions
</step_6>
</process>

<success_criteria>
- [ ] The failure plane was identified before recovery actions were chosen
- [ ] Diagnostics or the last transcript log provided the primary evidence
- [ ] Restarts, token recovery, or log pulls were done for a specific reason
- [ ] Azure test or publish work resumes only after the instance itself is green
</success_criteria>
