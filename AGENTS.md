# AGENTS.md

## Mandatory Testing Skill

- **MUST** load `$test-methodology` before writing, changing, debugging, reviewing, or validating tests or behavior-changing code.
- **MUST** load the `testing-expert` skill before writing, reviewing, or running any test.
- **MUST** load `pester-tests` for Pester-specific work.
- Pester tests are required for PowerShell/module/data changes.
- Playwright E2E tests are required for PSU UI/page/interaction changes.
- Both Pester and Playwright are required when module behavior is surfaced in the UI.
- `Invoke-TestCommand` is required for PSU runtime validation when PSU context matters; it is additional validation, not a substitute for tests.

## Project Context
- CIEM solution built on PowerShell Universal (PSU).
- PSU is owned by Devolutions.
- CIEM is distributed as a PSU Gallery add-on, not a standalone deployment.
- CIEM is a free, intentionally focused PSU Gallery add-on that creates value for Devolutions PAM by identifying entitlement risk and routing users toward PAM-supported action.
- CIEM is not meant to become a complete CIEM, CSPM, ticketing, or PAM replacement. Avoid broad standalone feature sets that duplicate Devolutions PAM capabilities.
- The product direction is **identity-first CIEM**, not generic CSPM. Prioritize entitlements, dormant permissions, role right-sizing, and control relationships. Prowler-ported CSPM checks are secondary.
- User-facing features should make the next Devolutions PAM-backed outcome clear where applicable: JIT access, approval workflows, credential and session governance, evidence capture, least-privilege changes, onboarding privileged accounts or secrets, and remediation tracking. Verify current Devolutions PAM information links before adding them; do not guess product URLs.

## Product Purpose And Expected Features
- `docs/ciem-feature-todos.md` is the source of truth for the project's purpose and expected product capabilities. Treat it as project direction, not an optional idea list.
- CIEM should discover cloud and identity entitlement data, build the environment hierarchy, detect attack paths, detect exposure changes over time, and make findings actionable through existing security and PAM workflows.
- CIEM features should solve narrow discovery, analysis, and prioritization problems in-app, then guide users to better outcomes with Devolutions PAM instead of owning the full remediation lifecycle.
- Expected discovery priorities are scheduled discovery scans, exposure change detection, AWS effective access graph, least-privilege recommendation previews, privilege drift detection, sensitive resource access inventory, expanded attack path patterns, and discovery coverage reporting.
- Expected action and connector priorities are outbound risk signal delivery, finding-to-action queue, PAM-backed JIT access requests, manual approval and evidence capture, least-privilege change packages, controlled role or policy updates, and automatic expiration or revocation.
- Discovery remains read-only by default. Action, connector, PAM, SIEM, ticketing, IdP, or cloud write workflows require explicit re-scoping before implementation.

## Global Blocker Ownership
- A blocker report is a progress update, not task completion.
- Autonomously remediate blockers as part of the requested work.
- Ask for user intervention only when the next step needs explicit approval, unavailable credentials, or a destructive decision.
- When reporting blockers, include the concrete remediation actions already in progress.

## Mandatory PSU Delegation
- Any PSU feature, API, config, publishing, restart, troubleshooting, or other PSU-specific question or operation must go through the `psu-expert` agent.
- Do not use web search or guess PSU behavior.

## PSU Instances
### Local PSU
- "Local" means the always-on PSU instance on `adam-server`, not the MacBook.
- Normal workflow is edit on MacBook, then `Publish-PSUModule -LocalOnly` pushes via SSH/rsync to adam-server.
- LAN URL: `http://192.168.86.36:5001` (set as `LOCAL_PSU_URL` in `.env`)
- `Connect-PSU` defaults to local and reads `LOCAL_PSU_URL` and `LOCAL_PSU_TOKEN` from `.env`; use `Connect-PSU -Azure` only for explicit Azure work.
- PSU Repository on adam-server: `/Users/adam/psu/Repository` (pushed via SSH, not Dropbox-synced).

