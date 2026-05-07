# Implementation Instructions: Simon CIEM Feedback

## Objective

Make CIEM match Simon Chalifoux's product feedback: an identity-first, PAM-relevant PSU app that surfaces urgent risks, detects exposure changes without manual dashboard checking, answers production deployment concerns, and feels usable at 1080p.

## Non-Negotiables

- Keep discovery read-only unless Adam explicitly scopes a write/action workflow.
- Do not add fallback logic. If data shape is wrong, trace and fix the source.
- Do not claim multi-instance PSU support until it is tested.
- Do not send outbound alerts to external systems until the connector target and allowed operation are explicitly scoped.
- Every implementation phase needs Pester coverage for PowerShell/module/data changes.
- Every PSU UI/page/interaction change needs Playwright E2E coverage.
- Runtime validation with `Invoke-TestCommand` is additional validation when PSU context matters; it does not replace Pester or Playwright.

## Source Files To Start With

- `docs/ciem-feature-todos.md`
- `docs/devolutions-ciem-app-architecture.md`
- `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMDashboardPage.ps1`
- `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMIdentitiesPage.ps1`
- `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMAttackPathsPage.ps1`
- `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMScanHistoryPage.ps1`
- `psu-app/modules/Devolutions.CIEM.PSU/Pages/New-CIEMReportsPage.ps1`
- `psu-app/modules/Devolutions.CIEM.Graph/Public/Get-CIEMIdentityRiskSummary.ps1`
- `psu-app/modules/Devolutions.CIEM.Graph/Public/Get-CIEMIdentityRiskSignals.ps1`
- `psu-app/modules/Devolutions.CIEM.EffectivePermissions/Public/Get-CIEMEffectivePermission.ps1`
- `psu-app/data/schema.sql`
- `docs/psu-docs/apps/components/data-display/table.md`
- `docs/psu-docs/automation/schedules.md`

## Phase 1: Fix The Identity View First

Simon directly reacted to the current identity view. Fix this before broad product work.

### Work

1. Change the top-level identity page row model so one row equals one identity.
2. Add visible `Object ID` or `Principal ID` for every identity row.
3. Move target resources, entitlements, effective actions, paths, and evidence into detail content or nested grids.
4. Preserve filtering by provider, access level, and privileged-only status.
5. If the same display name appears for two distinct principals, show type and object ID so the distinction is obvious.

### Implementation Notes

- The current page builds rows from `Get-CIEMEffectivePermission`, using an ID composed from provider, principal, entitlement, target, and entitlement ID. That row model creates duplicate-looking principals.
- Build a grouped identity model keyed by provider and principal ID.
- Use `Get-CIEMIdentityRiskSummary` as the top-level identity summary source for Azure.
- Use `Get-CIEMEffectivePermission` inside the identity detail surface, grouped by target resource and entitlement.

### Acceptance Criteria

- The identity grid does not repeat the same principal at the top level because it has multiple targets.
- The top-level identity row includes name, object ID, type, entitlement count, privileged role count, risk level, last activity, and at least one drill-in action.
- Expanding an identity shows target resources, entitlements, inherited/direct path, access level, and evidence.
- A service principal or managed identity with a duplicate display name can be distinguished without opening developer tools.

### Tests

- Add or update Pester tests for the grouped identity row model if the grouping is implemented outside the page.
- Add Playwright tests under `psu-app/ui/e2e/pages/Identities/` for one-row-per-identity, object ID visibility, and target-resource detail expansion.
- Run the identity page at 1080p and verify Simon's screenshot issue is gone.

## Phase 2: Fix Table/Grid Usability At 1080p

Simon called out table truncation, bad column allocation, and pagination that requires horizontal scrolling.

### Work

1. Audit every `New-UDDataGrid` and `New-UDTable` used in CIEM pages.
2. Assign fixed compact widths to numeric, status, severity, provider, service, and boolean columns.
3. Give important text columns meaningful flex width: principal, identity, target resource, finding, path, evidence, and result title.
4. Ensure pagination remains visible without horizontal scrolling at 1920x1080 and 1366x768.
5. Prefer detail panels for long text rather than cramming every field into the primary row.

