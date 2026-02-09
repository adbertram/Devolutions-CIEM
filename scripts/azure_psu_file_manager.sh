#!/bin/bash
# Azure PSU File Manager - Query, list, and read files on Azure Web App via Kudu API
set -euo pipefail

RESOURCE_GROUP="devolutions-ciem-rg"
APP_NAME="devolutions-ciem-psu"
SCM_URL="https://${APP_NAME}.scm.azurewebsites.net"
DATA_DIR="$(cd "$(dirname "$0")/.." && pwd)/local-psu"

# Get credentials via Azure CLI
get_credentials() {
    az webapp deployment list-publishing-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$APP_NAME" \
        --query "[publishingUserName, publishingPassword]" -o tsv 2>/dev/null
}

# List files in a directory
list_files() {
    local path="${1:-}"
    if [[ "$LOCAL_MODE" == true ]]; then
        ls -la "$DATA_DIR/$path"
    else
        local creds
        creds=$(get_credentials)
        local user=$(echo "$creds" | head -1)
        local pass=$(echo "$creds" | tail -1)

        # Kudu VFS API: trailing slash = directory listing (root is /api/vfs/)
        curl -s -u "${user}:${pass}" "${SCM_URL}/api/vfs/${path}${path:+/}" | jq -r '.[] | "\(.mime) \(.name)"' 2>/dev/null || \
        curl -s -u "${user}:${pass}" "${SCM_URL}/api/vfs/${path}${path:+/}"
    fi
}

# Read a file
read_file() {
    local path="$1"
    if [[ "$LOCAL_MODE" == true ]]; then
        cat "$DATA_DIR/$path"
    else
        local creds
        creds=$(get_credentials)
        local user=$(echo "$creds" | head -1)
        local pass=$(echo "$creds" | tail -1)

        # Kudu VFS API: no trailing slash = file content
        curl -s -u "${user}:${pass}" "${SCM_URL}/api/vfs/${path}"
    fi
}

# Execute command via Kudu command API
exec_cmd() {
    local cmd="$1"
    if [[ "$LOCAL_MODE" == true ]]; then
        bash -c "$cmd"
    else
        local creds
        creds=$(get_credentials)
        local user=$(echo "$creds" | head -1)
        local pass=$(echo "$creds" | tail -1)

        curl -s -u "${user}:${pass}" \
            -H "Content-Type: application/json" \
            -d "{\"command\": \"$cmd\", \"dir\": \"/home\"}" \
            "${SCM_URL}/api/command" | jq -r '.Output // .Error // .'
    fi
}

usage() {
    cat <<EOF
Usage: $0 [--local] <command> [args]

Options:
  --local         Use local PSU filesystem (local-psu/) instead of Azure Kudu API

Commands:
  list [path]     List files in directory (default: root)
  read <path>     Read file contents
  exec <command>  Execute shell command on server

Examples:
  $0 list                    # List root directory (Azure)
  $0 list site/wwwroot       # List wwwroot (Azure)
  $0 read site/wwwroot/appsettings.json
  $0 exec "pwsh -c 'Get-Module -ListAvailable'"
  $0 exec "ls -la /home"
  $0 --local list            # List local PSU root directory
  $0 --local read Repository/.universal/apps.ps1
EOF
}

LOCAL_MODE=false
if [[ "${1:-}" == "--local" ]]; then
    LOCAL_MODE=true
    shift
fi

case "${1:-}" in
    list)  list_files "${2:-}" ;;
    read)  read_file "$2" ;;
    exec)  exec_cmd "$2" ;;
    *)     usage ;;
esac
