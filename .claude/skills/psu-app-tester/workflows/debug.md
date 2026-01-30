# Debug Workflow - Troubleshoot PSU App Issues

<required_reading>
When PSU docs don't have the answer, use WebSearch for "PowerShell Universal v5 [topic]".
PSU docs location: `./prowler/docs/psu-docs/`
</required_reading>

<process>
## Step 1: Query PSU logs (PRIMARY DEBUG TOOL)

**ALWAYS start here.** The log script queries all PSU log sources:

```bash
# Get recent logs from all sources
./scripts/get-psu-logs.sh 100

# Search for CIEM-specific errors
./scripts/get-psu-logs.sh 100 --search "CIEM"

# App-level logs only (most useful for app startup issues)
./scripts/get-psu-logs.sh 100 --db-only

# Infrastructure logs only
./scripts/get-psu-logs.sh 100 --docker-only
```

**Log sources:**
| Source | Flag | Content |
|--------|------|---------|
| Database | `--db-only` | App-level: `[App-Devolutions CIEM]` messages |
| Docker | `--docker-only` | Azure container stdout (ASP.NET Core) |
| API | `--api-only` | PSU REST API logs |

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
- `./prowler/docs/psu-docs/cmdlets/` - Cmdlet reference
- `./prowler/docs/psu-docs/platform/variables.md` - Secret management

## Step 8: Web search for unknown issues

If local docs don't help:
```
WebSearch: "PowerShell Universal v5 [error message or topic]"
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
</process>

<success_criteria>
- Root cause identified with evidence
- Fix implemented and verified
- Issue documented if novel
</success_criteria>