### Azure PSU
- URL: `https://devolutions-ciem-psu.azurewebsites.net`
- Resource group: `devolutions-ciem-rg`
- Location: `West US 2`
- App Service Plan: `Standard S1 (Linux)`
- PSU version: `5.5.4`
- Container image: `ironmansoftware/universal:5.5.4-azure`
- Azure restarts are slow. Prefer app-level restart or configuration sync before a full webapp restart.
- To remove CIEM from the Azure PSU target, use `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment azure -Force`. Do not hand-run Azure CLI deletion or ad hoc PSU cleanup commands for CIEM removal.

## Module Deployment
- Never upload module files directly to the Azure PSU instance.
- Local publishing is automated by the `auto-publish-psu` Stop hook after `psu-app/` changes.
- Initial CIEM setup is owned by `psu-app/setup.ps1`, which is invoked during `Devolutions.CIEM` module import. Keep this setup path limited to idempotent local module initialization such as database/schema/catalog setup.
- PSU resource registration remains in `.universal/dashboards.ps1` and `.universal/scripts.ps1`. Do not move `New-PSUApp`, `New-PSUScript`, `Get-PSUScript`, or other PSU management cmdlets into import-time setup.

```powershell
Import-Module ./Devolutions.CIEM.Admin
Publish-PSUModule -ModulePath ./psu-app -WhatIf
Publish-PSUModule -ModulePath ./psu-app
Publish-PSUModule -ModulePath ./psu-app -LocalOnly
```

- Use `-LocalOnly` to push to adam-server via SSH/rsync (skips PSGallery).
- `scripts/azure_psu_file_manager.sh` and `scripts/invoke_command_in_azure_webapp.sh` are for inspection only, not deployment.
- Use `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment local -Force` or `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment azure -Force` to remove CIEM-owned PSU scripts, schedules, active jobs, and the `Devolutions.CIEM` module from a PSU target.

## Testing and Validation
- Use `Invoke-TestCommand` to validate CIEM code inside PSU instead of publish-debug-publish cycles.
- `Invoke-TestCommand` validates PSU runtime behavior after tests are in place; it does not replace Pester or Playwright tests.

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

## Known Issues

### 1. Discovery Last Query Must Preserve Filters
**Symptom:** The global Last Discovery header can disappear and PSU can show `One or more errors occurred` while a discovery run is in progress.
**Cause:** `Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 1` must apply `-Status` before `-Last`. If `-Last` ignores filters, a newer `Running` run with no `CompletedAt` is returned to `New-CIEMLastDiscoveryHeader`.
**Fix:** Build the `WHERE` clause for `Id` and `Status` first in `psu-app/modules/Azure/Discovery/Public/Get-CIEMAzureDiscoveryRun.ps1`, then append `ORDER BY started_at DESC LIMIT @last` only when `-Last` is supplied.
**Verification:** Run `pwsh -NoProfile -Command "Invoke-Pester psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureDiscoveryRun.Tests.ps1 -Output Detailed"` and `cd psu-app/ui/e2e && npx playwright test pages/Environment/Environment.test.js -g "when a discovery run is in progress"`.
**Recurrence Prevention:** Keep the Pester test named `Applies -Status before -Last so running runs do not replace the latest completed run` and the Environment E2E test named `should keep the global last discovery timestamp box visible`.

