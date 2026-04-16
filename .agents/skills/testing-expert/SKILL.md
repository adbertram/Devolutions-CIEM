---
name: "testing-expert"
description: "MANDATORY: Use this skill for ALL testing work in Devolutions CIEM. DO NOT write, review, or run tests without loading this skill first. Triggers: \"testing-expert\", \"create test\", \"review test\", \"e2e test\", \"playwright test\", \"pester test\", \"test scenarios\", \"test states\", \"test template\", \"write test\", \"test review\", \"test structure\", \"test requirements\", \"run tests\", \"test coverage\". Covers BOTH Playwright E2E and Pester unit/integration tests. Auto-detects framework from file path."
---

<objective>
Comprehensive testing authority for the Devolutions CIEM project. Covers BOTH
Playwright E2E tests (browser UI) and Pester unit/integration tests (PowerShell).
Auto-detects the framework based on file path and applies the correct conventions.
</objective>

<quick_start>

**Playwright E2E tests:**
```bash
# All E2E tests
cd /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ui/e2e && npx playwright test

# Single page
cd /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ui/e2e && npx playwright test pages/Environment/

# Debug mode (headed browser)
cd /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ui/e2e && npx playwright test --headed
```

**Pester unit tests:**
```bash
# All unit tests
pwsh -NoProfile -Command "Invoke-Pester /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ -Output Detailed"

# Single file
pwsh -NoProfile -Command "Invoke-Pester /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureArmResource.Tests.ps1 -Output Detailed"

# By tag
pwsh -NoProfile -Command "Invoke-Pester /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ -Tag 'CRUD' -Output Detailed"
```

</quick_start>

<intake>

**Framework auto-detection:**
- Path contains `psu-app/ui/e2e/` or mentions Playwright/E2E/browser → **Playwright**
- Path contains `psu-app/**/Tests/` or mentions Pester/unit/CRUD/InModuleScope → **Pester**
- If ambiguous, ask: "Is this a UI/browser test (Playwright) or a PowerShell function test (Pester)?"

**Route by intent:**

