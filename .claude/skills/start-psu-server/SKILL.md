---
name: start-psu-server
description: Starts the PSU server (local or Azure) and waits for it to be ready. Use when starting, launching, or restarting the PSU development or production server.
argument-hint: "[local|azure]"
allowed-tools: Bash
---

<objective>
Starts the PowerShell Universal server for development or production. Supports both the local macOS instance and the Azure webapp. Waits for the server to be fully ready before completing.
</objective>

<quick_start>
Parse the argument to determine target:
- `local` or no argument → Start local PSU at http://localhost:5001
- `azure` → Restart Azure PSU at https://devolutions-ciem-psu.azurewebsites.net

Execute the appropriate startup command and wait for health check to pass.
</quick_start>

<workflow>
<step name="parse-target">
Determine target from $ARGUMENTS:
- Empty, "local", or "dev" → local
- "azure", "prod", or "production" → azure
</step>

<step name="start-local" condition="target is local">
Run the setup script:
```bash
./scripts/setup-local-psu.sh start
```

The script handles already-running detection, binary installation, waiting for ready (120s timeout), and status output.

Report: **Local PSU started at http://localhost:5001**
</step>

<step name="start-azure" condition="target is azure">
**WARNING: Azure PSU takes up to 10 minutes to cold start. Do NOT restart unless necessary.**

1. Check current state:
```bash
curl -s "https://devolutions-ciem-psu.azurewebsites.net/api/v1/alive" | jq '.'
```

2. If response shows `loading: false` and no errors, server is already healthy. Report status and exit without restarting.

3. If endpoint doesn't respond or returns an error, restart:
```bash
az webapp restart --resource-group devolutions-ciem-rg --name devolutions-ciem-psu
```

4. Poll every 15s until `loading` is `false` (timeout 600s):
```bash
curl -s "https://devolutions-ciem-psu.azurewebsites.net/api/v1/alive" | jq '.loading'
```

Report: **Azure PSU running at https://devolutions-ciem-psu.azurewebsites.net**
</step>
</workflow>

<success_criteria>
- Health endpoint returns `loading: false`
- Server URL confirmed accessible
- User informed of the URL
</success_criteria>

<validated>
Validated by validate-skill on 2026-02-09 15:42
</validated>