### 2. Azure PSU App Startup Must Not Register Scripts
**Symptom:** Azure `/ciem` can return HTTP 200 while the page body says `App is not running`. PSU logs can show `Failed to get dashboard. Specify a computer name or use the Connect-PSUServer command.` or `StatusCode="Cancelled"` gRPC timeout errors.
**Cause:** `New-DevolutionsCIEMApp.ps1` ran `Import-CIEMScript` from the dashboard/app startup path. PSU app startup is the dashboard render path and cannot reliably perform PSU management cmdlets such as `Get-PSUFolder`, `New-PSUFolder`, `Get-PSUScript`, or `New-PSUScript`; in Azure this fails unauthenticated or times out.
**Fix:** Keep the dashboard factory pure. Do not call `Import-CIEMScript` from `psu-app/modules/Devolutions.CIEM.PSU/Public/New-DevolutionsCIEMApp.ps1`. Run `Import-CIEMScript` as an explicit PSU management operation after `Connect-PSU`; use `Import-CIEMScript -Integrated` only from a PSU process where integrated cmdlets are verified to work.
**Verification:** Run `pwsh -NoProfile -Command "Invoke-Pester psu-app/Tests/Unit/ImportCIEMScript.Tests.ps1 -Output Detailed"`, run `Import-CIEMScript` after `Connect-PSU`, and run a Playwright browser check against `https://devolutions-ciem-psu.azurewebsites.net/ciem`; the page must show CIEM dashboard content and must not contain `App is not running`.
**Recurrence Prevention:** Keep the Pester assertion that the generated app startup script does not contain `Import-CIEMScript`. Do not add PSU management cmdlets to the app factory/startup path.

### 3. Azure PSU App Tokens Can Be Lost During Recovery
**Symptom:** `Connect-PSU` against Azure fails with HTTP 401 while `/api/v1/alive` is healthy. Publishing can succeed to PowerShell Gallery but fail during Azure import because the stored `AZURE_PSU_TOKEN` is invalid.
**Cause:** The Azure PSU database can contain zero app tokens after a recovery/reset event, invalidating the token in `.env`.
**Fix:** On the supported Azure image, set non-default `PSUDefaultAdminName` and `PSUDefaultAdminPassword` app settings from `.env`, restart the web app, wait for `/api/v1/alive` to report `loading=false`, sign in with those local admin credentials, grant a new app token, and update `.env` `AZURE_PSU_TOKEN` without printing it. Use `ResetAdminAccount=true` only as a temporary lockout recovery setting and remove it immediately after token recovery.
**Verification:** `Connect-PSU` succeeds, `Get-PSUModule` returns `Devolutions.CIEM` with the installed version, publishing can import the module into Azure, and the non-default admin credentials from `.env` can grant an app token.
**Recurrence Prevention:** If Azure `Connect-PSU` returns 401, inspect app token state before republishing. Keep `PSUDefaultAdminName` and `PSUDefaultAdminPassword` set on Azure, and do not leave `ResetAdminAccount=true` configured.

### 4. Azure PSU Get-PSUScript Name Lookup Cancels on Missing Scripts
**Symptom:** `Import-CIEMScript` can fail on Azure with `Status(StatusCode="Cancelled", Detail="No message returned from method.")` when calling `Get-PSUScript -Name` for a CIEM script that has not been registered yet.
**Cause:** Azure PSU 2026.1.5 cancels `Get-PSUScript -Name` when the script name is absent, including names such as `New-CIEMScanRun`, `DoesNotExist.ps1`, and folder-style names such as `Checks/New-CIEMScanRun`.
**Fix:** Do not use `Get-PSUScript -Name` in CIEM registration. Query `Get-PSUScript` once and match locally by normalized script name or repository path.
**Verification:** Run `pwsh -NoProfile -Command "Invoke-Pester psu-app/Tests/Unit/ImportCIEMScript.Tests.ps1 -Output Detailed"` and confirm the test asserts `Get-PSUScript` is not called with `-Name`. On Azure, `Import-CIEMScript` must return `Status = Registered` with `TotalScripts = 13`.
**Recurrence Prevention:** Keep the no-`-Name` Pester assertion in `ImportCIEMScript.Tests.ps1`; do not reintroduce named script lookups for CIEM registration.

