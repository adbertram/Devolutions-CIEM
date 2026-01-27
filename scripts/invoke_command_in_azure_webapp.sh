#!/bin/bash
# Invoke commands for PSU web app troubleshooting via Kudu API
#
# IMPORTANT: Commands run in the Kudu sidecar container, NOT the PSU app container.
# The Kudu container shares /home filesystem with the app, so file operations work.
# For commands that need to run IN the PSU container (like querying loaded modules),
# use the PSU REST API or interactive SSH (if enabled in the container image).
#
# For more info on Azure App Service container architecture:
# https://learn.microsoft.com/en-us/azure/app-service/configure-linux-open-ssh-session
set -euo pipefail

RESOURCE_GROUP="devolutions-ciem-rg"
APP_NAME="devolutions-ciem-psu"
SCM_URL="https://${APP_NAME}.scm.azurewebsites.net"
PSU_URL="https://${APP_NAME}.azurewebsites.net"

# Get Kudu publishing credentials
get_credentials() {
    az webapp deployment list-publishing-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_NAME" \
        --query "[publishingUserName, publishingPassword]" -o tsv 2>/dev/null
}

# Execute command in Kudu container via API
kudu_exec() {
    local cmd="$1"
    local creds
    creds=$(get_credentials)
    local user=$(echo "$creds" | head -1)
    local pass=$(echo "$creds" | tail -1)

    # Build JSON payload using jq for proper escaping
    # Wrap in bash -c to support shell features (pipes, redirects, etc.)
    local payload
    payload=$(jq -n --arg cmd "bash -c \"$cmd\"" '{"command": $cmd, "dir": "/home"}')

    local response
    response=$(curl -s -u "${user}:${pass}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${SCM_URL}/api/command")

    local output=$(echo "$response" | jq -r '.Output // empty')
    local error=$(echo "$response" | jq -r '.Error // empty')
    local exit_code=$(echo "$response" | jq -r '.ExitCode // "0"')

    [[ -n "$output" ]] && echo "$output"
    [[ -n "$error" ]] && echo "Error: $error" >&2

    # Ensure exit_code is numeric
    [[ "$exit_code" =~ ^[0-9]+$ ]] || exit_code=0
    return "$exit_code"
}

# Query PSU REST API (runs against actual PSU app)
psu_api() {
    local endpoint="$1"
    local token="${PSU_APP_TOKEN:-}"

    if [[ -z "$token" ]]; then
        echo "Error: PSU_APP_TOKEN environment variable not set" >&2
        echo "Get a token from PSU Admin > Settings > Tokens" >&2
        return 1
    fi

    curl -s -H "Authorization: Bearer $token" "${PSU_URL}${endpoint}"
}

# Open interactive SSH session (requires SSH enabled in container image)
interactive_ssh() {
    echo "Opening interactive SSH session..."
    echo "Note: This requires SSH to be enabled in the container image."
    echo "The PSU container may not have SSH configured."
    echo ""
    az webapp ssh \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_NAME"
}

# Preset troubleshooting commands
run_preset() {
    local preset="$1"
    case "$preset" in
        files)
            echo "=== PSU Repository Files ==="
            kudu_exec "ls -la /home/Repository/.universal/ 2>/dev/null || echo 'No .universal directory'"
            ;;
        apps)
            echo "=== PSU Apps Configuration ==="
            kudu_exec "cat /home/Repository/.universal/apps.ps1 2>/dev/null || echo 'No apps.ps1 found'"
            ;;
        modules)
            echo "=== Installed Modules in /home/Repository/Modules ==="
            kudu_exec "ls -la /home/Repository/Modules/ 2>/dev/null || echo 'No modules directory'"
            ;;
        logs)
            echo "=== Recent Log Files ==="
            kudu_exec "ls -la /home/LogFiles/ 2>/dev/null && echo '---' && tail -50 /home/LogFiles/*.log 2>/dev/null | head -100"
            ;;
        disk)
            echo "=== Disk Usage (Kudu container) ==="
            kudu_exec "df -h"
            ;;
        env)
            echo "=== Environment Variables (Kudu container) ==="
            kudu_exec "env | sort"
            ;;
        health)
            echo "=== PSU Health Check ==="
            curl -s -o /dev/null -w "HTTP Status: %{http_code}\nResponse Time: %{time_total}s\n" "${PSU_URL}/api/v1/alive" || echo "Health check failed"
            ;;
        version)
            echo "=== PSU Version (via API) ==="
            curl -s "${PSU_URL}/api/v1/version" 2>/dev/null | jq . || echo "Could not get version (may require auth)"
            ;;
        container-ip)
            echo "=== Container Network Info ==="
            kudu_exec "cat /appsvctmp/ipaddr_* 2>/dev/null || echo 'No ipaddr file'"
            ;;
        *)
            echo "Unknown preset: $preset"
            echo ""
            echo "Available presets:"
            echo "  files        List PSU configuration files in .universal/"
            echo "  apps         Show apps.ps1 configuration"
            echo "  modules      List installed modules"
            echo "  logs         Show recent log files"
            echo "  disk         Show disk usage"
            echo "  env          Show environment variables"
            echo "  health       Check PSU health endpoint"
            echo "  version      Get PSU version via API"
            echo "  container-ip Show container network info"
            return 1
            ;;
    esac
}

usage() {
    cat <<EOF
Usage: $0 <command> [args]

Troubleshoot the PSU web app via Kudu API and PSU REST API.

Commands:
  run <command>       Execute a shell command (runs in Kudu container)
  api <endpoint>      Query PSU REST API (requires PSU_APP_TOKEN)
  ssh                 Open interactive SSH session (if enabled)
  preset <name>       Run a preset troubleshooting command

Presets:
  files         List PSU configuration files
  apps          Show apps.ps1 configuration
  modules       List installed PowerShell modules
  logs          Show recent log files
  disk          Show disk usage
  env           Show environment variables
  health        Check PSU health endpoint
  version       Get PSU version via API
  container-ip  Show container network info

Examples:
  $0 run "ls -la /home/Repository"
  $0 run "cat /home/Repository/.universal/apps.ps1"
  $0 preset logs
  $0 preset health
  $0 api "/api/v1/dashboard"

Environment Variables:
  PSU_APP_TOKEN    Bearer token for PSU API calls (from PSU Admin > Tokens)

Architecture Note:
  The 'run' command executes in the Kudu sidecar container, which shares
  the /home filesystem with the PSU app container. This means:

  ✓ File operations work (ls, cat, etc. on /home)
  ✓ Log file access works
  ✗ Runtime state queries don't reflect PSU app (use 'api' instead)
  ✗ PowerShell commands run in Kudu, not PSU

  For PSU-specific queries (loaded modules, running jobs, etc.), use
  the PSU REST API via the 'api' command.
EOF
}

case "${1:-}" in
    run)
        [[ -z "${2:-}" ]] && { echo "Error: command required"; usage; exit 1; }
        kudu_exec "$2"
        ;;
    api)
        [[ -z "${2:-}" ]] && { echo "Error: API endpoint required"; usage; exit 1; }
        psu_api "$2"
        ;;
    ssh)
        interactive_ssh
        ;;
    preset)
        [[ -z "${2:-}" ]] && { echo "Error: preset name required"; usage; exit 1; }
        run_preset "$2"
        ;;
    *)
        usage
        ;;
esac
