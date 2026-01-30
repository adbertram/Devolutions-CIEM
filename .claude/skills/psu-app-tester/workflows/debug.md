# Debug Workflow - Troubleshoot PSU App Issues

<required_reading>
When PSU docs don't have the answer, use WebSearch for "PowerShell Universal v5 [topic]".
PSU docs location: `./prowler/docs/psu-docs/`
</required_reading>

<process>
## Step 1: Identify the symptom

Common issues:
- "Page Not Found" - App not running or wrong URL path
- "Failed to save configuration" - PSU variable/secret API issue
- Blank page - App crashed or JS error
- Stale data - Module not reloaded after publish

## Step 2: Check app status

```bash
source .env && curl -s -H "Authorization: Bearer $PSU_TOKEN" \
  "https://devolutions-ciem-psu.azurewebsites.net/api/v1/dashboard" | jq '.[] | {name, status}'
```

## Step 3: Check PSU variables/secrets

```bash
source .env && curl -s -H "Authorization: Bearer $PSU_TOKEN" \
  "https://devolutions-ciem-psu.azurewebsites.net/api/v1/variable" | jq '.'
```

## Step 4: Check installed modules

```bash
source .env && curl -s -H "Authorization: Bearer $PSU_TOKEN" \
  "https://devolutions-ciem-psu.azurewebsites.net/api/v1/module" | jq '.[] | {name, version}'
```

## Step 5: Read PSU cmdlet documentation

For PSU API issues, check:
- `./prowler/docs/psu-docs/cmdlets/` - Cmdlet reference
- `./prowler/docs/psu-docs/platform/variables.md` - Secret management

## Step 6: Web search for unknown issues

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