### 5. Azure PSU 2026.1.5 Image Is Not a Supported Recovery Target
**Symptom:** A rebuilt Azure PSU instance on `ironmansoftware/universal:2026.1.5-azure` can show only a Devolutions Login first-run screen. Local admin bootstrap can return 401 for `/api/v1/accessible` and `/api/v1/apptoken/grant`, and adding `.universal/authentication.ps1` with `Set-PSUAuthenticationMethod -Type Form` can crash the container with exit code 139.
**Cause:** The 2026.1.5 Azure image changes first-run/auth behavior in a way that is not covered by the local PSU docs and blocks the documented CIEM bootstrap flow.
**Fix:** Keep the Azure CIEM PSU instance on `ironmansoftware/universal:5.5.4-azure`. If Azure keeps pulling 2026.1.5 after `linuxFxVersion` is changed, recreate the Web App with 5.5.4 as the initial image. Use `az webapp delete --keep-empty-plan` to preserve the App Service Plan; if the plan was deleted, recreate `devolutions-ciem-psu-asp` as Linux S1 in West US 2.
**Verification:** Docker logs must show `Pulling image docker.io/ironmansoftware/universal:5.5.4-azure`, `/api/v1/alive` must report `loading=false`, and `/login` must render the 5.5-era page without `?v=2026.1.5` assets.
**Recurrence Prevention:** Do not upgrade the Azure PSU container image past 5.5.4 until first-run, local-admin token grant, and CIEM module import have been tested in a separate throwaway Web App.

### 6. PSU Removal Retains CIEM Job History
**Symptom:** After `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment azure -Force`, Azure PSU can have `Devolutions.CIEM` module count `0`, CIEM-owned script count `0`, and CIEM-owned schedule count `0`, while `Get-PSUJob` still returns historical or queued `CIEMExecutor.ps1` job records.
**Cause:** PSU exposes `Get-PSUJob` and `Stop-PSUJob`, but no supported `Remove-PSUJob` or `Set-PSUJob` cmdlet. The project PSU knowledge also confirms `DELETE /api/v1/job/{id}` returns success without removing or archiving jobs. `scripts/remove-psu.ps1` therefore stops active CIEM jobs and removes CIEM resources, but intentionally retains job history.
**Fix:** Treat retained CIEM job history as a PSU retention limitation, not a script failure. Do not claim the instance is free from all CIEM remnants if owned job records remain. Do not modify PSU database tables directly without explicit user approval and a separate recovery plan.
**Verification:** Dot-source `scripts/remove-psu.ps1`, connect to Azure PSU, build `Get-CIEMPSUScriptRemovalModel -ModulePath ./psu-app`, and count `Get-PSUJob` results where `Test-CIEMOwnedPSUJob` returns true.
**Recurrence Prevention:** Removal summaries must report module, app, script, schedule, active job, queued job, and retained job-history counts separately.

### 7. Local PSU Module Removal Must Delete Publish-Point Files
**Symptom:** After `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment local -Force`, local PSU can show `Devolutions.CIEM` again even though the PSU module database delete returned `Status = Removed`, or it can retain the `Devolutions CIEM` app at `/ciem` after module/script removal.
**Cause:** Local publishing installs the module under the adam-server publish point at `/Users/adam/psu/Repository/Modules/Devolutions.CIEM`. PSU adds the repository `Modules` directory to `PSModulePath`, so deleting only the PSU database entry lets PSU rediscover the module from disk. The CIEM app is a separate PSU app resource and must be removed in addition to module-owned scripts and schedules.
**Fix:** `Remove-PSUModule -Environment local` must read `PUBLISH_POINT_SSH` and `PUBLISH_POINT_PSU_PATH` from `.env`, run `ssh <publish-point> "rm -rf '<PUBLISH_POINT_PSU_PATH>/Repository/Modules/Devolutions.CIEM'"`, and then run `Sync-PSUConfiguration -Reset`. `Remove-CIEMPSUModule` must remove CIEM-owned apps, scripts, schedules, and active jobs before invoking `Remove-PSUModule`, and must pass `-Environment` and connection parameters through to `Remove-PSUModule`.
**Verification:** Run `pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path Devolutions.CIEM.Admin/Tests/Unit`, then run `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment local -Force` and verify local PSU reports module, app, script, schedule, active job, and queued job counts as `0`.
**Recurrence Prevention:** Keep the `Remove-PSUModule.Tests.ps1` local filesystem cleanup assertions and the `CIEMDeployment.Tests.ps1` assertions that `Remove-CIEMPSUModule` removes CIEM-owned apps and passes environment and env file values into `Remove-PSUModule`.

