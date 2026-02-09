#!/bin/bash
# setup-local-psu.sh
# Manage local PowerShell Universal instance for development (native macOS ARM64)

set -euo pipefail

PSU_VERSION="2026.1.0"
PORT=5001
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PSU_DIR="$HOME/.local/share/powershell-universal"
PSU_BIN="$PSU_DIR/Universal.Server"
DATA_DIR="$PROJECT_DIR/local-psu"
PID_FILE="$DATA_DIR/.psu.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

ensure_installed() {
    if [[ -x "$PSU_BIN" ]]; then
        return 0
    fi

    log_info "PSU binary not found. Installing v${PSU_VERSION} (osx-arm64)..."
    mkdir -p "$PSU_DIR"

    local zip_file="/tmp/psu-osx-arm64.zip"
    local url="https://imsreleases.blob.core.windows.net/universal/production/${PSU_VERSION}/Universal.osx-arm64.${PSU_VERSION}.zip"

    curl -L -o "$zip_file" "$url" --progress-bar
    unzip -qo "$zip_file" -d "$PSU_DIR"
    chmod +x "$PSU_BIN"
    # Also make PowerShell host binaries executable (needed for module discovery)
    find "$PSU_DIR/Hosts" -name "PowerShellUniversal.Host" -exec chmod +x {} \; 2>/dev/null || true
    xattr -r -d com.apple.quarantine "$PSU_DIR/" 2>/dev/null || true
    rm -f "$zip_file"

    log_info "PSU v${PSU_VERSION} installed to $PSU_DIR"
}

ensure_data_dirs() {
    if [[ ! -d "$DATA_DIR/Repository" ]]; then
        log_info "Creating data directories at $DATA_DIR"
        mkdir -p "$DATA_DIR/Repository/.universal"
        mkdir -p "$DATA_DIR/Repository/Modules"
        mkdir -p "$DATA_DIR/Repository/dashboards"
        mkdir -p "$DATA_DIR/LogFiles"
    fi
}

get_pid() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
        # Stale PID file
        rm -f "$PID_FILE"
    fi
    return 1
}

start() {
    local pid
    if pid=$(get_pid); then
        log_warn "PSU is already running (PID: $pid)"
        status
        return 0
    fi

    ensure_installed
    ensure_data_dirs

    log_info "Starting PSU on port $PORT..."

    # Set environment for PSU
    # Note: Kestrel key must match case from appsettings.json (HTTP not Http)
    export Kestrel__Endpoints__HTTP__Url="http://localhost:$PORT"
    export Data__RepositoryPath="$DATA_DIR/Repository"
    export Data__ConnectionString="Data Source=$DATA_DIR/database.db"
    export Logging__Path="$DATA_DIR/LogFiles"

    # Start PSU in background
    nohup "$PSU_BIN" > "$DATA_DIR/LogFiles/psu-stdout.log" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    log_info "PSU started (PID: $new_pid)"
    log_info "Web UI: http://localhost:$PORT"

    if [[ "$NO_WAIT" == "true" ]]; then
        log_info "Skipping wait (--no-wait). PSU may take 15-30 seconds to fully initialize."
        return 0
    fi

    # Wait for PSU to be ready
    wait_ready 60
    status
}

stop() {
    local pid
    if pid=$(get_pid); then
        log_info "Stopping PSU (PID: $pid)..."
        kill "$pid" 2>/dev/null || true

        # Wait for graceful shutdown
        local tries=0
        while kill -0 "$pid" 2>/dev/null && [[ $tries -lt 10 ]]; do
            sleep 1
            tries=$((tries + 1))
        done

        if kill -0 "$pid" 2>/dev/null; then
            log_warn "PSU didn't stop gracefully, sending SIGKILL"
            kill -9 "$pid" 2>/dev/null || true
        fi

        rm -f "$PID_FILE"
        log_info "PSU stopped"
    else
        log_warn "PSU is not running"
    fi
}

restart() {
    stop
    sleep 1
    start
}

reset() {
    log_warn "This will stop PSU AND wipe all local PSU data"
    read -p "Are you sure? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stop 2>/dev/null || true
        if [[ -d "$DATA_DIR" ]]; then
            log_info "Removing data directory: $DATA_DIR"
            rm -rf "$DATA_DIR"
        fi
        log_info "Reset complete. Run 'start' to create a fresh instance"
    else
        log_info "Reset cancelled"
    fi
}

logs() {
    local log_file="$DATA_DIR/LogFiles/psu-stdout.log"
    if [[ -f "$log_file" ]]; then
        if [[ "${1:-}" == "-f" ]]; then
            tail -f "$log_file"
        else
            tail -100 "$log_file"
        fi
    else
        log_error "No log file found at $log_file"
        return 1
    fi
}

