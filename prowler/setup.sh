#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Set up the Prowler development environment.

This script:
1. Checks prerequisites (Docker, pnpm, poetry)
2. Creates .env file if missing
3. Starts backend services in Docker
4. Installs UI dependencies locally
5. Starts the UI dev server

Options:
    --skip-ui       Only set up backend (skip UI)
    --reset         Stop everything and start fresh
    -h, --help      Show this help message

After setup, use ./start.sh to manage services.
EOF
    exit 0
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    local missing=0

    # Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        missing=1
    else
        echo "  ✓ Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
    fi

    # pnpm
    if ! command -v pnpm &> /dev/null; then
        log_error "pnpm is not installed"
        echo "    Install: npm install -g pnpm"
        missing=1
    else
        echo "  ✓ pnpm $(pnpm --version)"
    fi

    # poetry (optional, for git hooks)
    if command -v poetry &> /dev/null; then
        echo "  ✓ poetry $(poetry --version | cut -d' ' -f3)"
    elif [ -f "$HOME/.local/bin/poetry" ]; then
        echo "  ✓ poetry (in ~/.local/bin)"
        export PATH="$HOME/.local/bin:$PATH"
    else
        log_warn "poetry not found (optional, needed for git hooks)"
        echo "    Install: curl -sSL https://install.python-poetry.org | python3 -"
    fi

    if [ $missing -eq 1 ]; then
        log_error "Missing prerequisites. Please install them and try again."
        exit 1
    fi
}

setup_env() {
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        log_warn ".env file not found"
        if [ -f "$SCRIPT_DIR/.env.example" ]; then
            log_info "Copying .env.example to .env"
            cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        else
            log_error "No .env.example found. Please create .env manually."
            exit 1
        fi
    else
        echo "  ✓ .env exists"
    fi

    # Create UI .env.local for local development
    if [ ! -f "$SCRIPT_DIR/ui/.env.local" ]; then
        log_info "Creating ui/.env.local for local development..."
        cat > "$SCRIPT_DIR/ui/.env.local" << 'EOF'
# Local development - API runs on localhost
NEXT_PUBLIC_API_BASE_URL=http://localhost:8080/api/v1
NEXT_PUBLIC_API_DOCS_URL=http://localhost:8080/api/v1/docs
AUTH_URL=http://localhost:3000
AUTH_TRUST_HOST=true
AUTH_SECRET="N/c6mnaS5+SWq81+819OrzQZlmx1Vxtp/orjttJSmw8="
EOF
    else
        echo "  ✓ ui/.env.local exists"
    fi
}

start_backend() {
    log_info "Starting backend services..."
    docker compose -f "$SCRIPT_DIR/docker-compose-dev.yml" up -d \
        api-dev postgres valkey neo4j worker-dev worker-beat mcp-server

    log_info "Waiting for services to be healthy..."
    sleep 10
}

setup_ui() {
    log_info "Setting up UI..."
    cd "$SCRIPT_DIR/ui"

    if [ ! -d "node_modules" ] || [ "$RESET" = true ]; then
        log_info "Installing UI dependencies..."
        pnpm install || log_warn "pnpm install had warnings (likely git hooks)"
    else
        echo "  ✓ node_modules exists"
    fi

    cd "$SCRIPT_DIR"
}

start_ui() {
    log_info "Starting UI dev server..."
    cd "$SCRIPT_DIR/ui"
    pkill -f "next dev" 2>/dev/null || true
    pnpm run dev &
    cd "$SCRIPT_DIR"
}

show_status() {
    echo
    log_info "Setup complete!"
    echo
    echo "Backend services (Docker):"
    docker ps --format "  {{.Names}}: {{.Status}}" | grep devolutions-ciem || true
    echo
    echo "Endpoints:"
    echo "  - UI:         http://localhost:3000"
    echo "  - API:        http://localhost:8080/api/v1/"
    echo "  - MCP Server: http://localhost:8000"
    echo "  - Neo4j:      http://localhost:7474"
    echo
    echo "Default dev credentials: dev@prowler.com / Thisisapassword123@"
    echo
    echo "Use ./start.sh to manage services after initial setup."
}

# Parse arguments
SKIP_UI=false
RESET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-ui)
            SKIP_UI=true
            shift
            ;;
        --reset)
            RESET=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Main
echo "🚀 Prowler Development Setup"
echo "============================"
echo

if [ "$RESET" = true ]; then
    log_warn "Resetting environment..."
    pkill -f "next dev" 2>/dev/null || true
    docker compose -f "$SCRIPT_DIR/docker-compose-dev.yml" down -v 2>/dev/null || true
    rm -rf "$SCRIPT_DIR/ui/node_modules" 2>/dev/null || true
    rm -rf "$SCRIPT_DIR/ui/.next" 2>/dev/null || true
fi

check_prerequisites
setup_env
start_backend

if [ "$SKIP_UI" = false ]; then
    setup_ui
    start_ui
    sleep 5
fi

show_status
