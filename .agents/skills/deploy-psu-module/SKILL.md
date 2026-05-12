---
name: "deploy-psu-module"
description: >
  MANDATORY: Use this skill when deploying, installing, importing, or updating
  the Devolutions.CIEM module in a PSU instance (local adam-server or Azure)
  from PowerShell Gallery. Assumes the version is already on PSGallery; use
  `publish-psu-module` first if not. DO NOT run Deploy-PSUModule ad hoc without
  this workflow.
argument-hint: "[local|azure] [version]"
---

<objective>
Install the current (or a specific) Devolutions.CIEM PowerShell Gallery version
into a PSU instance, restart the CIEM app, and optionally validate the deployment,
all via `Devolutions.CIEM.Admin\Deploy-PSUModule`. This skill never publishes to
PSGallery.
</objective>

<quick_start>
1. Select the target from the request; use `local` when no target is specified.
2. If `$ARGUMENTS` contains a version string, pass it via `-Version`.
3. Run the appropriate `Deploy-PSUModule` command from the repository root.
4. Add `-ValidateDeployment` when a full deploy with end-to-end validation is requested.
5. Confirm environment, installed version, and deploy status.
6. If Azure import, 401, or post-install verification fails, switch to `azure-psu-instance` before retrying.
</quick_start>

<target_selection>
- `local`, `dev`, or `adam-server`: deploy to the local PSU instance on adam-server (`-Environment local`).
- `azure`, `prod`, or `production`: deploy to Azure PSU (`-Environment azure`).
- No target specified: use `local` and state that local adam-server deployment is the selected target.
- Conflicting target signals: ask the user directly which target before running.
</target_selection>

<workflow>
<step_1>
Run commands from the repository root containing `Devolutions.CIEM.Admin`.
</step_1>

<step_2>
Confirm the target version exists on PowerShell Gallery before deploying. If a
version was requested but is not on Gallery yet, stop and recommend
`publish-psu-module` to publish it first.

```powershell
pwsh -NoProfile -Command "Find-Module Devolutions.CIEM -AllowPrerelease | Select-Object Name, Version | Format-Table -AutoSize"
```
</step_2>

<step_3>
For local adam-server deploy:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Deploy-PSUModule -Environment local"
```

For Azure deploy:

```powershell
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Deploy-PSUModule -Environment azure"
```

Optionally pin a version: `-Version 5.1.6`. Optionally validate: `-ValidateDeployment`.
</step_3>

<step_4>
Report environment, installed version, status (`Deployed`), and PSGallery URL.
When `-ValidateDeployment` was used, also report the validation status (e.g.
module/app/script counts).
</step_4>
</workflow>

<safety>
- `Deploy-PSUModule` is install-only. It does NOT publish to Gallery, does not
  bump the manifest, and does not require `NUGET_API_KEY`.
- The version installed is whatever PSU finds on PSGallery (or the explicit
  `-Version`). If a desired version is missing from Gallery, run
  `publish-psu-module` first — do NOT try to bump and publish from here.
- CIEM Gallery imports must allow PSU configuration sync. `Install-PSUModule`
  always runs `Sync-PSUConfiguration` so `.universal/dashboards.ps1` and
  `.universal/scripts.ps1` register PSU resources.
- CIEM Gallery installs are fresh-only. Existing unsupported CIEM residue must
  fail validation; remove CIEM via `Remove-CIEMPSUModule` (or
  `scripts/reinstall-ciem-psu-module.sh`) before installing the current module.
- Do not print or serialize raw PSU job objects from the deploy result. Report
  only safe fields such as module version, environment, status, app count,
  script count, and validation status.
- For Azure 401, cold-start, or runtime verification failures, switch to
  `azure-psu-instance` for recovery — do not loop on `Deploy-PSUModule`.
</safety>

<success_criteria>
- The deploy command completes without error.
- The reported version matches the version installed into PSU.
- The CIEM app restart succeeded (or was explicitly skipped with `-SkipAppRestart`).
- Deployment validation reports installed module, app, script, and database state when requested.
- No version bump or PSGallery publish was attempted.
</success_criteria>