### Implementation Notes

- PSU table docs support explicit column width and truncation on `New-UDTableColumn`.
- Current high-risk files include:
  - `New-CIEMIdentitiesPage.ps1`
  - `New-CIEMAttackPathsPage.ps1`
  - `New-CIEMAttackPathPatternsPage.ps1`
  - `New-CIEMScanHistoryPage.ps1`
  - `New-CIEMScanPage.ps1`
  - `New-CIEMReportsPage.ps1`
  - `New-CIEMDashboardPage.ps1`

### Acceptance Criteria

- No page requires horizontal scroll just to change pages.
- Important names and findings are not truncated while low-value count/status columns consume excess width.
- Grid row detail remains readable at 1080p.
- Screenshot comparison at 1080p shows pagination and important identity/finding columns visible.

### Tests

- Add Playwright assertions for pagination visibility and key text visibility on affected pages.
- Capture screenshots for identity and table-heavy pages at 1920x1080 and 1366x768.

## Phase 3: Make The Dashboard Show What To Look At ASAP

Simon wants the dashboard to show current outstanding risks, especially identity and attack path risks.

### Work

1. Add a dashboard "Needs Attention" section above or before static stats.
2. Populate it from identity risk summaries and attack paths.
3. Sort by severity, privileged standing access, public exposure, dormant/stale access, and newly discovered exposure once change detection exists.
4. Each item must provide a drill-in destination and evidence summary.
5. Keep scan result cards, but make them secondary to current risk.

### Implementation Notes

- Existing dashboard sections are `Checks & Scans` and `Identity Stats`.
- Do not create a broad new dashboard framework. Add one focused risk queue and reuse existing risk/attack-path data.

### Acceptance Criteria

- A user landing on the dashboard can identify the top risks without opening another page.
- The top risks include identities and attack paths, not only scan checks.
- Each risk shows severity, identity, target, reason, and link/action to inspect details.
- Empty states explain whether no risk exists or whether discovery has not run.

### Tests

- Add Pester tests for any new risk-summary selector function.
- Add Playwright dashboard tests for the new "Needs Attention" section, seeded high-risk identities, seeded attack paths, and empty state.

## Phase 4: Scheduled Discovery And Exposure Change Detection

This is the product shift Simon's security-team feedback requires.

### Work

1. Add a scheduled discovery model using the same discovery pipeline as manual scans.
2. Persist schedule configuration and last-run status locally.
3. Add snapshot comparison that produces local exposure-change records.
4. Capture new risk, removed risk, risk score increase, impacted identity, impacted resource, first seen timestamp, previous state, current state, and evidence.
5. Add a UI surface for reviewing exposure-change records before any external delivery.

### Implementation Notes

- PSU supports scheduled scripts through `New-PSUSchedule`, CRON, continuous schedules, environments, run-as credentials, and computer selection.
- Start by scheduling CIEM's existing discovery script path rather than creating a second discovery execution path.
- Keep the first implementation local and read-only.

### Acceptance Criteria

- A user can configure a scheduled CIEM discovery cadence.
- Scheduled discovery creates the same kind of discovery/run records as manual discovery.
- Exposure-change records are generated deterministically from two snapshots.
- No connector sends data externally in this phase.

### Tests

- Pester: schedule model validation, snapshot comparison, exposure-change record generation.
- Playwright: schedule configuration UI and exposure-change review UI.
- PSU runtime validation: `Invoke-TestCommand` against the schedule/discovery commands in local PSU.

## Phase 5: Connector Payload Previews

Simon specifically named SIEM or alert-management systems as where security teams already work.

### Work

1. Define connector payload models for email, SIEM/webhook, ticketing, and PSU automation.
2. Add payload preview generation from exposure-change records.
3. Include dashboard drill-in link, evidence, previous/current state, severity, owner/routing context when known, and verification steps.
4. Do not send externally until a specific connector target is scoped.

### Acceptance Criteria

- Every exposure-change record can produce a connector payload preview.
- Payloads are evidence-rich enough for a security analyst to decide whether to drill in.
- The UI makes it clear that payloads are previews, not sent alerts, until configured.

