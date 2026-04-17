---
name: "publish-psu-module"
description: >
  MANDATORY: Use this skill when publishing, deploying, importing, or releasing
  the Devolutions.CIEM PSU module to a PSU instance. Use for local adam-server
  publishes and Azure/PowerShell Gallery publishes. DO NOT run Publish-PSUModule
  ad hoc without this workflow.
argument-hint: "[local|azure]"
---

<objective>
Publish the Devolutions.CIEM module through `Devolutions.CIEM.Admin` using the
target-specific `Publish-PSUModule` flow, then confirm the app restart.
</objective>

<quick_start>
1. Select the target from the request; use `local` when no target is specified.
2. Run the matching `Publish-PSUModule` command from the repository root.
3. Confirm publish status, module version, and app restart output.
4. If restart is not confirmed, run the target-specific restart command below.
</quick_start>

<target_selection>
- `local`, `dev`, or `adam-server`: publish to the local PSU instance on adam-server with `-LocalOnly`.
- `azure`, `prod`, or `production`: publish through PowerShell Gallery, then import into Azure PSU.
- No target specified: use `local` and state that local adam-server publishing is the selected target.
- Conflicting target signals: ask the user directly which target to publish to before running a publish command.
</target_selection>

<workflow>
<step_1>
Run commands from the repository root containing `Devolutions.CIEM.Admin` and `psu-app`.
</step_1>

<step_2>
For local adam-server publishing:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -LocalOnly"
```
</step_2>

<step_3>
For Azure publishing:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app"
```
</step_3>

<step_4>
Verify the publish output confirms a successful app restart. If the output does
not confirm the restart, restart the app explicitly.

Local:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Connect-PSU -Local; Restart-PSUApp -Name 'Devolutions CIEM'"
```

Azure:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Connect-PSU; Restart-PSUApp -Name 'Devolutions CIEM'"
```
</step_4>
</workflow>

<safety>
- Do not upload module files directly to Azure PSU.
- Local publishing uses adam-server through `Publish-PSUModule -LocalOnly`.
- Azure publishing goes through PowerShell Gallery before PSU import.
- Do not use `-Integrated` from the external terminal publish workflow.
</safety>

<success_criteria>
- The publish command completes without error.
- The module version and publish status are reported.
- The app restart is confirmed by publish output or by the explicit restart command.
- Azure publishes report the PowerShell Gallery publication details.
</success_criteria>
