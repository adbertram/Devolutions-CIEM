# PowerShell Codebase Review - 2026-04-29

## Scope

Reviewed the Devolutions CIEM PowerShell codebase under `/Users/adam/Dropbox/GitRepos/Devolutions-CIEM`, including:

- `*.ps1`, `*.psm1`, and `*.psd1` implementation files.
- PSU page/runtime code and local PSU documentation references.
- Pester unit and E2E helper files.
- Module manifests and admin scripts.

The review was read-only except for this report file.

## Executive Summary

- No P0 findings.
- The highest-risk findings are public APIs that expose module-defined classes, PSU runtime paths that can fail in Azure, and fail-fast violations where errors are retried, downgraded to warnings, or skipped.
- The Pester reviewer rejected the current test suite quality gate: `0 CRITICAL, 32 HIGH, 0 MEDIUM, 0 LOW`.
- A direct unit run using `scripts/invoke-ciem-tests.ps1 -Suite Unit -Output Detailed` started 1,195 tests but was interrupted after a TTY prompt appeared in `CIEMAzureResourceRelationship.Tests.ps1`. A non-TTY targeted rerun of that file passed 23/23 but still printed the mandatory-parameter prompt, so the test is noisy and should be hardened.

## Findings To Fix

| ID | Severity | Area | Finding | Minimal Fix |
|---|---:|---|---|---|
| PS-001 | P1 | Public API | Public functions expose module-defined types in signatures and output metadata. External callers and PSU runspaces can fail with `Unable to find type` because type literals are resolved outside module scope. Affected references: `psu-app/modules/Devolutions.CIEM.EffectivePermissions/Public/Get-CIEMEffectivePermission.ps1:3`, `:6`, `:12`, `:21`, `:24`; `psu-app/modules/Devolutions.CIEM.Reports/Public/Invoke-CIEMReport.ps1:9`; `psu-app/modules/Devolutions.CIEM.Graph/Public/Invoke-CIEMAttackPathRemediation.ps1:6`; `psu-app/modules/Devolutions.CIEM.Checks/Public/New-CIEMScanResult.ps1:13`; `psu-app/modules/Devolutions.CIEM.Checks/Public/Save-CIEMScanResult.ps1:13`. | Replace public parameter types with simple types, `[pscustomobject]`, or string `ValidateSet` contracts. Keep class construction and typed validation inside module-private implementation. Use string-form `OutputType` for module classes. |
| PS-002 | P1 | PSU runtime | `Get-CIEMAttackPathRemediationScript` uses `Get-PSUScript -Name ... -Integrated` at `psu-app/modules/Devolutions.CIEM.Graph/Public/Get-CIEMAttackPathRemediationScript.ps1:26`. The repo documents Azure PSU `Get-PSUScript -Name` cancellation on missing scripts. A stale attack path or partial registration can break remediation rendering with a PSU transport error. | Enumerate `Get-PSUScript -Integrated` once and match locally by normalized script name or repository path, following `psu-app/Public/Import-CIEMScript.ps1`. |
| PS-003 | P1 | PSU runtime | `New-CIEMScanPage` writes `$script:ScanConfigCacheKey` from an `-OnClick` event handler at `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMScanPage.ps1:221`. PSU event handlers run in separate runspaces, so script scope is not a stable page contract. `New-CIEMScanRun` reads the same cache key at `psu-app/modules/Devolutions.CIEM.Checks/Public/New-CIEMScanRun.ps1:62`. | Use a literal cache key or a public helper that returns the key inside the handler and scan job. Add Playwright/Pester coverage for selected-check scan launch. |
| PS-004 | P1 | PSU runtime | `GetCIEMAzureAuthProfileCache` directly reads `Get-PSUCache -Key $script:AzureAuthProfilesCacheKey -Integrated -ErrorAction Stop` at `psu-app/modules/Azure/Infrastructure/Private/GetCIEMAzureAuthProfileCache.ps1:17`. On a fresh PSU instance, the missing cache key is the expected empty state and can fail first page render/save. | Initialize the cache key before first read or centralize the missing-key contract through `ReadPSUCache`, then return an empty list only for that explicit missing-key state. |
| PS-005 | P1 | Fail-fast | `Invoke-CIEMCommand` retries PSU REST requests once on 401 at `Devolutions.CIEM.Admin/Public/Invoke-CIEMCommand.ps1:92-119`. This is fallback behavior that can hide stale token/auth bugs. | Remove the 401 retry path and fail immediately. Fix token drift at `Connect-PSU` or Azure PSU recovery. |
| PS-006 | P1 | Fail-fast | `Enable-CIEMCheck` and `Disable-CIEMCheck` emit non-terminating `Write-Error` and continue when a check ID is missing at `psu-app/modules/Devolutions.CIEM.Checks/Public/Enable-CIEMCheck.ps1:40-41` and `psu-app/modules/Devolutions.CIEM.Checks/Public/Disable-CIEMCheck.ps1:40-41`. Pipeline input can partially mutate state. | Replace `Write-Error` and `continue` with `throw`. Add tests for multi-ID input where one ID is invalid. |
| PS-007 | P1 | Persistence | `Save-CIEMScanRun` skips persistence when the provider row is missing at `psu-app/modules/Devolutions.CIEM.Checks/Public/Save-CIEMScanRun.ps1:33-38`, and catches database failures only to `Write-Warning` at `:104-107`. A scan can appear completed while its run/results were not persisted. | Throw on missing provider and rethrow transaction failures after rollback. Add tests that a failed save fails the scan path. |
| PS-008 | P1 | Error policy | Multiple production/runtime functions do not start with `$ErrorActionPreference = 'Stop'`: `_BootLog` in `psu-app/Devolutions.CIEM.psm1:15`; all helper functions in `scripts/azure-psu-diagnostics.ps1:52`, `:86`, `:100`, `:154`, `:177`, `:187`, `:196`, `:240`, `:257`, `:282`, `:300`, `:321`, `:342`; Azure check functions in `psu-app/modules/Azure/Checks/Test-EntraPolicyDefaultUserCannotCreateSecurityGroup.ps1:1`, `Test-EntraPolicyEnsureDefaultUserCannotCreateApp.ps1:1`, and `Test-EntraPolicyEnsureDefaultUserCannotCreateTenant.ps1:1`. | Add `$ErrorActionPreference = 'Stop'` as the first statement after each `param()` block. Expand the enforcement test so these paths are scanned. |
| PS-009 | P2 | Discovery graph | `InvokeCIEMGraphComputedEdgeBuild` swallows malformed JSON and FK failures in several places: `psu-app/modules/Azure/Discovery/Private/InvokeCIEMGraphComputedEdgeBuild.ps1:82-94`, `:103`, `:137`, `:209`, `:234`, `:278`, `:343`. This can silently drop graph edges from bad discovery rows. | Fail on malformed persisted JSON or mark the discovery run failed with the bad row ID. Do not continue past invalid graph input. |
| PS-010 | P2 | Discovery graph | `ResolveCIEMNodeKind` has an empty catch at `psu-app/modules/Azure/Discovery/Private/ResolveCIEMNodeKind.ps1:51-56` when managed-identity property JSON fails to parse. | Throw a descriptive error for malformed `PropertiesJson`, including type/source context. |
| PS-011 | P2 | PSU runtime | `New-CIEMEnvironmentPage` cancels all running jobs whose script name matches `*Discovery*` at `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMEnvironmentPage.ps1:150-153`. A shared PSU instance can terminate unrelated discovery jobs. | Stop only the exact CIEM discovery script (`Checks/Start-CIEMAzureDiscovery`) or the specific job ID associated with the active CIEM discovery run. |
| PS-012 | P2 | Module structure | Several files under `Public/` define private helper functions, blurring export boundaries. Examples: `Devolutions.CIEM.Admin/Public/Invoke-CIEMCommand.ps1:68`, `psu-app/modules/Azure/Discovery/Public/Start-CIEMAzureDiscovery.ps1:25`, `psu-app/modules/Devolutions.CIEM.Checks/Public/Save-CIEMCheck.ps1:18`, `psu-app/modules/Devolutions.CIEM.Checks/Public/Update-CIEMCheck.ps1:53`, `psu-app/modules/Devolutions.CIEM.Graph/Public/Get-CIEMAttackPath.ps1:1`, `:27`, `:78`. | Move helpers to `Private/` files or inline single-use logic. Keep each `Public/` file focused on its exported command. |
| PS-013 | P2 | Guardrail tests | `psu-app/Tests/Unit/ErrorActionPreference.Tests.ps1` only scans `Public/` and `Private/` paths at lines `6-20` and file collection at `28-32`, so it misses `.psm1`, `scripts/`, checks, templates, and E2E helpers. | Expand the scanner to every tracked PowerShell file that can define functions, with explicit exclusions for generated/vendor content only. |
| PS-014 | P2 | Templates/helpers | Shared tracked scripts also miss function-level `$ErrorActionPreference = 'Stop'`: `psu-app/Tests/E2E/PesterE2EHelper.ps1:8` and `psu-app/modules/Devolutions.CIEM.Graph/Data/attack_path_remediation_script_template.ps1:5`. | Apply the same EAP rule to test helpers/templates or document a narrow explicit exemption with tests. |
| PS-015 | P2 | Pester quality | `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureResourceRelationship.Tests.ps1:65` asserts a missing mandatory parameter by invoking the command with only `-SourceId`. The test passes in a non-TTY run but prints an interactive `SourceType:` prompt; in a TTY full run it stalled until interrupted. | Assert mandatory metadata through `Get-Command`/parameter attributes or invoke in a noninteractive child process that fails without prompting. |
| PS-016 | P3 | Naming | Private functions use public-style dashed names in private scope. Examples: `Devolutions.CIEM.Admin/Private/Assert-PSUConnection.ps1:1`, `Convert-ProwlerCheck.ps1:1`, `psu-app/modules/PSUSQLite/Private/Resolve-PSUSQLiteAssembly.ps1:1`, plus similar admin private helpers. | Rename private helpers to the repo's no-dash private naming convention and update call sites. |

