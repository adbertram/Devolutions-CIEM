#!/bin/bash
# Invoke commands for PSU web app troubleshooting via Kudu API or local PSU instance
#
# IMPORTANT: Commands run in the Kudu sidecar container, NOT the PSU app container.
# The Kudu container shares /home filesystem with the app, so file operations work.
# For commands that need to run IN the PSU container (like querying loaded modules),
# use the PSU REST API or interactive SSH (if enabled in the container image).
#
# Use --local flag to target a local PSU Docker container instead of Azure.
#
# For more info on Azure App Service container architecture:
# https://learn.microsoft.com/en-us/azure/app-service/configure-linux-open-ssh-session
set -euo pipefail

# Parse --local flag before command parsing
LOCAL_MODE=false
if [[ "${1:-}" == "--local" ]]; then
    LOCAL_MODE=true
    shift
fi

# Local mode constants
# Load publish point config from .env
_env_file="$(cd "$(dirname "$0")/.." && pwd)/.env"
PUBLISH_POINT_SSH=""
PUBLISH_POINT_PSU_PATH=""
LOCAL_PSU_URL=""
if [ -f "$_env_file" ]; then
    while IFS='=' read -r key value; do
        case "$key" in
            \#*|'') continue ;;
            PUBLISH_POINT_SSH) PUBLISH_POINT_SSH="$value" ;;
            PUBLISH_POINT_PSU_PATH) PUBLISH_POINT_PSU_PATH="$value" ;;
            LOCAL_PSU_URL) LOCAL_PSU_URL="$value" ;;
        esac
    done < "$_env_file"
fi

# Azure mode constants
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

# Execute command in Kudu container via API (or locally against $DATA_DIR)
kudu_exec() {
    local cmd="$1"

    if [[ "$LOCAL_MODE" == true ]]; then
        # Local mode: execute on publish point via SSH
        if [[ -z "$PUBLISH_POINT_SSH" ]]; then
            echo "Error: PUBLISH_POINT_SSH not set in .env" >&2
            return 1
        fi
        ssh "$PUBLISH_POINT_SSH" "cd $PUBLISH_POINT_PSU_PATH && $cmd"
        return $?
    fi

    # Azure mode: execute via Kudu API
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

# Query PSU REST API (runs against actual PSU app or local instance)
psu_api() {
    local endpoint="$1"

    if [[ "$LOCAL_MODE" == true ]]; then
        # Local mode: no auth needed for local dev instance
        curl -s "${LOCAL_PSU_URL}${endpoint}"
        return $?
    fi

    # Azure mode: requires auth token
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
    if [[ "$LOCAL_MODE" == true ]]; then
        echo "Opening shell in local container $LOCAL_CONTAINER..."
        docker exec -it "$LOCAL_CONTAINER" bash 2>/dev/null || {
            echo "Error: Could not connect to container $LOCAL_CONTAINER" >&2
            echo "Is the container running? Check with: docker ps" >&2
            return 1
        }
        return $?
    fi

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
    # Resolve the target PSU URL based on mode
    local target_url="$PSU_URL"
    if [[ "$LOCAL_MODE" == true ]]; then
        target_url="$LOCAL_PSU_URL"
    fi

    case "$preset" in
        files)
            echo "=== PSU Repository Files ==="
            if [[ "$LOCAL_MODE" == true ]]; then
                kudu_exec "ls -la Repository/.universal/ 2>/dev/null || echo 'No .universal directory'"
            else
                kudu_exec "ls -la /home/Repository/.universal/ 2>/dev/null || echo 'No .universal directory'"
            fi
            ;;
        apps)
            echo "=== PSU Apps Configuration ==="
            if [[ "$LOCAL_MODE" == true ]]; then
                kudu_exec "cat Repository/.universal/apps.ps1 2>/dev/null || echo 'No apps.ps1 found'"
            else
                kudu_exec "cat /home/Repository/.universal/apps.ps1 2>/dev/null || echo 'No apps.ps1 found'"
            fi
            ;;
        modules)
            if [[ "$LOCAL_MODE" == true ]]; then
                echo "=== Installed Modules in $DATA_DIR/Repository/Modules ==="
                kudu_exec "ls -la Repository/Modules/ 2>/dev/null || echo 'No modules directory'"
            else
                echo "=== Installed Modules in /home/Repository/Modules ==="
                kudu_exec "ls -la /home/Repository/Modules/ 2>/dev/null || echo 'No modules directory'"
            fi
            ;;
        logs)
            echo "=== Recent Log Files ==="
            if [[ "$LOCAL_MODE" == true ]]; then
                kudu_exec "ls -la LogFiles/ 2>/dev/null && echo '---' && tail -50 LogFiles/*.log 2>/dev/null | head -100"
            else
                kudu_exec "ls -la /home/LogFiles/ 2>/dev/null && echo '---' && tail -50 /home/LogFiles/*.log 2>/dev/null | head -100"
            fi
            ;;
        disk)
            echo "=== Disk Usage ==="
            kudu_exec "df -h"
            ;;
        env)
            echo "=== Environment Variables ==="
            if [[ "$LOCAL_MODE" == true ]]; then
                docker exec "$LOCAL_CONTAINER" env | sort 2>/dev/null || echo "Container $LOCAL_CONTAINER not running"
            else
                kudu_exec "env | sort"
            fi
            ;;
        health)
            echo "=== PSU Health Check ==="
            curl -s -o /dev/null -w "HTTP Status: %{http_code}\nResponse Time: %{time_total}s\n" "${target_url}/api/v1/alive" || echo "Health check failed"
            ;;
        version)
            echo "=== PSU Version (via API) ==="
            curl -s "${target_url}/api/v1/version" 2>/dev/null | jq . || echo "Could not get version (may require auth)"
            ;;
        container-ip)
            echo "=== Container Network Info ==="
            if [[ "$LOCAL_MODE" == true ]]; then
                docker inspect "$LOCAL_CONTAINER" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo "Container $LOCAL_CONTAINER not running"
            else
                kudu_exec "cat /appsvctmp/ipaddr_* 2>/dev/null || echo 'No ipaddr file'"
            fi
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
Usage: $0 [--local] <command> [args]

Troubleshoot the PSU web app via Kudu API and PSU REST API.

Options:
  --local             Target the local PSU instance instead of Azure.
                      Commands run against $DATA_DIR instead of Kudu.
                      API calls target $LOCAL_PSU_URL instead of Azure.

Commands:
  run <command>       Execute a shell command (Kudu container or local)
  api <endpoint>      Query PSU REST API (requires PSU_APP_TOKEN for Azure)
  ssh                 Open interactive SSH session (Azure only)
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

Examples (Azure):
  $0 run "ls -la /home/Repository"
  $0 run "cat /home/Repository/.universal/apps.ps1"
  $0 preset logs
  $0 preset health
  $0 api "/api/v1/dashboard"

Examples (Local):
  $0 --local run "ls -la Repository"
  $0 --local preset health
  $0 --local preset modules
  $0 --local api "/api/v1/alive"

Environment Variables:
  PSU_APP_TOKEN    Bearer token for PSU API calls (Azure mode only)

Architecture Note:
  Azure mode: The 'run' command executes in the Kudu sidecar container,
  which shares the /home filesystem with the PSU app container.

  Local mode: The 'run' command executes on the publish point (adam-server)
  via SSH. API calls go to the local PSU instance at $LOCAL_PSU_URL.
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
