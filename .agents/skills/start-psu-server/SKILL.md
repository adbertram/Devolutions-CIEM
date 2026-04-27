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
- `local` or no argument → "local" PSU on adam-server via the current ngrok tunnel URL from `ngrok api tunnels list`
- `azure` → Restart Azure PSU at https://devolutions-ciem-psu.azurewebsites.net

Execute the appropriate startup command and wait for health check to pass.
</quick_start>

<workflow>
<step name="parse-target">
Determine target from $ARGUMENTS:
- Empty, "local", "dev", or "adam-server" → local
- "azure", "prod", or "production" → azure
</step>

<step name="start-local" condition="target is local">
The "local" PSU is the always-on instance on adam-server (Mac Mini via Tailscale), managed by the `com.psu.server` LaunchDaemon (KeepAlive=true, so it's normally already running).

1. Check if it's already responding:
```bash
PUBLIC_PSU_URL=$(ngrok api tunnels list --limit 20 --log false | jq -r '.tunnels[] | select(.forwards_to == "http://localhost:5001") | .public_url' | head -n 1)
curl -s --max-time 5 "$PUBLIC_PSU_URL/api/v1/alive"
```
If `loading: false`, it's already running. Report and exit.

2. If unreachable, kickstart the LaunchDaemon:
```bash
ssh adam-server 'sudo launchctl kickstart -k system/com.psu.server'
```

3. Poll until ready (timeout 60s):
```bash
PUBLIC_PSU_URL=$(ngrok api tunnels list --limit 20 --log false | jq -r '.tunnels[] | select(.forwards_to == "http://localhost:5001") | .public_url' | head -n 1)
for i in $(seq 1 20); do
  R=$(curl -s --max-time 5 "$PUBLIC_PSU_URL/api/v1/alive" 2>/dev/null)
  echo "$R" | grep -q '"loading":false' && break
  sleep 3
done
```

Report: **adam-server PSU running at http://192.168.86.30:5001 (LOCAL_PSU_URL from .env)**
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