### 8. Validated Gallery Reinstall Requires a Current Published Module
**Symptom:** `scripts/reinstall-ciem-psu-module.sh --validate-deployment` can remove the local CIEM module and install the latest PowerShell Gallery version, then fail bootstrap with `The term 'Initialize-CIEMPSUInstance' is not recognized` when Gallery is behind the local module source. Older Gallery installs can also recreate the legacy `CIEMExecutor.ps1` script.
**Cause:** The reinstall script runs local admin validation code against the module version that PSU installs from PowerShell Gallery. When the local source is newer than Gallery, the local validation contract can require commands that the published package does not contain. The old Gallery package can leave legacy CIEM PSU resources that current removal must still classify as CIEM-owned residue.
**Fix:** Before removing CIEM for a validated reinstall, compare the latest Gallery version with the local module manifest version and fail before removal when Gallery is older. Treat `CIEMExecutor.ps1` as a legacy CIEM-owned PSU script during removal.
**Verification:** Run `pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path Devolutions.CIEM.Admin/Tests/Unit`, run `scripts/reinstall-ciem-psu-module.sh --validate-deployment` while Gallery is older than the local manifest, and confirm it fails before removal with the Gallery/local version mismatch. Then run `pwsh -NoProfile -File ./scripts/remove-psu.ps1 -Environment local -Force` and verify CIEM module, app, and script counts are `0`.
**Recurrence Prevention:** Keep `ReinstallPSUModuleScript.Tests.ps1` asserting Gallery preflight runs before `Remove-CIEMPSUModule`, and keep `CIEMDeployment.Tests.ps1` asserting `CIEMExecutor.ps1` is removed as legacy CIEM-owned residue.

### 9. Invoke-CIEMCommand Must Not Send ScriptContent In The REST Query String
**Symptom:** `scripts/reinstall-ciem-psu-module.sh --environment local --validate-deployment` can complete install and app restart, then fail deployment validation with `Response status code does not indicate success: 414 (URI Too Long)` from `Invoke-CIEMCommand.ps1`.
**Cause:** PSU REST script parameters are query-string parameters. Passing a full validation script through `/api/v1/script/{id}?ScriptContent=...` can exceed the local PSU server URL limit. Sending `ScriptContent` in the REST JSON body does not bind the script parameter on PSU 5.5.4.
**Fix:** Invoke the persistent `CIEMExecutor.ps1` script with the native Universal cmdlet: `Invoke-PSUScript -Id <id> -Parameters @{ ScriptContent = $Command }`. Keep REST only for script discovery, script creation, job polling, and job output retrieval.
**Verification:** Run `pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path Devolutions.CIEM.Admin/Tests/Unit/Invoke-CIEMCommand.Tests.ps1`, run an oversized local `Invoke-CIEMCommand` command, and rerun `scripts/reinstall-ciem-psu-module.sh --environment local --validate-deployment`; validation must finish with `Status = Deployed`.
**Recurrence Prevention:** Keep the `Invoke-CIEMCommand.Tests.ps1` assertion that `ScriptContent` is passed through `Invoke-PSUScript` parameters and never appears in the REST invocation URL.

## Reference Docs
- Architecture planning: `docs/devolutions-ciem-app-architecture.md`
- CIEM feature todos: `docs/ciem-feature-todos.md` - source of truth for project purpose, expected features, product feedback, build order, and discovery/action guardrails.
- Resource icons: `psu-app/modules/Devolutions.CIEM.PSU/Data/icons/` contains official Azure, Entra, and AWS icon source packs, curated SVGs in `resources/`, and `resource-icon-map.json` for CIEM resource type mappings.
- PSU Azure hosting docs: `docs/psu-docs/config/hosting/azure.md`
