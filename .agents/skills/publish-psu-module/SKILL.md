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
2. Inspect the pending change set and choose the semantic version bump (`Patch`, `Minor`, or `Major`) before publishing.
3. Run the matching `Publish-PSUModule` command from the repository root with an explicit `-BumpVersion`.
4. Add `-ValidateDeployment` when the request is for a full CIEM deploy, not only a publish/import.
5. Confirm publish status, module version, and app restart output.
6. If restart is not confirmed, run the target-specific restart command below.
7. If Azure import, restart, 401, or post-publish runtime verification fails, switch to `azure-psu-instance` before repeating the publish.
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
Determine the semantic version bump. Do not rely on the `Publish-PSUModule`
default bump. Always pass `-BumpVersion` explicitly.

Inspect the change set first:

```powershell
git status --short
git diff --stat
git diff --name-only
```

Classify the highest-impact change:

- `Major`: breaking public/module contract changes, removed or renamed exported commands, incompatible parameter changes, incompatible schema or persisted-data changes, required manual migrations, removed UI/API workflows, changed authentication/profile formats, or behavior changes that make existing automation invalid.
- `Minor`: backwards-compatible user-visible capability, new exported command, new PSU page or workflow, new provider/check/attack-path capability, additive schema changes, new optional parameters, or new configuration that existing users can ignore.
- `Patch`: bug fix, test fix, documentation-only change, internal refactor with no public behavior change, performance improvement with the same contract, or republish of equivalent behavior.

If multiple categories apply, choose the highest category: `Major` > `Minor` > `Patch`.
If the change impact is ambiguous after inspecting the diff, ask the user one targeted
question and include your recommended bump. Do not publish until the ambiguity is resolved.
</step_2>

<step_3>
For local adam-server publishing:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -LocalOnly -BumpVersion <Patch|Minor|Major>"
```
</step_3>

<step_4>
For Azure publishing:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -BumpVersion <Patch|Minor|Major>"
```
</step_4>

<step_5>
For a full CIEM deploy, use the same `Publish-PSUModule` entry point with
`-ValidateDeployment`. Do not call or recreate `Deploy-CIEMPSUModule`; the full
deploy path was merged into `Publish-PSUModule`.

Local:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -LocalOnly -BumpVersion <Patch|Minor|Major> -ValidateDeployment"
```

Azure:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -BumpVersion <Patch|Minor|Major> -ValidateDeployment"
```
</step_5>

<step_6>
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
</step_6>
</workflow>

<safety>
- Do not upload module files directly to Azure PSU.
- Local publishing uses adam-server through `Publish-PSUModule -LocalOnly`.
- Azure publishing goes through PowerShell Gallery before PSU import.
- CIEM Gallery imports must allow PSU configuration sync. Do not use
  `Install-PSUModule -NoSync` for CIEM Gallery installs because PSU must load
  `.universal/dashboards.ps1` and `.universal/initialize.ps1` to register the
  app and run `Initialize-CIEMPSUInstance`.
- CIEM Gallery installs are fresh-only. Do not add legacy repair, migration, or
  cleanup paths to install/bootstrap. Existing unsupported CIEM residue must
  fail validation; remove CIEM from the PSU instance before installing the
  current module.
- Do not use `-Integrated` from the external terminal publish workflow.
- Do not print or serialize raw PSU job objects from `Invoke-CIEMCommand`,
  `Invoke-TestCommand`, or deployment results. PSU job objects can contain
  `appToken.token`; report only safe fields such as job ID, status, message
  text, module version, app count, script count, and validation status.
</safety>

<success_criteria>
- The publish command completes without error.
- The chosen `Patch`, `Minor`, or `Major` bump is reported with the diff-based rationale.
- The module version and publish status are reported.
- The app restart is confirmed by publish output or by the explicit restart command.
- Azure publishes report the PowerShell Gallery publication details.
</success_criteria>
