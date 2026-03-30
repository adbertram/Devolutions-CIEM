---
description: ErrorActionPreference and exception handling requirements for all PowerShell functions
paths: ["psu-app/**", "Devolutions.CIEM.Admin/**"]
---

# ErrorActionPreference and Exception Handling (MANDATORY)

**Every PowerShell function (public AND private) MUST include `$ErrorActionPreference = 'Stop'` and throw exceptions on failure.**

## Required Pattern

```powershell
function Verb-Noun {
    [CmdletBinding()]
    param(...)

    $ErrorActionPreference = 'Stop'

    # Function body — errors terminate by default
}
```

For functions with `process {}` blocks, place `$ErrorActionPreference = 'Stop'` between the `param()` block and the `process` block (runs in the implicit `begin` block, applies to all blocks):

```powershell
function Verb-Noun {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    $ErrorActionPreference = 'Stop'

    process {
        # Errors terminate here too
    }
}
```

## Rules

1. **Every function gets `$ErrorActionPreference = 'Stop'`** — no exceptions. This converts non-terminating errors to terminating, ensuring failures propagate immediately.

2. **Use `throw` for validation failures** — never `Write-Error`. Throw produces a terminating error the caller must handle.

3. **Intentional graceful degradation must use explicit `-ErrorAction Stop` + `try/catch`** — when a specific call has a known fallback (e.g., Premium P1 API falling back to basic API), wrap ONLY that call in `try/catch` with `-ErrorAction Stop` on the cmdlet. The function-level `$ErrorActionPreference = 'Stop'` still applies to everything else.

4. **Never use `-ErrorAction SilentlyContinue` without justification** — the only acceptable uses are:
   - Cache reads where a miss is expected (e.g., `Get-PSUCache -ErrorAction SilentlyContinue`)
   - `Get-Command` existence checks
   - `Test-Path` alternatives where the cmdlet itself may error on invalid paths

5. **Tab-completion scriptblocks are exempt from throw** — argument completer scriptblocks (`Register-ArgumentCompleter`) should use `try/catch` returning `@()` on failure. The outer registration function still uses `$ErrorActionPreference = 'Stop'`.

## What This Prevents

- Silent data loss from failed database operations
- API errors swallowed without caller awareness
- Half-completed operations where early steps fail but later steps proceed
- "It works sometimes" bugs from intermittent non-terminating errors