## Test Review Findings

The Pester reviewer produced a rejected verdict with 32 high-severity findings. Grouped by rule:

### Real Environment Access

- `psu-app/Tests/Unit/ModuleLoad.Tests.ps1:14-22` reads the live runtime log `psu-app/data/ciem.log` in a unit test. Replace it with isolated logging assertions or source-content checks.

### Source-Only Tests Importing The Module

- `psu-app/modules/Azure/Discovery/Tests/Unit/InvokeCIEMScanRefactor.Tests.ps1:1-10` imports `Devolutions.CIEM` even though its assertions are source-only. Remove module import from that file.

### Conditional Assertion Logic

- `psu-app/modules/Devolutions.CIEM.Graph/Tests/Unit/CIEMAttackPath.Tests.ps1:68-87` branches between `Should -Throw` and `Should -Be` inside one data-driven `It`.
- `psu-app/modules/Azure/Infrastructure/Tests/Unit/ConnectCIEMAzure.Tests.ps1:50-60` only asserts scope URLs if a regex match succeeds.
- `psu-app/modules/Devolutions.CIEM.Graph/Tests/Unit/CIEMAttackPathPattern.Tests.ps1:181-214` gates assertions behind `if ($step.kind)`, `if ($step.edge)`, `if ($step.node_filter)`, and `if ($step.filter)`.

