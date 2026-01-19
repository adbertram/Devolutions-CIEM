#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose-dev.yml"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [COMMAND]

Start the Prowler development environment.
- Backend services run in Docker
- UI runs locally via pnpm for fast hot-reload

Commands:
    up          Start all services (default)
    stop        Stop all services
    restart     Restart all services
    status      Show service status
    logs        Follow backend logs

Examples:
    $(basename "$0")            # Start everything
    $(basename "$0") stop       # Stop everything
EOF
    exit 0
}

BACKEND_SERVICES="api-dev postgres valkey neo4j worker-dev worker-beat mcp-server"

start_backend() {
    log_info "Starting backend services in Docker..."
    docker compose -f "$COMPOSE_FILE" up -d $BACKEND_SERVICES
}

start_ui() {
    log_info "Starting UI locally..."
    cd "$SCRIPT_DIR/ui"

    # Kill any existing next dev process
    pkill -f "next dev" 2>/dev/null || true

    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        log_info "Installing UI dependencies..."
        pnpm install
    fi

    # Start in background
    pnpm run dev &

    cd "$SCRIPT_DIR"
}

stop_all() {
    log_info "Stopping all services..."
    pkill -f "next dev" 2>/dev/null || true
    docker compose -f "$COMPOSE_FILE" down
}

show_status() {
    echo
    log_info "Backend services (Docker):"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAMES|devolutions-ciem)" || true
    echo
    log_info "UI process:"
    pgrep -f "next dev" > /dev/null && echo "  Running (PID: $(pgrep -f 'next dev'))" || echo "  Not running"
    echo
    log_info "Endpoints:"
    echo "  - UI:         http://localhost:3000"
    echo "  - API:        http://localhost:8080/api/v1/"
    echo "  - MCP Server: http://localhost:8000"
    echo "  - Neo4j:      http://localhost:7474"
}

# Parse command
COMMAND="${1:-up}"

case "$COMMAND" in
    up)
        start_backend
        start_ui
        sleep 3
        show_status
        ;;
    stop)
        stop_all
        ;;
    restart)
        stop_all
        start_backend
        start_ui
        sleep 3
        show_status
        ;;
    status)
        show_status
        ;;
    logs)
        docker compose -f "$COMPOSE_FILE" logs -f $BACKEND_SERVICES
        ;;
    -h|--help)
        usage
        ;;
    *)
        log_warn "Unknown command: $COMMAND"
        usage
        ;;
esac
