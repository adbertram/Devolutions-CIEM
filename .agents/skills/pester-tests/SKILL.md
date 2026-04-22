---
name: "pester-tests"
description: "MANDATORY: Use this skill for ALL Pester and test-related operations. DO NOT run Invoke-Pester directly via Bash. DO NOT search for test files manually. Triggers: \"run tests\", \"run all tests\", \"create test\", \"review test\", \"test coverage\", \"Invoke-Pester\", \".Tests.ps1\", \"pester\". Covers: TDD workflow, test definitions, CRUD patterns, database isolation, InModuleScope usage, code coverage analysis, test framework rules."
---

<objective>
Single source of truth for all Pester testing in the Devolutions CIEM project.
Handles creating, running, and reviewing Pester tests against a single PowerShell
module (`Devolutions.CIEM`) with dot-sourced sub-folders and SQLite-backed CRUD.
</objective>

<quick_start>

Run all unit tests:
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit
```

Run a specific test file:
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Path psu-app/modules/Azure/Discovery/Tests/Unit/CIEMAzureArmResource.Tests.ps1
```

Run tests by tag:
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite Unit -Tag 'CRUD'
```

Run PSU-backed E2E tests:
```bash
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite E2E -Environment local
pwsh -NoProfile -File scripts/invoke-ciem-tests.ps1 -Suite E2E -Environment azure
```

</quick_start>

<essential_principles>

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

For complete rules and Should operator reference, see [references/test-definitions.md](references/test-definitions.md).

</essential_principles>

<intake>
Route to the appropriate workflow based on user intent:
- If intent is clear from the user's message, route directly
- If ambiguous, ask: "What would you like to do? (create / run / review)"

1. **Create** tests — Write new Pester tests following TDD and project conventions
2. **Run** tests — Execute tests, troubleshoot failures, analyze coverage
3. **Review** tests — Validate test quality against framework rules
</intake>

<routing>

| Intent | Action |
|--------|--------|
| "create test", "write test", "add test", "new test", "TDD" | Read [workflows/create-tests.md](workflows/create-tests.md) |
| "run test", "execute test", "Invoke-Pester", "run all tests" | Read [workflows/run-tests.md](workflows/run-tests.md) |
| "review test", "check test", "validate test", "test quality" | Read [workflows/review-tests.md](workflows/review-tests.md) |
| "test coverage", "coverage analysis", "missing tests" | Read [workflows/run-tests.md](workflows/run-tests.md) § Coverage Analysis |
| "troubleshoot", "test failing", "debug test" | Read [workflows/run-tests.md](workflows/run-tests.md) § Troubleshooting |

After reading the workflow, follow its process for the user's specific situation.

</routing>

<reference_index>

- **[references/test-framework.md](references/test-framework.md)** — Test architecture, module import, DB isolation, directory structure, test categories, common gotchas
- **[references/test-definitions.md](references/test-definitions.md)** — Test definition structure, critical rules, naming conventions, Should operators, anti-patterns
- **[references/code-coverage.md](references/code-coverage.md)** — Coverage analysis workflow, report format, priority levels, implementation plan format

</reference_index>

<project_context>

- **Module**: `Devolutions.CIEM` — single module with dot-sourced sub-folders
- **Entry point**: `psu-app/Devolutions.CIEM.psd1`
- **Database**: SQLite via `PSUSQLite`, accessed through `Invoke-CIEMQuery`
- **`$script:ModuleRoot`**: `psu-app/`
- **`$script:DatabasePath`**: `psu-app/data/ciem.db`
- **Framework**: Pester 5.x, PowerShell 7.5+

</project_context>

<success_criteria>
- Tests follow all rules in test-definitions.md
- CRUD tests use $TestDrive DB isolation
- 0 failures, 0 errors in test run
- Test names describe observable behavior
- No Import-Module -Force anywhere
- Source-only tests do not import the module
- Unit tests mock Write-CIEMLog
</success_criteria>