Split these into deterministic test groups with one assertion path per `It`.

### `-ErrorAction SilentlyContinue` In `It` Blocks

- `psu-app/Tests/Unit/ModuleLoad.Tests.ps1:154-198`
- `psu-app/modules/Azure/Discovery/Tests/Unit/InvokeCIEMBatchInsert.Tests.ps1:17`
- `psu-app/modules/Azure/Discovery/Tests/Unit/SaveCIEMAzureTable.Tests.ps1:115`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureDiscoveryRun.Tests.ps1:82`
- `psu-app/modules/Azure/Infrastructure/Tests/Unit/InvokeCIEMParallelForEach.Tests.ps1:23`
- `psu-app/modules/Devolutions.CIEM.Graph/Tests/Unit/CIEMAttackPathPersistence.Tests.ps1:306`

Replace silenced negative lookups with explicit `Should -Throw` assertions and move cleanup to deterministic `AfterEach`/`finally` paths without swallowed errors.

### Missing `Mock Write-CIEMLog` In Unit Tests That Import The Module

Add `Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}` after module import in these files:

- `psu-app/Tests/Unit/ImportCIEMScript.Tests.ps1:3`
- `psu-app/Tests/Unit/ModuleLoad.Tests.ps1:3`
- `psu-app/Tests/Unit/PSUIntegration.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureArmHierarchy.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureArmResource.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureDiscoveryRun.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureEntityRegistry.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureEntraResource.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureResourceRelationship.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureResourceType.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/DiscoveryClasses.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/InvokeCIEMBatchInsert.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/SaveCIEMAzureTable.Tests.ps1:3`
- `psu-app/modules/Azure/Discovery/Tests/Unit/SchemaCleanup.Tests.ps1:3`
- `psu-app/modules/Azure/Infrastructure/Tests/Unit/ConnectCIEMAzure.Tests.ps1:3`
- `psu-app/modules/Azure/Infrastructure/Tests/Unit/InvokeAzureApiPagination.Tests.ps1:3`
- `psu-app/modules/Azure/Infrastructure/Tests/Unit/InvokeCIEMParallelForEach.Tests.ps1:3`
- `psu-app/modules/Devolutions.CIEM.Graph/Tests/Unit/CIEMGraphNode.Tests.ps1:3`
- `psu-app/modules/Devolutions.CIEM.Graph/Tests/Unit/GraphClasses.Tests.ps1:3`
- `psu-app/modules/Devolutions.CIEM.PSU/Tests/Unit/GetCIEMRelationshipColor.Tests.ps1:3`
- `psu-app/modules/Devolutions.CIEM.PSU/Tests/Unit/PageRegistry.Tests.ps1:5`

## Verification Performed

Commands run during review:

```bash
git status --short --branch
rg --files -g '*.ps1' -g '*.psm1' -g '*.psd1' -g '!**/node_modules/**' -g '!**/.git/**' | wc -l
rg -n '\bWrite-Error\b' -g '*.ps1' -g '*.psm1' -g '*.psd1'
rg -n 'Import-Module\b.*\s-Force\b' -g '*.ps1' -g '*.psm1' -g '*.psd1'
rg -n '\b-ErrorAction\s+SilentlyContinue\b|\b-EA\s+SilentlyContinue\b' -g '*.Tests.ps1' -g '*Helper.ps1'
rg -n '\[CIEM' psu-app/modules/*/Public psu-app/Public Devolutions.CIEM.Admin/Public -g '*.ps1'
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Output Detailed
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureResourceRelationship.Tests.ps1 -Output Detailed
```

Validation results:

- Static inventory found 394 PowerShell files.
- Targeted `CIEMAzureResourceRelationship.Tests.ps1` run: 23 passed, 0 failed, 0 skipped.
- Full unit run was not completed because the TTY session reached the mandatory-parameter prompt described in `PS-015`; after interruption, the runner threw `Pester suite 'Unit' did not write a result summary. Child process exit code: 1.`

## Post-Fix Status

All findings listed above were remediated after this report was created.

Fix coverage included:

- Public parameter contracts were changed away from module class types while keeping string-form `OutputType` metadata where appropriate.
- PSU runtime fallbacks were removed for remediation script lookup, scan cache key handling, Azure auth profile cache reads, and PSU REST 401 retries.
- Fail-fast behavior now throws for missing checks, missing scan providers, transaction failures, malformed discovery JSON, malformed graph node JSON, and graph edge persistence failures.
- Function-level `$ErrorActionPreference = 'Stop'` coverage was expanded across production scripts, helpers, templates, and tracked test helpers.
- Public-file helper leakage and private dashed helper naming were cleaned up.
- Pester quality findings were fixed, including the mandatory-parameter prompt, source-only module import, conditional assertions, `SilentlyContinue` use in reviewed tests, live log access, and missing `Write-CIEMLog` mocks.
- Scan page DataGrid modal handlers now capture row fields before nested `OnClick` handlers execute, so PSU click event data cannot overwrite the rendered row context.
- Parallel scan execution now carries each selected check script path into the child runspace and dot-sources the script before invoking the check function.

Post-fix verification:

```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureEffectiveRoleAssignment.Tests.ps1 -Output Detailed
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Output Normal
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Playwright -Environment local -Name 'Environment Page'
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Playwright -Environment local -Name 'Scan Page'
pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -LocalOnly -BumpVersion Patch"
./scripts/ciem-log.sh -n 120
git diff --check
rg -n "Get-PSUScript\s+-Name|\$script:ScanConfigCacheKey|catch\s*\{\s*continue\s*\}|FK constraint: skipping edge|Write-Warning \"Save-CIEMScanRun|Write-Error \"Check '" psu-app Devolutions.CIEM.Admin scripts -S
rg -n '\b-ErrorAction\s+SilentlyContinue\b|\b-EA\s+SilentlyContinue\b' psu-app Devolutions.CIEM.Admin scripts -g '*.ps1' -g '*.psm1' -g '*.Tests.ps1' -S
```

Results:

- Targeted effective role assignment test: 58 passed, 0 failed.
- Full standardized unit suite: 1203 passed, 0 failed, 0 skipped.
- Local PSU publish completed successfully at module version 3.0.11.
- Environment Playwright check: 31 passed, 0 failed.
- Scan Playwright check: 38 passed, 0 failed.
- CIEM runtime log shows scan jobs completing and persisting one result each under v3.0.11.
- `git diff --check`: no whitespace errors.
- Static anti-pattern scans: no implementation matches; the earlier FK string is now only asserted by a guardrail test.

## Source Inputs

- Requested `powershell-expert` review.
- PSU runtime review from `psu-expert`.
- Pester quality review from `pester-test-reviewer`; raw JSON remains at `agent_workspaces/pester-test-reviewer/report.json`.
- Local PSU docs consulted by the PSU review: `docs/psu-docs/apps/components/README.md`, `docs/psu-docs/automation/jobs.md`, `docs/psu-docs/automation/scripts/README.md`, `docs/psu-docs/cmdlets/Get-PSUCache.txt`, `docs/psu-docs/cmdlets/Set-PSUCache.txt`, and `docs/psu-docs/cmdlets/Get-PSUScript.txt`.