status() {
    echo "=== PSU Status ==="

    # Check binary
    if [[ -x "$PSU_BIN" ]]; then
        echo -e "Binary: ${GREEN}Installed${NC} ($PSU_DIR)"
        echo "  Version: $PSU_VERSION"
    else
        echo -e "Binary: ${RED}Not installed${NC}"
        echo "  Run '$0 start' to install and start"
        return
    fi

    # Check if running
    local pid
    if pid=$(get_pid); then
        echo -e "Process: ${GREEN}Running${NC} (PID: $pid)"

        echo ""
        echo "=== PSU Health ==="

        # Check health endpoint
        # Note: PSU 2026.1.0 /api/v1/alive returns: loading, hasError, loadingInfo, mode
        # (no 'alive' field). Use 'loading == false' as the ready indicator.
        local health
        if health=$(curl -s --connect-timeout 5 "http://localhost:${PORT}/api/v1/alive" 2>/dev/null); then
            local loading hasError loadingInfo
            loading=$(echo "$health" | jq -r 'if .loading == false then "false" else "true" end')
            hasError=$(echo "$health" | jq -r 'if .hasError == true then "true" else "false" end')
            loadingInfo=$(echo "$health" | jq -r '.loadingInfo // ""')

            if [[ "$loading" == "false" && "$hasError" == "false" ]]; then
                echo -e "  Status: ${GREEN}Ready${NC}"
            elif [[ "$hasError" == "true" ]]; then
                echo -e "  Status: ${RED}Error${NC}"
            else
                echo -e "  Status: ${YELLOW}Starting${NC}"
            fi

            if [[ "$loading" == "true" ]]; then
                echo -e "  Loading: ${YELLOW}Yes${NC} - $loadingInfo"
            else
                echo -e "  Loading: ${GREEN}Complete${NC}"
            fi
        else
            echo -e "  Status: ${YELLOW}Not responding (may still be starting)${NC}"
        fi

        echo ""
        echo "=== Access ==="
        echo "  Web UI: http://localhost:${PORT}"
        echo "  API:    http://localhost:${PORT}/api/v1"
    else
        echo -e "Process: ${YELLOW}Stopped${NC}"
        echo "  Run '$0 start' to start"
    fi
}

wait_ready() {
    local timeout="${1:-60}"
    local interval=2
    local elapsed=0

    log_info "Waiting for PSU to be ready (timeout: ${timeout}s)..."

    while [[ $elapsed -lt $timeout ]]; do
        local health
        if health=$(curl -s --connect-timeout 3 "http://localhost:${PORT}/api/v1/alive" 2>/dev/null); then
            # Note: jq's // operator treats false as falsy, so we must use
            # 'if .loading == false' instead of '.loading // true'
            local loading
            loading=$(echo "$health" | jq -r 'if .loading == false then "false" else "true" end')

            if [[ "$loading" == "false" ]]; then
                log_info "PSU is ready! (${elapsed}s)"
                return 0
            fi

            local loadingInfo
            loadingInfo=$(echo "$health" | jq -r '.loadingInfo // "Starting..."')
            echo "  Loading: $loadingInfo (${elapsed}s)"
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    log_error "Timeout waiting for PSU to be ready"
    return 1
}

usage() {
    echo "Usage: $0 [--no-wait] {start|stop|restart|reset|logs|status|wait}"
    echo ""
    echo "Commands:"
    echo "  start     Start the local PSU server (waits for ready by default)"
    echo "  stop      Stop the server (keeps data)"
    echo "  restart   Stop and start the server"
    echo "  reset     Stop and wipe all data"
    echo "  logs      Show recent logs (use -f to follow)"
    echo "  status    Show server and health status"
    echo "  wait      Wait for PSU to finish loading (optional timeout in seconds)"
    echo ""
    echo "Flags:"
    echo "  --no-wait  Don't wait for PSU to be ready after start/restart"
    echo ""
    echo "Paths:"
    echo "  Binary:   $PSU_DIR"
    echo "  Data:     $DATA_DIR"
    echo "  Port:     $PORT"
}

# Parse global flags
NO_WAIT=false
args=()
for arg in "$@"; do
    case "$arg" in
        --no-wait) NO_WAIT=true ;;
        *) args+=("$arg") ;;
    esac
done
set -- "${args[@]+"${args[@]}"}"

case "${1:-}" in
    start)   start ;;
    stop)    stop ;;
    restart) restart ;;
    reset)   reset ;;
    logs)    shift; logs "${1:-}" ;;
    status)  status ;;
    wait)    shift; wait_ready "${1:-60}" ;;
    -h|--help) usage ;;
    *)
        usage
        exit 1
        ;;
esac