| Intent | Action |
|--------|--------|
| Create new tests | Go to [Create Workflow](#create-workflow) |
| Review existing tests | Go to [Review Workflow](#review-workflow) |
| Run tests / troubleshoot | Go to [Run Workflow](#run-workflow) |
| Coverage analysis | Go to [Coverage Workflow](#coverage-workflow) |

</intake>

---

# REQUIREMENTS REFERENCE

## Universal Requirements (Both Frameworks)

1. **Every code change MUST have a corresponding test.** No exceptions.
2. **TDD workflow is mandatory:** Write test → confirm fail → implement → run full suite.
3. **Tests document expected behavior.** Fix implementation, not tests (unless requirements change).
4. **0 failures, 0 errors = passing.** ERROR is a failure, not a skip.
5. **Never skip failing tests.** Investigate and fix.
6. **What requires which test type:**
   - New PowerShell function → Pester
   - New CRUD table → Full CRUD Pester test file
   - Bug fix in PowerShell → Pester test reproducing the bug
   - New UI page → Playwright E2E
   - UI behavior change → Playwright E2E
   - Refactor → Existing tests must pass; add tests if coverage gaps exist

## State-Driven Scenario Design (CRITICAL)

This pattern applies to BOTH Playwright and Pester tests. It is the foundation of test organization.

### What is a "State"?

A **state** is the condition under which tests execute. Each `describe`/`Context` block names one state. There are two types:

**1. Environmental State** — external conditions that exist BEFORE the user interacts with the page. These require `beforeAll` setup and `afterAll` cleanup.

| Example | Type | Setup mechanism |
|---------|------|-----------------|
| "when no authentication profile exists" | Auth state | `deactivateAzureAuthProfile()` via PSU API |
| "when a ServicePrincipalCertificate profile is active" | Auth state | `activateAzureAuthProfile()` via PSU API |
| "when discovery data exists in the database" | Data state | `seedEnvironmentData()` via SQLite |
| "when no discovery data exists in the database" | Data state | `backupAndClearAllArmResources()` via SQLite |
| "when the PSU server is not responding" | Infrastructure state | Stop PSU in beforeAll, restart in afterAll |
| "when the Azure token has expired" | Auth state | Inject expired token via PSU Cache |

**2. User Action State** — conditions created by simulating user interaction within the test. These do NOT require `beforeAll`/`afterAll` — the action happens inside `test()` or `it()` blocks.

| Example | Type | How it's triggered |
|---------|------|--------------------|
| "when the user clicks Start Discovery" | Button action | `await envPage.clickStartDiscovery()` |
| "when the user clicks Load Environment" | Button action | `await envPage.clickLoadEnvironment()` |
| "when Azure is selected from the Provider dropdown" | Select action | `await envPage.selectProvider('Azure')` |
| "when the user changes the Layout to Top to Bottom" | Select action | `await envPage.selectLayout('TB')` |

### How to Combine State Types

Describe blocks can NEST environmental state with user action:

```javascript
// Environmental state (outer) — requires setup/teardown
test.describe('when no active authentication profile exists', () => {
  test.beforeAll(async () => { /* deactivate profile, assert state */ });
  test.afterAll(async () => { /* restore profile */ });

  // User action (inner) — no setup needed, action in test body
  test('should show failed toast when clicking Start Discovery', async () => {
    await envPage.clickStartDiscovery();
    // ...assertions about what the UI shows under this state...
  });
});
```

The describe name always answers: **"Under what conditions are these tests running?"**
- Environmental: "when X exists/doesn't exist/is configured/is broken"
- User action: "when the user does X" (only when the action IS the thing being tested)

### Describe Block Lifecycle

Every environmental-state describe block MUST follow this lifecycle:

```
beforeAll:
  1. SET UP the required state (seed data, deactivate profiles, etc.)
  2. ASSERT the state was achieved (query DB, check counts, verify API response)
  3. If assertion fails → skip the group (environment can't support this scenario)

tests:
  Run under the guaranteed state

afterAll:
  RESTORE any state changes (re-activate profiles, restore backed-up data, etc.)
```

User-action describe blocks need NO `beforeAll`/`afterAll` — the action happens in the test itself.

### State Axes Pattern

For any page or function, identify the independent state axes that affect behavior:
- Each axis has discrete values (e.g., auth: `none | active-valid | active-invalid | active-insufficient-perms`)
- Each combination that produces DIFFERENT behavior deserves its own describe/Context block
- Do not create combinatorial explosion — only test combinations where the axis actually affects the tested behavior
- Static page rendering (no state dependency) gets its own describe: "when the page loads"

**Example state axes for Environment page:**
- Auth profile: `none | active-valid | active-insufficient-perms`
- Discovery data: `none | exists`
- Provider selection: `Azure | (unsupported future)`

### Anti-Patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| `testInfo.skip()` inside test body based on ambient state | Test doesn't control its preconditions | Move state check to `beforeAll` — set up the state, don't skip around it |
| `beforeAll` sets up state but doesn't assert it | Tests run under unknown state if setup silently fails | Add assertion after setup: query count, check API response |
| `afterAll` missing when `beforeAll` modifies shared state | Subsequent test groups run under dirty state | Always restore: reactivate profiles, restore backed-up DB rows |
| Describe named "when user clicks X" but has `beforeAll` setting up environmental state | Confusing — mixes state types | Split into environmental describe (outer) + user action test (inner) |
| Generic acceptance: "any toast is visible" | Doesn't test specific behavior under the state | Assert the SPECIFIC toast content expected for this state |

---

# PLAYWRIGHT E2E TEST REQUIREMENTS

## Database Path (CRITICAL)

PSU uses the **publish point's database**, NOT the development source:
- Correct: `/Users/adam/psu/data/ciem.db` (on adam-server, accessed via SSH)
- Wrong: `psu-app/data/ciem.db`
- `test-config.js` uses `resolvePsuDatabasePath()` to find it
- All DB seeding goes to the PSU module's DB

## SQLite WAL Cross-Process Visibility (CRITICAL)

When seeding data via `better-sqlite3` (Node.js) for PSU (`Microsoft.Data.Sqlite`) to read:
- You MUST call `db.pragma('wal_checkpoint(TRUNCATE)')` after writes
- Without checkpoint, PSU's separate process may not see WAL entries
- Apply checkpoint after BOTH seeds AND cleanups

```javascript
// CORRECT — always checkpoint after writes
db.prepare('INSERT OR REPLACE INTO ...').run(...);
db.pragma('wal_checkpoint(TRUNCATE)');

// WRONG — PSU may not see these writes
db.prepare('INSERT OR REPLACE INTO ...').run(...);
db.close();
```

## PSU Cache (Auth Profiles)

Auth profiles are stored in PSU Cache, NOT SQLite:
- Cannot be manipulated via direct DB access
- Use `runPSUCommand()` from `psu-helpers.js` to manage via PSU REST API
- Helpers: `deactivateAzureAuthProfile()` / `activateAzureAuthProfile()`
- Always save previous state and restore in `afterAll`

## Helper Separation of Concerns (CRITICAL)

**Helpers are a transport layer. Tests are the assertion layer.**

Helpers (`psu-helpers.js`, `cleanup.js`, `PageHelpers`) must:
- Execute operations and return raw results
- Never throw on "expected" failures (e.g., PSU job returns Failed status)
- Never assert, validate, or interpret success/failure
- Return structured objects with all data the caller needs to assert

Tests (`beforeAll`, `test()`) must:
- Call helpers to get results
- Assert the result status, counts, and values
- Decide whether to skip, fail, or proceed based on the result

```javascript
// WRONG — helper decides what's an error
async function deactivateAzureAuthProfile() {
  const result = await runPSUCommand('...');
  if (result.status !== 'Completed') throw new Error('Failed');  // ← assertion in helper
  return result.pipelineOutput[0].value;
}

// RIGHT — helper returns raw result, test asserts
async function deactivateAzureAuthProfile() {
  const result = await runPSUCommand('...');
  return { previousActiveId: extractValue(result), result };     // ← transport only
}

// In test beforeAll:
const { previousActiveId, result } = await deactivateAzureAuthProfile();
if (result.status !== 'Completed') {
  test.skip(true, `PSU command ${result.status} (jobId: ${result.jobId})`);  // ← test decides
}
```

`runPSUCommand` returns: `{ jobId, status, statusCode, startTime, endTime, output, pipelineOutput }`
- `status`: string name (`'Completed'`, `'Failed'`, `'TimedOut'`, `'InvocationFailed'`)
- `pipelineOutput`: parsed JSON from PSU pipeline (or null)
- `output`: raw job output array (console messages, errors)

## PSU MUI Selector Gotchas

| Pattern | Wrong | Correct | Why |
|---------|-------|---------|-----|
| Sidebar nav | `.MuiDrawer-root` | `.MuiDrawer-root.MuiDrawer-anchorLeft` | PSU renders 2 drawers |
| Nav item hrefs | `getAttribute('href')` on `<a>` | `getAttribute('button')` on `<li>` | PSU puts URL in `button` attr on `<li>` |
| Nav item text | `has-text("Scan")` | `filter({ hasText: new RegExp('^Scan$') })` | Substring match hits "Scan History" |
| Page redirects | `waitForNavigation()` | `waitForURL('**/path', { timeout: 15000 })` | PSU `Invoke-UDRedirect` is async |
| Text selectors | `text=No failed results` | Scope to parent: `.MuiCard-root:has-text('Severity') >> text=...` | Same text in multiple cards |
| DataGrid expand | Click the row | Click `[aria-label="Expand"]` | MUI DataGrid uses dedicated toggle |
| DataGrid detail content | Wait only for `.MuiDataGrid-detailPanel` | After expanding, wait for expected panel content text such as `Entitlement Path` | PSU `LoadDetailContent` can render after the detail panel shell is already visible |
| Toast notifications | `.MuiSnackbar-root` | `.iziToast` | PSU uses iziToast, not MUI Snackbar |
| MUI Select open | Click `<input>` | Click `[role="combobox"]` | Hidden input is not interactive |
| Dynamic element IDs | `#myDynamicId` | Check actual rendered HTML | `New-UDDynamic -Id` uses internal UUIDs |
| Clipboard assertions on local PSU | Read `navigator.clipboard` directly on `http://192.168.86.30:5001` | Install a test-only clipboard shim with `page.addInitScript()` before navigation | Chromium does not expose Clipboard API on private-IP HTTP origins |
| Nested cards | `#parent .MuiCard-root` | `#parent > .MuiCard-root` or scope with text | `New-CIEMErrorContent` nests cards |
| `:has-text()` | `.MuiCard-root:has-text("Tenants")` | Locator chaining: `.MuiTypography-caption`, `{ hasText: /^Tenants$/ }` | `:has-text()` matches any ancestor |

## Test Data Convention

- All test data uses `_E2E_TEST_` prefix for IDs
- Seed functions use `INSERT OR REPLACE` for idempotency
- Cleanup functions delete by `_E2E_TEST_` prefix
- Global setup/teardown in `_utils/global-setup.js` and `_utils/global-teardown.js`

## File Structure

```
psu-app/ui/e2e/
├── _utils/
│   ├── BasePage.js          # Base class with common selectors/helpers
│   ├── BaseTestSetup.js     # Fixture definitions (ciemPage)
│   ├── cleanup.js           # Seed/cleanup functions (seedTestData, seedEnvironmentData, etc.)
│   ├── database.js          # Direct DB query helpers (read-only)
│   ├── global-setup.js      # Runs before all tests (PSU health, seed)
│   ├── global-teardown.js   # Runs after all tests (cleanup, close DB)
│   ├── psu-helpers.js       # PSU server helpers (health, start, runPSUCommand, auth profile mgmt)
│   └── test-config.js       # URLs, paths, timeouts (resolves PSU DB path dynamically)
├── pages/
│   └── PageName/
│       ├── PageName.test.js
│       └── PageNamePageHelpers.js
└── playwright.config.js
```

## Playwright Config Notes

- `fullyParallel: false`, `workers: 1` — tests run sequentially (shared PSU state)
- `timeout: 120000` (2 min per test)
- `expect.timeout: 15000` (15s for assertions)
- `globalSetup` ensures PSU is running and data is seeded
- `globalTeardown` cleans test data

## Playwright Test Template

```javascript
const { test, expect } = require('../../_utils/BaseTestSetup');
const XxxPageHelpers = require('./XxxPageHelpers');
const { seedXxx, cleanupXxx } = require('../../_utils/cleanup');
const { deactivateAzureAuthProfile, activateAzureAuthProfile } = require('../../_utils/psu-helpers');

test.describe('Xxx Page', () => {
  let xxxPage;

  test.beforeEach(async ({ ciemPage }) => {
    xxxPage = new XxxPageHelpers(ciemPage);
    await xxxPage.navigateToXxxPage();
  });

  // --- Static UI verification (no state setup needed) ---
  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await xxxPage.getPageTitle();
      expect(title).toContain('Expected Title');
    });
  });

  // --- State-driven scenario ---
  test.describe('when [STATE CONDITION]', () => {
    let previousState = null;

    test.beforeAll(async () => {
      // 1. Set up required state — helpers return raw results, not assertions
      const { previousActiveId, result } = await deactivateAzureAuthProfile();

      // 2. Assert the helper executed successfully
      if (result.status !== 'Completed') {
        test.skip(true, `Could not set up state: PSU command ${result.status} (jobId: ${result.jobId})`);
        return;
      }
      previousState = previousActiveId;

      // 3. Assert the state was actually achieved
      const { count, result: verifyResult } = await getActiveAzureAuthProfileCount();
      if (verifyResult.status !== 'Completed' || count !== 0) {
        test.skip(true, `State verification failed: ${count} active profiles remain`);
        return;
      }
      console.log('[setup] State established for [scenario]');
    });

    test.afterAll(async () => {
      // 4. Restore previous state
      if (previousState) {
        const restoreResult = await activateAzureAuthProfile(previousState);
        console.log(`[teardown] Restored (status: ${restoreResult.status})`);
      }
    });

    test('should [expected behavior]', async () => {
      // ...assertions...
    });
  });
});
```

## PageHelpers Template

```javascript
const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class XxxPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Page Title')",
      // Define ALL selectors here — never inline in tests
    };
  }

  async navigateToXxxPage() {
    await this.goto(testConfig.pages.xxx);
    await this.page.waitForTimeout(3000); // PSU dynamic content render
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }
}

module.exports = XxxPageHelpers;
```

## Playwright Timeouts

| Context | Timeout | Notes |
|---------|---------|-------|
| Page load | 30s | `navigationTimeout` in config |
| Dynamic content | 15s | `waitForTimeout(3000)` after navigation |
| Scan execution | 600s (10 min) | `testInfo.setTimeout(600000)` |
| Discovery | 90s for result toast | Auth-dependent operation |
| PSU server start | 120s | Global setup polling |

## PSU App URL Pattern

Double path prefix: `/ciem/ciem/[page]` — first `/ciem` is the PSU app base, second is internal routing.

## PSU Runtime Knowledge (Learned from Production)

### PSU Job Status Codes

| Status | Code | Terminal? | Meaning |
|--------|------|-----------|---------|
| Queued | 0 | No | Waiting to run |
| Running | 1 | No | Currently executing |
| Completed | 2 | Yes | Finished successfully |
| Failed | 3 | Yes | Threw terminating error |
| Canceled | 5 | Yes | Manually cancelled |
| TimedOut | 9 | Yes | Exceeded timeout |
| Warning | 10 | Yes | Non-terminating error, no output |
| WarningOutput | 11 | Yes | Non-terminating error WITH output — most common for commands that succeed but emit warnings |

### PSU Job API Shape

The job list endpoint returns a paginated object, NOT a flat array:
```javascript
// WRONG: const jobs = await fetch('.../api/v1/job?status=1').then(r => r.json());
// RIGHT:
const data = await fetch('.../api/v1/job?status=1&take=100').then(r => r.json());
const jobs = data.page; // Array of jobs
const total = data.total; // Total count
```

### PSU Executor Script Scope

Only **exported (public)** functions are available in executor scripts (`CIEMExecutor.ps1`). Private functions (e.g., `Get-CIEMAzureAuthProfileCache`) are NOT visible. For direct cache manipulation, use PSU built-ins:
- `Get-PSUCache -Key 'CIEM:AuthProfiles:Azure' -ErrorAction SilentlyContinue`
- `Set-PSUCache -Key 'CIEM:AuthProfiles:Azure' -Value $profiles -Persist`

### PSU Cache Staleness

After writing to PSU Cache via `Set-PSUCache` from the executor, public functions like `Get-CIEMAzureAuthenticationProfile` may return stale data (they read from `$script:` module state cached at load time). For verification after direct cache writes, always read from `Get-PSUCache` directly.

### better-sqlite3 Column Casing

`better-sqlite3` preserves column name casing from the schema. Use exact case: `row.Token` not `row.token`.

### Zombie PSU Jobs

Killed test runs leave running/queued jobs in PSU. Call `cancelRunningPSUJobs()` before running PSU commands to clear the queue. Consider adding to global setup.

## Tool Boundary (CRITICAL)

E2E tests are **Playwright browser tests only**. Never use PowerShell, `Invoke-TestCommand`, PSU API calls, or `pwsh` to verify behavior in E2E tests. All verification happens through the browser UI. The only exception is `runPSUCommand()` in `psu-helpers.js` for STATE SETUP/TEARDOWN — and even then, helpers return raw results for the TEST to assert, not the helper.

## Scan Execution Test Rules

- Minimize real scan launches — consolidate into 1-2 tests that share one scan execution
- Use 10-minute timeout for scan completion
- Accept both success and error as valid terminal states (auth may not be configured in all environments)

## Test Ordering Awareness

Scan tests may launch a real scan creating a "Running" scan run. Subsequent page tests must handle this:
- Use `findCompletedRowIndex()` to find rows with "Completed" status instead of assuming row 0
- Do not hard-code expected row counts — other scan runs may exist

---

# PESTER TEST REQUIREMENTS

## Essential Principles

1. **Single module scope** — Always `InModuleScope Devolutions.CIEM`. Sub-folders are dot-sourced, not real modules.
2. **$TestDrive isolation** — CRUD tests redirect `$script:DatabasePath` to `$TestDrive/ciem.db`. Never touch the dev database.
3. **Never `Import-Module -Force`** — Breaks PowerShell classes. Use `Remove-Module -Force` then `Import-Module` without `-Force`.
4. **Block purity** — Setup in `BeforeAll`/`BeforeEach`. Assertions in `It` blocks. No mixing.
5. **Native Should operators** — Use `Should -Exist`, `Should -Contain`, `Should -Match` — never `Should -Be $true` with PowerShell operators.
6. **Behavioral test names** — Answer "what happens?" not "what exists?"
7. **No error silencing** — Never `-ErrorAction SilentlyContinue` in `It` blocks.
8. **TDD is mandatory** — Write tests FIRST, confirm fail, implement, confirm pass.
9. **Mock Write-CIEMLog** — Unit tests that import the module must `Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}`.
10. **Source-only tests skip import** — Tests using only `Get-Content -Raw` + `Should -Match` must NOT `Import-Module`.

## Pester File Structure

```
psu-app/
├── Tests/Unit/                              # Module-level unit tests
│   ├── Psm1Structure.Tests.ps1              # Source assertions (no import)
│   ├── PSUIntegration.Tests.ps1             # Class/structure via InModuleScope
│   └── ModuleLoad.Tests.ps1                 # Export validation via Get-Command
│
├── modules/Azure/Discovery/Tests/Unit/      # Discovery unit tests
│   ├── CIEMAzureArmResource.Tests.ps1       # CRUD ($TestDrive DB)
│   └── ...
│
├── modules/Azure/Infrastructure/Tests/
│   ├── Unit/ConnectCIEMAzure.Tests.ps1      # Source assertions + structure
│   └── E2E/Azure/Authentication/            # E2E (requires PSU)
```

## Test Categories

| Category | DB Needed | Import Module | Example |
|----------|-----------|---------------|---------|
| Source Assertion | No | No | `Get-Content -Raw` + `Should -Match` |
| Structure | No | Yes | `Get-Command -Module` + parameter checks |
| Schema | Yes | Yes | Table creation validation |
| Classes | No | Yes | Property tests via `InModuleScope` |
| CRUD | Yes | Yes | Full lifecycle (New/Get/Update/Save/Remove) |
| Command | No | Yes | Parameter sets + concurrency |

## Module Import Pattern

```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}
```

## Database Isolation Pattern (CRUD Tests)

```powershell
BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..path..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    New-CIEMDatabase -Path "$TestDrive/ciem.db"
    $schema = Join-Path $PSScriptRoot '..path..' 'Data' 'schema_file.sql'
    Invoke-CIEMQuery -Query (Get-Content $schema -Raw)
    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}
```

## CRUD Test Completeness Checklist

For every CRUD function set, verify these tests:

### New- (Create)
- [ ] Creates successfully with required parameters
- [ ] Returns correctly typed object
- [ ] Throws on duplicate (if UNIQUE constraint)
- [ ] Accepts -InputObject parameter set
- [ ] Mandatory parameters validated

### Get- (Read)
- [ ] Returns all records when no filter
- [ ] Returns correctly typed objects (`.GetType().Name`)
- [ ] Filters by each parameter (-Id, -Type, -Name, etc.)
- [ ] Returns empty array when no match

### Update- (Partial Update)
- [ ] Updates specified fields only
- [ ] Does not overwrite unspecified fields
- [ ] Returns nothing without -PassThru
- [ ] Returns updated object with -PassThru
- [ ] Accepts -InputObject for full object update

### Save- (Upsert)
- [ ] Inserts new record
- [ ] Updates existing record
- [ ] Accepts -InputObject via pipeline

### Remove- (Delete)
- [ ] Removes by -Id
- [ ] Removes by scope-appropriate bulk param (e.g., -Type, -All)
- [ ] Removes via -InputObject
- [ ] No-ops when Id does not exist

## Should Operator Reference

| Instead of | Use |
|------------|-----|
| `(Test-Path $p) \| Should -Be $true` | `$p \| Should -Exist` |
| `$a -contains $b \| Should -Be $true` | `$a \| Should -Contain $b` |
| `$s -match 'x' \| Should -Be $true` | `$s \| Should -Match 'x'` |
| `$o -is [Type] \| Should -Be $true` | `$o \| Should -BeOfType [Type]` |
| `$a.Count \| Should -Be $n` | `$a \| Should -HaveCount $n` |
| `$v \| Should -Be $null` | `$v \| Should -BeNullOrEmpty` |
| `$v \| Should -Be $true` | `$v \| Should -BeTrue` |
| `$v \| Should -Be $false` | `$v \| Should -BeFalse` |

## Pester Anti-Patterns

```powershell
# WRONG — object creation in assertion block
It 'creates resource' {
    $resource = New-CIEMAzureArmResource -Id 'test' ...
    $resource | Should -Not -BeNullOrEmpty
}
# RIGHT — setup in BeforeAll/BeforeEach, assertion in It
BeforeAll { $script:resource = New-CIEMAzureArmResource ... }
It 'creates resource' { $script:resource | Should -Not -BeNullOrEmpty }

# WRONG — conditional logic in assertions
It 'validates type' {
    if ($script:result.Type -eq 'User') { ... }
}
# RIGHT — split into separate tests

# WRONG — error silencing
BeforeAll { $script:result = Get-X -ErrorAction SilentlyContinue }
# RIGHT
BeforeAll { $script:result = Get-X -ErrorAction Stop }

# WRONG — testing structure not behavior
It 'Has Id property' { ... }
# RIGHT — testing behavior
It 'Creates ARM resource with specified Id' { ... }
```

## Data Cleanup Between Contexts

Write-operation Contexts need `BeforeEach` cleanup:
```powershell
Context 'New-CIEMAzureArmResource' {
    BeforeEach {
        InModuleScope Devolutions.CIEM {
            Invoke-CIEMQuery -Query "DELETE FROM azure_arm_resources"
        }
    }
}
```
Read-only Contexts can use `BeforeAll` for seeding.

## Unit Test Isolation Rules

Unit tests MUST NOT:
- Read/write real filesystem paths (`ciem.log`, `ciem.db`) — use `$TestDrive` or mocks
- Make network calls to Azure, Graph, or any external API
- Depend on PSU running (`Get-PSUCache`, `Set-PSUCache`)
- Use `-ErrorAction SilentlyContinue` in `It` blocks

## Test Removal Policy

NEVER remove or comment out tests without explicit user approval. Analyze and attempt to fix first. If unfixable, explain the issue and propose options. Only remove after explicit approval.

---

# WORKFLOWS

<a id="create-workflow"></a>
## Create Workflow

### For Playwright E2E Tests

1. **Identify the page being tested** — read the PSU page source in `psu-app/modules/Devolutions.CIEM.PSU/Pages/`
2. **Map all STATE AXES** that affect the page's behavior:
   - Auth profile state (none / active-valid / active-insufficient-perms)
   - Data state (empty / seeded / real)
   - User action state (button clicks, form inputs)
3. **For each state value that produces different UI behavior**, create a `test.describe` block
4. **For each describe**: define `beforeAll` (setup + assert), test cases, `afterAll` (restore)
5. **Create PageHelpers class** extending `BasePage`:
   - All selectors in `this.selectors` object
   - Navigation method with `waitForTimeout(3000)` for PSU dynamic content
   - Helper methods for each user interaction
6. **Add seed/cleanup functions** to `cleanup.js` if new data types are needed:
   - Use `_E2E_TEST_` prefix for all IDs
   - `INSERT OR REPLACE` for idempotency
   - `db.pragma('wal_checkpoint(TRUNCATE)')` after writes
7. **Run the tests**, verify all pass

### For Pester Tests

1. **Read source code** (MANDATORY) — identify parameters, parameter sets, return types, error paths
2. **Check existing tests** in the same directory — avoid duplicate coverage
3. **Determine test sub-type**:
   - Source assertion (no import) — `Get-Content -Raw` + `Should -Match`
   - Structure (import + mock) — `Get-Command`, parameter validation
   - CRUD (import + $TestDrive + mock) — full lifecycle
4. **Write the test FIRST** (TDD red phase)
5. **Run it** — confirm it FAILS
6. **Implement the code** — make it pass
7. **Run full suite** — confirm no regressions
8. For CRUD: verify against the CRUD Test Completeness Checklist above

<a id="review-workflow"></a>
## Review Workflow

### For Playwright E2E Tests

1. Does every `test.describe` block represent a specific **state condition**?
2. Does every `test.beforeAll` set up AND assert the required state?
3. Does every `test.afterAll` restore state changes?
4. Are there any `testInfo.skip()` calls that should be replaced with proper state setup?
5. Are selectors specific enough? (no ambiguous `:has-text()` on ancestor elements)
6. Is the correct database path being used? (PSU module DB, not dev DB)
7. Do cross-process DB writes include WAL checkpoint?
8. Are toasts asserted for specific content, not just "any toast visible"?
9. Are selectors defined in PageHelpers, not inlined in test files?
10. Does the test use `ciemPage` fixture from `BaseTestSetup`?

### For Pester Tests

1. Module import: source-only tests have NO `Import-Module`? Other tests use `Remove-Module -Force` + `Import-Module` (no `-Force`)?
2. Module mock: `Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}` present?
3. InModuleScope: uses `Devolutions.CIEM` only? (never sub-folder names)
4. DB isolation: CRUD tests use `$TestDrive`?
5. Block purity: assertions ONLY in `It` blocks? No object creation in assertion blocks?
6. Native Should operators used? (no `Should -Be $true` with PowerShell operators)
7. Behavioral test names? (answer "what happens?")
8. No `-ErrorAction SilentlyContinue` in `It` blocks?
9. CRUD completeness: all 5 operations tested? Both parameter sets?
10. Data isolation: `BeforeEach` cleanup for write-operation Contexts?

### Review Verdict

Every review MUST end with one of:

**APPROVED** — all checks pass.

**REJECTED** — with blocking issues:
```
VERDICT: REJECTED

BLOCKING ISSUES:
1. [File:Line] Issue description
   FIX: Specific remediation steps
```

### Critical Violations (Always Reject)

**Playwright:**
- Missing WAL checkpoint after DB writes
- Using dev DB path instead of PSU module DB
- Ambiguous `:has-text()` selectors on ancestor elements
- Missing state restoration in `afterAll`
- Inline selectors instead of PageHelpers
- Helpers that assert/throw instead of returning raw results (transport layer violation)

**Pester:**
- Wrong InModuleScope target (sub-folder name)
- No $TestDrive isolation for CRUD tests
- Block purity violation
- Conditional logic in assertions
- `Import-Module -Force`
- Missing `Mock Write-CIEMLog`
- `-ErrorAction SilentlyContinue` in `It` blocks

<a id="run-workflow"></a>
## Run Workflow

### Playwright

```bash
# All E2E tests (never pipe through grep/tail/head)
cd /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ui/e2e && npx playwright test

# Single page
cd /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ui/e2e && npx playwright test pages/PageName/

# Debug (headed)
cd /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ui/e2e && npx playwright test --headed

# With trace
cd /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ui/e2e && npx playwright test --trace on
```

### Pester

```bash
# All tests
pwsh -NoProfile -Command "Invoke-Pester /Users/adam/Dropbox/GitRepos/Devolutions-CIEM/psu-app/ -Output Detailed"

# Diagnostic (max verbosity for debugging)
pwsh -NoProfile -Command "Invoke-Pester path/to/test.Tests.ps1 -Output Diagnostic"
```

### Interpreting Results

- **Passing run**: 0 Failed, 0 Error
- **ERROR is a failure**, not a skip
- **Container failures** (Pester): usually mean `BeforeAll` failed — check module import, DB setup, or missing schema
- **Timeout failures** (Playwright): check PSU is running, increase timeout, or check selector correctness

### Troubleshooting

1. **Check CIEM boot log:** `tail -50 psu-app/data/ciem.log`
2. **Check PSU health:** `curl -s http://localhost:5001/api/v1/alive | jq`
3. **Verify DB schema (Pester):** `Invoke-CIEMQuery -Query "SELECT name FROM sqlite_master WHERE type='table'"`
4. **Check module exports:** `Get-Command -Module Devolutions.CIEM | Sort-Object Name`
5. **Fix implementation, not test** — after 2 failed fixes, STOP and present options

| Symptom | Cause | Fix |
|---------|-------|-----|
| Container failed (Pester) | BeforeAll threw | Check module import path, schema files |
| Connection refused (Playwright) | PSU not running | Start local PSU |
| Type not found (Pester) | Class not in scope | Use `InModuleScope Devolutions.CIEM` |
| Table not found (Pester) | Missing schema | Apply provider-specific `.sql` after `New-CIEMDatabase` |
| Classes break (Pester) | `Import-Module -Force` | Use `Remove-Module -Force` then `Import-Module` (no `-Force`) |
| Selector timeout (Playwright) | Wrong selector or slow render | Check MUI gotchas table, increase timeout |
| WAL visibility (Playwright) | Missing checkpoint | Add `db.pragma('wal_checkpoint(TRUNCATE)')` |

<a id="coverage-workflow"></a>
## Coverage Workflow

### Pester Coverage Analysis

For each function under test:
1. Read source code — identify parameters, parameter sets, return types, error paths
2. Read existing tests — map which scenarios are covered
3. Identify gaps — uncovered parameters, missing error paths, untested combinations
4. Prioritize: P1 (critical CRUD ops), P2 (filter params, -PassThru), P3 (edge cases)

### Playwright Coverage Analysis

For each page:
1. Map all state axes (auth, data, user actions)
2. Map existing test describes to state combinations
3. Identify untested state combinations that produce different behavior
4. Prioritize: P1 (core user flows), P2 (error states), P3 (edge cases)

---

# PROJECT CONTEXT

- **Module**: `Devolutions.CIEM` — single module with dot-sourced sub-folders
- **Module root**: `psu-app/`
- **Database (dev)**: `psu-app/data/ciem.db`
- **Database (PSU runtime)**: `/Users/adam/psu/data/ciem.db` (on adam-server)
- **Pester framework**: Pester 5.x, PowerShell 7.5+
- **Playwright framework**: Playwright (Node.js), Chromium only
- **PSU URL**: `http://localhost:5001` (local), double-path `/ciem/ciem/[page]`
- **E2E test data prefix**: `_E2E_TEST_`

<success_criteria>

**For created tests:**
- State-driven design with proper setup/assert/restore lifecycle
- Correct framework conventions applied (Pester or Playwright)
- All tests pass with 0 failures, 0 errors
- No regressions in existing tests
- Test names describe observable behavior

**For reviewed tests:**
- All rules checked systematically
- Critical violations identified with actionable fix instructions
- Clear APPROVED or REJECTED verdict

**For test runs:**
- 0 failures, 0 errors
- Failures investigated and root-caused (not rationalized)

</success_criteria>
