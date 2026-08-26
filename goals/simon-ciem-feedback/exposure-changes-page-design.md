# Exposure Changes Review Page — Design / Discovery

Status: **P1 discovery-only design.** Gated on Simon Chalifoux feedback. No PR, no publish, no deploy.
Scope: design a new read-only PSU page that surfaces `Get-CIEMExposureChange`. The detect / snapshot / compare pipeline is built and Pester-covered but nothing in the UI consumes it.

## 1. Problem

Simon's feedback item #2 ("CIEM Needs Scheduled Discovery And Exposure-Change Alerting") asks CIEM to compare discovery snapshots and surface **new risk, removed risk, and risk-score increases** so a security team does not have to manually re-read the whole dashboard each run. The backend is already there:

- `Save-CIEMExposureSnapshot` persists a per-run exposure snapshot (`ciem_exposure_snapshot_items`).
- `Compare-CIEMExposureSnapshot -PreviousDiscoveryRunId -CurrentDiscoveryRunId` diffs two runs and writes `ciem_exposure_changes`.
- `Get-CIEMExposureChange` reads those rows back.

There is **no CIEM page that consumes `Get-CIEMExposureChange`** today. This page closes that gap: a dedicated, per-run "what changed since last discovery" review surface.

## 2. Data source

Command (call qualified, as every page does): `Devolutions.CIEM\Get-CIEMExposureChange`

File: `psu-app/modules/Devolutions.CIEM.Graph/Public/Get-CIEMExposureChange.ps1`

### Parameters (all optional)
| Parameter | Type | Notes |
|---|---|---|
| `CurrentDiscoveryRunId` | `int` | Filters to one current discovery run (the "compared-to-previous" run). Server-side `WHERE current_discovery_run_id = @id`. This is the page's primary time-window control. |
| `ChangeType` | `string` (`NewRisk`, `RemovedRisk`, `RiskIncrease`) | Server-side `WHERE change_type = @change_type`. |
| `Last` | `int` | `LIMIT`. Applied after ordering. |

Default ordering (no param): `current_discovery_run_id DESC, severity_rank ASC, change_type ASC, exposure_key ASC` — newest run first, most severe first. No param = every stored change across all runs.

### Output object shape (`PSCustomObject[]`)
21 properties per change row (typed in the function; SQLite table `ciem_exposure_changes`):

