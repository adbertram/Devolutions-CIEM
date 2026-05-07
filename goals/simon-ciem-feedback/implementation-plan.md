# Simon CIEM Feedback Implementation Plan

## Summary

Implement Simon Chalifoux's CIEM feedback on branch `simon-ciem-feedback-program` with phase checkpoints and reviewable commits. Preserve `simon-feedback.md` and `implementation-instructions.md` as source context.

Execution order:

1. Identity-first UI row model and Object ID.
2. 1080p table/grid usability.
3. Dashboard Needs Attention risk queue.
4. Production PSU readiness and SQLite topology answer.
5. Scheduled discovery.
6. Exposure-change detection.
7. Connector payload previews.
8. PAM fit and progress view.
9. Scan-efficiency instrumentation.

## Key Changes

- Replace the top-level Identities grid row model with one row per `{ provider, principalId }`.
- Show Object ID / Principal ID clearly on identity rows and details.
- Move target resources, entitlements, paths, actions, and evidence into identity detail content.
- Audit CIEM tables and grids for 1080p usability, with compact fixed widths for low-value columns and detail panels for long text.
- Add a Dashboard Needs Attention section sourced from identity risk summaries and materialized attack paths.
- Add read-only production deployment validation for PSU version, module import, app URL, script registration, managed identity read capability, schedule support, DB path, and topology.
- Add scheduled discovery configuration using the existing `Start-CIEMAzureDiscovery` pipeline and PSU schedules.
- Add deterministic local exposure-change records from discovery snapshots.
- Add connector payload previews only. Do not send alerts externally.
- Add read-only PAM fit classification and progress reporting.
- Add discovery timing and scan-efficiency instrumentation.

## Interfaces And Data

- Add model functions where behavior needs Pester coverage instead of embedding product logic in PSU pages.
- Add SQLite tables only for durable product state: schedule config/status, exposure changes, connector preview metadata if required, PAM baseline/progress state, and discovery timing metadata.
- Keep discovery, connector, PAM, SIEM, ticketing, IdP, and cloud workflows read-only unless Adam explicitly scopes writes.
- Treat single PSU instance plus one CIEM SQLite database path as the supported v1 storage shape until multi-node behavior is tested.

## Test Plan

- Use TDD per phase: write Pester and/or Playwright coverage first, confirm the expected failure, implement, then run targeted tests to green.
- Use `scripts/invoke-ciem-tests.ps1 -Suite Unit` for Pester and targeted unit paths.
- Use `scripts/invoke-ciem-tests.ps1 -Suite Playwright -Environment local` or page-specific Playwright commands through the project runner for PSU UI changes.
- After local publish, use `Publish-PSUModule -LocalOnly` and targeted `Invoke-TestCommand` checks for PSU runtime behavior.
- Capture or inspect identity/table-heavy pages at `1920x1080` and `1366x768` before closing UI phases.

## Phase Checkpoints

### Phase 1: Identity-First UI

- Pester covers the grouped identity row model.
- Playwright covers one row per identity, Object ID visibility, and detail expansion for target access.
- Local PSU page validation confirms duplicate-looking top-level principal rows are removed.

### Phase 2: 1080p Table Usability

- Playwright asserts pagination visibility and key text visibility on identity and table-heavy pages.
- Screenshots or browser inspection cover `1920x1080` and `1366x768`.

### Phase 3: Dashboard Needs Attention

- Pester covers the risk selector.
- Playwright covers high-risk identity, attack path, and empty states.

### Phase 4: Production Readiness

- Pester covers the deployment validation command.
- Local and Azure runtime checks validate app load, script registration, discovery command, and database path.

### Phase 5: Scheduled Discovery

- Pester covers schedule config validation and persistence.
- Playwright covers schedule UI.
- Local PSU runtime validates the scheduled discovery command path.

### Phase 6: Exposure Changes

- Pester covers snapshot comparison and exposure-change persistence.
- Playwright covers the exposure-change review UI.

### Phase 7: Connector Payload Previews

- Pester covers payload schema and required fields.
- Playwright covers preview rendering and missing routing context.

### Phase 8: PAM Fit And Progress

- Pester covers PAM fit classification.
- Playwright covers PAM progress metrics and candidate details.

### Phase 9: Scan-Efficiency Instrumentation

- Pester covers discovery timing metadata persistence.
- Runtime validation captures phase timings against a known test tenant.

## Correction Log

- Created during implementation start from the proposed plan approved by Adam with `go`.
