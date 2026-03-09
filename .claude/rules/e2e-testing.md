---
description: E2E Playwright testing conventions for PSU CIEM app
paths: ["e2e/**"]
---

# E2E Playwright Testing Rules

## Environment Context

- The local PSU instance (`http://localhost:5001`) has real Azure credentials configured (ServicePrincipalCertificate auth profile)
- Tests SHOULD exercise real functionality (scans, auth testing) — do not skip assuming missing credentials
- The `e2e/_utils/cleanup.js` seeds test data with `_E2E_TEST_` prefix and cleans up in global teardown

## Tool Boundary (CRITICAL)

E2E tests are **Playwright browser tests only**. Never use PowerShell, `Invoke-TestCommand`, PSU API calls, or `pwsh` to verify behavior. All verification happens through the browser UI.

## Never Pipe npx Output

Always run `npx playwright test` without piping through grep, tail, or other filters. Full output must be visible.

## PSU MUI Selector Gotchas

These patterns are specific to how PSU renders MUI components server-side. They differ from standard React MUI apps.

| Pattern | Wrong | Correct | Why |
|---------|-------|---------|-----|
| Sidebar navigation | `.MuiDrawer-root` | `.MuiDrawer-root.MuiDrawer-anchorLeft` | PSU renders 2 drawers (left sidebar + bottom bar) |
| Nav item hrefs | `getAttribute('href')` on `<a>` | `getAttribute('button')` on `<li>` | PSU `New-UDListItem -Href` puts URL in `button` attr on `<li>` |
| Nav item text match | `has-text("Scan")` | `filter({ hasText: new RegExp('^Scan$') })` | Substring match hits "Scan History" too |
| Page redirects | `waitForNavigation()` | `waitForURL('**/path', { timeout: 15000 })` | PSU `Invoke-UDRedirect` is async server-side |
| Text selectors | `text=No failed results` | Scope to parent card: `.MuiCard-root:has-text('Severity') >> text=No failed results` | Same text may appear in multiple PSU cards |
| DataGrid row expand | Click the row | Click `[aria-label="Expand"]` toggle button | MUI DataGrid uses dedicated expand toggle |
| Toast notifications | `.MuiSnackbar-root` | `.iziToast` | PSU uses iziToast library, not MUI Snackbar |
| MUI Select open | Click the `<input>` | Click `[role="combobox"]` | Hidden input is not interactive |
| Dynamic element IDs | `#myDynamicId` | Check actual rendered HTML | `New-UDDynamic -Id` uses internal UUIDs, not the `-Id` value as HTML id |
| Nested cards | `#parent .MuiCard-root` | `#parent > .MuiCard-root` or scope with text content | `New-CIEMErrorContent` nests cards inside cards |

## Scan Execution Tests

- Minimize real scan launches — consolidate into 1-2 tests that share one scan execution
- Use 10-minute timeout for scan completion (`timeout: 600000`)
- Accept both success and error as valid terminal states (auth may not be configured in all environments)

## Test Ordering Awareness

The Scan test file may launch a real scan that creates a "Running" scan run. Subsequent page tests (ScanHistory, Dashboard) must handle this:
- Use `findCompletedRowIndex()` to find rows with "Completed" status instead of assuming row 0
- Don't hard-code expected row counts — other scan runs may exist

## PSU App URL Pattern

PSU app has a double-path prefix: `/ciem/ciem/[page]` (first `/ciem` is the PSU app base, second is the app's internal routing).

## Conventions

- Each page gets a `PageHelpers.js` class extending `BasePage`
- Test files import from `../../_utils/BaseTestSetup` and use `ciemPage` fixture
- Use `testInfo.skip()` for data-dependent conditional tests (e.g., empty state vs populated state)
- Group tests with `test.describe()` using BDD-style names ("when X happens")
- Wait for PSU dynamic content: `waitForTimeout(3000)` after navigation, `waitForTimeout(2000)` after `Sync-UDElement` refreshes