| Property | Type | Meaning / UI use |
|---|---|---|
| `Id` | string | `"{currentRunId}:{changeType}:{exposureKey}"` — grid row id. |
| `PreviousDiscoveryRunId` | int? | Baseline run compared against (null for a first-ever `NewRisk`). |
| `CurrentDiscoveryRunId` | int | Run that produced the change. Group / filter key. |
| `ExposureKey` | string | Stable identity of the underlying exposure (matches snapshot key). |
| `ChangeType` | string | `NewRisk` / `RemovedRisk` / `RiskIncrease`. **Primary chip + filter.** |
| `ExposureType` | string | `IdentityRisk` or `AttackPath`. Secondary chip + filter. |
| `Severity` | string | `critical`/`high`/`medium`/`low`. Effective severity of the change. |
| `SeverityRank` | int | 1=critical … 4=low. Sort key. |
| `Title` | string | Human title (identity name, or attack-path pattern name). Main flex column. |
| `PreviousSeverity` | string? | For `RiskIncrease` before→after context. |
| `CurrentSeverity` | string? | For `RiskIncrease` before→after context. |
| `ImpactedIdentityId` | string? | Object/Principal ID (Simon #8 — always show the ID). |
| `ImpactedIdentityName` | string? | Display name. |
| `ImpactedIdentityType` | string? | User / ServicePrincipal / Group etc. |
| `ImpactedResourceId` | string? | Target resource ARM id. |
| `ImpactedResourceName` | string? | Target resource name. |
| `FirstSeenAt` | string (ISO 8601) | When the current exposure was first observed. Time column. |
| `PreviousStateJson` | string? | Full prior exposure state (detail panel only). |
| `CurrentStateJson` | string? | Full current exposure state (detail panel only). |
| `Evidence` | string | Prebuilt human sentence, e.g. `"New high AttackPath exposure: <title>"`. |
| `CreatedAt` | string (ISO 8601) | When the diff row was written. |

Notes that shape the UI:
- Only **risk-worthy** changes are ever stored — `Compare-CIEMExposureSnapshot` uses `TestCIEMExposureSeverityIsRisk` (severity ≠ `low`), so in practice rows are `medium`+. Do not build UI that promises a "low" bucket.
- `Compare-CIEMExposureSnapshot` **replaces** all rows for `current_discovery_run_id` on each run (`DELETE … WHERE current_discovery_run_id` then re-insert). So "changes for run N" is authoritative and idempotent — safe to re-render on demand.
- Table is indexed on `current_discovery_run_id`, `change_type`, and `severity_rank` — the three filters below are all index-backed.

## 3. Columns (1080p-conscious, per Simon #10)

Main grid (New-UDDataGrid, `-AutoHeight $true -Pagination -PageSize 25 -ShowQuickFilter -ExportOptions @('CSV','JSON')`):

| Field | Header | Sizing | Render |
|---|---|---|---|
| `changeType` | Change | fixed ~130 | chip: NewRisk=red-ish, RiskIncrease=orange, RemovedRisk=green |
| `severity` | Severity | fixed ~110 | chip via `Devolutions.CIEM\Get-SeverityColor` |
| `title` | Exposure | **Flex 1** | primary text — never truncate this one |
| `exposureType` | Type | fixed ~120 | chip (IdentityRisk / AttackPath) |
| `identityName` | Identity | width ~180 | display name |
| `identityId` | Object ID | width ~180 | monospace; Simon #8 — disambiguates duplicate names |
| `resourceName` | Target | Flex 1 | `overflowWrap: anywhere` |
| `firstSeenAt` | First Seen | width ~150 | `yyyy-MM-dd HH:mm` |

Follows Simon #10: important text columns get `Flex`, status/severity get fixed compact widths, no single-digit column hogging width, pagination stays left of any horizontal scroll. Deliberately keep the *displayed* column count low; put `evidence`, before/after severity, and the state JSON in a `-LoadDetailContent` expand panel (same pattern as `New-CIEMScanHistoryPage`).

### Detail panel (row expand)
- `Evidence` sentence.
- `RiskIncrease`: `PreviousSeverity → CurrentSeverity` badge pair.
- Pretty-printed `CurrentStateJson` (and `PreviousStateJson` for RemovedRisk).
- Drill-in button: `ExposureType='IdentityRisk'` → `/ciem/identities`; `ExposureType='AttackPath'` → `/ciem/attack-paths` (mirror the dashboard Needs-Attention drill-ins in `New-CIEMDashboardPage.ps1`). **Open question — see §7.**

## 4. Filtering / grouping

| Control | Backed by | Mechanism |
|---|---|---|
| **Discovery run (time window)** | `CurrentDiscoveryRunId` | `New-UDSelect` populated from `Devolutions.CIEM\Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last N` (exactly the pattern `New-CIEMReportsPage` already uses for past-run selection). Default = latest completed run. |
| **Change type** | `ChangeType` param | `New-UDSelect` (All / NewRisk / RiskIncrease / RemovedRisk). Server-side filter. |
| **Severity** | client | quick-filter / client column filter on the returned rows (severities are already ≥ medium). |
| **Exposure type** | client | IdentityRisk vs AttackPath toggle/filter. |
| **Resource / identity text** | client | `-ShowQuickFilter` free-text across grid. |

Run + ChangeType are passed as parameters to `Get-CIEMExposureChange` (index-backed); the rest are client-side over the already-small per-run result set. Re-query on selector change via `Sync-UDElement` against a `New-UDDynamic` panel (same as dashboard / scan history).

Summary chips above the grid (counts for the selected run): NewRisk / RiskIncrease / RemovedRisk, and Critical / High counts — parallels the scan-history summary-chip row.

## 5. Mapping to Simon's feedback

| Simon item | How this page answers it |
|---|---|
| **#2 Scheduled discovery + exposure-change alerting** | This *is* the local review surface for the compare pipeline — "new risk / removed risk / risk increase since last run," per-run. It is the read/inspect half; outbound connector delivery stays out of scope (Simon #2 explicitly says do not send until targets are defined; `Get-CIEMConnectorPayloadPreview` remains its own separate unbuilt surface). |
| **#1 Dashboard surfaces current outstanding risk** | Complements the dashboard Needs-Attention queue: dashboard = "what's bad now," Exposure Changes = "what changed this run." Drill-ins reuse the same identity/attack-path destinations. |
| **#3 PAM implementation progress** | RemovedRisk + RiskIncrease over runs are the raw before/after evidence the PAM progress view narrates; this page makes the per-run deltas inspectable. |
| **#10 Table sizing / pagination at 1080p** | Column plan in §3 bakes in the flex/fixed rules from #10. |
| **#8 Show Object ID** | `Object ID` column from `ImpactedIdentityId`. |

## 6. PSU page-construction approach (pattern to follow)

CIEM pages are **data-driven through a page registry** — do not hand-wire navigation.

1. **Registry entry** — add one object to `psu-app/modules/Devolutions.CIEM.PSU/Data/pages.json`:
   - `name`: `"Exposure Changes"`, `route`: `"/exposure-changes"`, `title`/`subtitle`, `icon` (e.g. `"ArrowTrendUp"` / `"Bell"` — must be a valid registered icon), `factory`: `"New-CIEMExposureChangesPage"`, `order`: `35` (between Scan History `30` and Identities `40`), and a `test` block with `expectedColumns` + `smokeSelector` (e.g. `"h4:has-text('Exposure Changes')"`).
   - `GetCIEMPSUPageRegistry` validates: unique name/route/factory/order, route starts with single slash, factory command is loaded, and `test` metadata present. All must hold or the app throws at load.
2. **Factory function** — `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMExposureChangesPage.ps1`, signature `param([Parameter(Mandatory)][object[]]$Navigation)`, body `New-UDPage -Name 'Exposure Changes' -Url '/ciem/exposure-changes' -Content { … } -Navigation $Navigation -NavigationLayout permanent`. Model it on `New-CIEMScanHistoryPage.ps1` (grid + detail expand + export) and `New-CIEMReportsPage.ps1` (completed-run `New-UDSelect` + `Sync-UDElement` refresh). Call the data command **module-qualified**: `Devolutions.CIEM\Get-CIEMExposureChange`.
3. **Wiring is automatic** — `New-DevolutionsCIEMApp` and `New-CIEMNavigation` both iterate `GetCIEMPSUPageRegistry`; adding the registry entry + factory is all that's needed. No edit to the app factory or nav.
4. **Script-name rule (Known Issue #10)** — this page is read-only and launches no `Invoke-PSUScript`, so the `Devolutions.CIEM\<command>` script-name trap does not apply. If a future "compare now" button is added, it must use `Devolutions.CIEM\<verb-noun>` matching `.universal/scripts.ps1`, never `Checks/…`.

### Tests required before implementation (TDD gate is enforced)
A PreToolUse `enforce-tdd.sh` hook **denies source edits until test files are touched**. Write these first (they must fail red first):
- **Pester** `psu-app/modules/Devolutions.CIEM.PSU/Tests/Unit/ExposureChangesPage.Tests.ps1` — mirror `ReportsPage.Tests.ps1`: assert the registry entry (name/route/factory), that nav + app factory iterate `GetCIEMPSUPageRegistry`, that the page file defines `New-UDPage -Name 'Exposure Changes' -Url '/ciem/exposure-changes'`, calls `Devolutions\.CIEM\\Get-CIEMExposureChange`, populates the run selector via `Devolutions\.CIEM\\Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last`, and renders the change-type/severity chip columns + `data-…` region hooks.
- `PageRegistry.Tests.ps1` already validates the registry globally — the new entry must keep it green.
- **Playwright** `psu-app/ui/e2e/pages/ExposureChanges/ExposureChanges.test.js` — page loads, grid renders, run + change-type selectors filter, empty-state shows when a run has no changes. Requires the live local PSU app (adam-server LAN), so it runs only after publish/deploy.

Run commands (from memory `reference_ciem_test_and_deploy_commands`):
- Pester: `pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Devolutions.CIEM.PSU/Tests/Unit`
- Playwright: `pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Playwright -Environment local`

## 7. Open questions for Simon

1. **Default time window** — default the run selector to the latest completed run only, or show "all runs" (cross-run history) by default? Recommendation: latest completed run (matches "what changed since last discovery"); cross-run history via the selector.
2. **RemovedRisk visibility** — should resolved/removed exposures appear by default, or be opt-in (they're "good news" and can crowd the actionable NewRisk/RiskIncrease rows)? Recommendation: include but default the change-type filter to NewRisk + RiskIncrease.
3. **Drill-in target for AttackPath changes** — reuse the dashboard's attack-path `DrillInUrl` convention, or link to a specific attack-path row by `ExposureKey`? Needs confirmation that `ExposureKey` maps to an attack-path route param.
4. **Placement / naming** — is a standalone "Exposure Changes" nav page right, or should this be a tab/section under Environment or Reports? Simon framed exposure change alongside scheduled discovery (Environment) and progress (Reports).
5. **Connector relationship** — should each change row expose a "preview outbound signal" action wired to `Get-CIEMConnectorPayloadPreview` (still read-only, no send), or keep connector preview a fully separate page? Affects whether the two unbuilt surfaces converge.

## 8. Is a local scaffold safe now?

**Partly.** The page is read-only (no scan/discovery/write, no PSU management cmdlets, no publish/deploy), which is the low-risk category. But:
- Scaffolding **must** go through the repo's TDD gate — write the Pester (and Playwright) tests first; the `enforce-tdd.sh` hook will otherwise deny the page-source and registry edits.
- Open questions #1–#3 change concrete UI/query behavior (default filters, drill-in). Reasonable defaults exist (see recommendations), so a scaffold can proceed on those defaults, but the **defaults should be confirmed by Simon before publish/deploy** so we don't ship a filter model he then wants changed.

**Recommendation:** safe to build the read-only page locally on the recommended defaults following the TDD flow (tests-first, Pester green). Do **not** `Publish-PSUModule` / `Deploy-PSUModule` and do **not** open a PR until Simon confirms §7 #1–#3. This design doc is the artifact to put in front of him first.