### Tests

- Pester: payload schema and required field validation.
- Playwright: preview rendering and empty/missing routing context behavior.

## Phase 6: PAM Fit And Progress View

Simon wants CIEM to help show PAM initiative progress.

### Work

1. Add read-only PAM fit analysis for findings and identities.
2. Classify candidates for JIT access, approval workflow, session governance, access brokering, secret rotation, privileged-account onboarding, and owner review.
3. Add a PAM progress view with exposure baseline, current exposure, risk burn-down, remaining standing access, accepted exceptions, and before/after evidence.
4. Keep all PAM behavior read-only unless Adam explicitly scopes a write operation.

### Implementation Notes

- Devolutions PAM provides the enforcement/adoption layer: JIT access, checkout/check-in, approvals, access brokering, session recording, privileged-account lifecycle, rotation, and reporting.
- CIEM should map evidence to PAM outcomes. It should not duplicate PAM as a remediation lifecycle system.

### Acceptance Criteria

- A stakeholder can use CIEM to explain how PAM adoption is reducing cloud entitlement risk.
- The view distinguishes CIEM-discovered risk from PAM-backed next actions.
- No PAM records are created and no PAM access is changed in this phase.

### Tests

- Pester: PAM fit classification rules.
- Playwright: PAM progress view, baseline/current metrics, candidate details.

## Phase 7: Production PSU Deployment Readiness

Do this before Simon's requested sync with Samuel and Nicolas.

### Work

1. Build a deployment checklist for the Devolutions PSU production instance.
2. Validate PSU version, module import path, app URL, CIEM script registration, managed identity read permissions, and schedule support.
3. Validate whether the production PSU topology is single-node or multi-node.
4. Validate where CIEM's SQLite database file lives and whether every running app/job process sees the same path.
5. Define the supported v1 shape before deployment.

### Acceptance Criteria

- The sync can answer whether CIEM is ready to queue for deployment.
- The sync can answer whether SQLite is safe for the target PSU topology.
- If the topology is multi-node and not proven, the plan states the exact blocker and the recommended storage/scheduling constraint.

### Tests

- Pester: deployment validation command behavior.
- PSU runtime: local and Azure `Invoke-TestCommand` for CIEM provider, app load, script registration, discovery command, and database path.
- Manual: confirm `/ciem` renders and does not show PSU app startup errors.

## Phase 8: Scan Efficiency Guardrails

Simon warned that real Azure customer environments will be much larger than expected.

### Work

1. Measure discovery phase timings and API call counts.
2. Identify N+1 API patterns and repeated full-load calls.
3. Keep UI render paths from triggering expensive discovery or graph rebuild work.
4. Add performance notes to deployment readiness.

### Acceptance Criteria

- Discovery has visible phase timing.
- The app can explain what was collected and how long it took.
- Large-environment risk is handled before production claims are made.

### Tests

- Pester: timing metadata persisted with discovery runs.
- Runtime: run discovery against a known test tenant and capture phase timings.

## Recommended Execution Order

1. Identity view row model and Object ID.
2. Table/grid 1080p usability.
3. Dashboard "Needs Attention" current risk queue.
4. Deployment readiness and SQLite/multi-instance answer.
5. Scheduled discovery.
6. Exposure-change detection.
7. Connector payload previews.
8. PAM fit/progress view.
9. Scan-efficiency instrumentation.

This order gives Simon visible UI fixes quickly, answers his production concern before a deployment sync, and then builds the product direction he asked for without rushing into external writes.

## Definition Of Done

Simon should be able to open CIEM and see:

- The dashboard tells him what needs attention immediately.
- The identity view is identity-first, not target-resource-first.
- Service principals and managed identities can be disambiguated by Object ID.
- Tables are readable on a 1080p display and pagination is reachable.
- There is a clear answer for production PSU deployment and SQLite/multi-instance support.
- Scheduled discovery and exposure-change detection are either implemented or tracked as the next concrete build step.
- PAM value is shown as a progress and routing layer, not just a link or marketing claim.
