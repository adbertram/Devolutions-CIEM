# Debug Workflow - Troubleshoot PSU App Issues

<required_reading>
When PSU docs don't have the answer, use WebSearch for "PowerShell Universal v5 [topic]".
PSU docs location: `./docs/psu-docs/`
</required_reading>

<critical_rule>
**DEBUG BEFORE PUBLISH:** Publishing is slow. ALWAYS test fixes via `Invoke-PSUCommand` BEFORE publishing a new module version.

Workflow: Identify error → Write fix locally → Test fix on PSU via Invoke-PSUCommand → Confirm fix works → THEN publish
</critical_rule>

<process>
## Step 1: Download and search PSU logs (PRIMARY DEBUG TOOL)

**ALWAYS start here.** Download all logs, then search locally:

```bash
# Download all logs from all sources
./scripts/download-psu-logs.sh

# Search the downloaded log file
grep -i "CIEM" psu-logs-*.log          # CIEM-specific entries
grep -i "error" psu-logs-*.log         # All errors
grep -i "authentication" psu-logs-*.log # Auth issues
grep -i "App-Devolutions" psu-logs-*.log # App startup issues
```

**Log sources (all downloaded to single file):**
| Source | Content |
|--------|---------|
| Database | App-level: `[App-Devolutions CIEM]` messages (most useful) |
| Docker | Azure container stdout (ASP.NET Core infrastructure) |
| API | PSU REST API logs |

## Step 2: Identify the symptom

Common issues:
- "Page Not Found" - App not running or wrong URL path
- "Failed to save configuration" - PSU variable/secret API issue
- Blank page - App crashed or JS error
- Stale data - Module not reloaded after publish
- "module could not be loaded" - Module import failure (check db logs)

## Step 3: Check app status

```bash
source .env && curl -s -H "Authorization: Bearer $PSU_TOKEN" \
  "https://devolutions-ciem-psu.azurewebsites.net/api/v1/dashboard" | jq '.[] | {name, status}'
```

Status codes: 1 = Running, 2 = Failed to start

## Step 4: Check PSU variables/secrets

```bash
source .env && curl -s -H "Authorization: Bearer $PSU_TOKEN" \
  "https://devolutions-ciem-psu.azurewebsites.net/api/v1/variable" | jq '.'
```

## Step 5: Check installed modules

```bash
source .env && curl -s -H "Authorization: Bearer $PSU_TOKEN" \
  "https://devolutions-ciem-psu.azurewebsites.net/api/v1/module" | jq '.[] | {name, version}'
```

## Step 7: Read PSU cmdlet documentation

For PSU API issues, check:
- `./docs/psu-docs/cmdlets/` - Cmdlet reference
- `./docs/psu-docs/platform/variables.md` - Secret management

## Step 8: Web search for unknown issues

If local docs don't help:
```
WebSearch: "PowerShell Universal v5 [error message or topic]"
```

## Step 9: Test fix via Invoke-TestCommand.ps1 BEFORE publishing (MANDATORY)

**Publishing is slow.** Always validate your fix works BEFORE publishing.

```bash
# Test locally first (imports module, no PSU needed)
./scripts/Invoke-TestCommand.ps1 -ScriptBlock { Get-CIEMProvider -Name Azure } -Destination local

# Test on local PSU app (runs inside PSU's PowerShell environment)
./scripts/Invoke-TestCommand.ps1 -ScriptBlock {
    (Get-Module Devolutions.CIEM -ListAvailable).Version.ToString()
} -Destination local_psu_app

# Test on Azure PSU app
./scripts/Invoke-TestCommand.ps1 -ScriptBlock {
    Get-CIEMSecret 'CIEM_Azure_TenantId'
} -Destination azure_psu_app
```

**Only after confirming the fix works, proceed to publish:**

```powershell
Publish-PSUModule -ModulePath ./Devolutions.CIEM
```

## Common fixes

**"Page Not Found":**
- Restart the app: `Restart-PSUApp -Name 'Devolutions CIEM'`
- Check URL uses double path: `/ciem/ciem/[page]`

**Secret/variable errors:**
- Use `-Vault 'Database'` not `BuiltInLocalVault` (Linux has no Windows Credential Manager)
- Check if variable exists before Set-PSUVariable

**Module not updating:**
- Restart the app after publishing
- Verify new version imported: check `/api/v1/module` endpoint

**"Property 'Value' cannot be found":**
- Secret doesn't exist or Get-Item returned $null
- Add null check before accessing .Value property
</process>

<success_criteria>
- Root cause identified with evidence
- Fix implemented and verified
- Issue documented if novel
</success_criteria>
