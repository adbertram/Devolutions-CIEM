#!/bin/bash
# Query CIEM application log from the publish point (adam-server) via SSH.
# Falls back to local psu-app/data/ciem.log for dev use.
#
# Usage:
#   ./scripts/ciem-log.sh                  # last 30 lines
#   ./scripts/ciem-log.sh -f               # follow (tail -f)
#   ./scripts/ciem-log.sh -n 100           # last 100 lines
#   ./scripts/ciem-log.sh -g "ERROR"       # grep for pattern
#   ./scripts/ciem-log.sh -g "EnvironmentPage" -n 50   # grep + limit
#   ./scripts/ciem-log.sh --path           # just print the log path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

load_env() {
    local env_file
    env_file="$(cd "$(dirname "$0")/.." && pwd)/.env"
    if [ -f "$env_file" ]; then
        while IFS='=' read -r key value; do
            case "$key" in
                \#*|'') continue ;;
                PUBLISH_POINT_SSH) PUBLISH_POINT_SSH="$value" ;;
                PUBLISH_POINT_PSU_PATH) PUBLISH_POINT_PSU_PATH="$value" ;;
                LOCAL_PSU_URL) LOCAL_PSU_URL="$value" ;;
            esac
        done < "$env_file"
    fi
}

load_env

REMOTE_LOG="${PUBLISH_POINT_PSU_PATH}/data/ciem.log"

# Check if remote log is accessible via SSH
check_remote() {
    if [[ -n "${PUBLISH_POINT_SSH:-}" ]] && [[ -n "${PUBLISH_POINT_PSU_PATH:-}" ]]; then
        ssh "$PUBLISH_POINT_SSH" "test -f '$REMOTE_LOG'" 2>/dev/null
        return $?
    fi
    return 1
}

# Find the log source — prefer remote, fall back to local dev copy
find_log() {
    if check_remote; then
        echo "remote"
        return
    fi

    local working_copy="$PROJECT_ROOT/psu-app/data/ciem.log"
    if [[ -f "$working_copy" ]]; then
        echo "$working_copy"
        return
    fi

    echo "ERROR: No ciem.log found (remote SSH failed and no local psu-app/data/ciem.log)" >&2
    exit 1
}

LOG_SOURCE=$(find_log)

# Parse arguments
LINES=30
FOLLOW=false
GREP_PATTERN=""
PATH_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--follow)    FOLLOW=true; shift ;;
        -n|--lines)     LINES="$2"; shift 2 ;;
        -g|--grep)      GREP_PATTERN="$2"; shift 2 ;;
        --path)         PATH_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: ciem-log.sh [-f] [-n LINES] [-g PATTERN] [--path]"
            echo ""
            echo "Options:"
            echo "  -f, --follow     Follow log output (tail -f)"
            echo "  -n, --lines N    Show last N lines (default: 30)"
            echo "  -g, --grep PAT   Filter lines matching pattern"
            echo "  --path           Print log file path and exit"
            echo "  -h, --help       Show this help"
            exit 0
            ;;
        *)  echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ "$LOG_SOURCE" == "remote" ]]; then
    LOG_DISPLAY="${PUBLISH_POINT_SSH}:${REMOTE_LOG}"

    if $PATH_ONLY; then
        echo "$LOG_DISPLAY"
        exit 0
    fi

    echo "# Log: $LOG_DISPLAY" >&2

    if $FOLLOW; then
        if [[ -n "$GREP_PATTERN" ]]; then
            ssh "$PUBLISH_POINT_SSH" "tail -f '$REMOTE_LOG'" | grep --line-buffered -i "$GREP_PATTERN"
        else
            ssh "$PUBLISH_POINT_SSH" "tail -f '$REMOTE_LOG'"
        fi
    elif [[ -n "$GREP_PATTERN" ]]; then
        ssh "$PUBLISH_POINT_SSH" "grep -i '$GREP_PATTERN' '$REMOTE_LOG' | tail -n $LINES"
    else
        ssh "$PUBLISH_POINT_SSH" "tail -n $LINES '$REMOTE_LOG'"
    fi
else
    # Local file path
    if $PATH_ONLY; then
        echo "$LOG_SOURCE"
        exit 0
    fi

    echo "# Log: $LOG_SOURCE" >&2

    if $FOLLOW; then
        if [[ -n "$GREP_PATTERN" ]]; then
            tail -f "$LOG_SOURCE" | grep --line-buffered -i "$GREP_PATTERN"
        else
            tail -f "$LOG_SOURCE"
        fi
    elif [[ -n "$GREP_PATTERN" ]]; then
        grep -i "$GREP_PATTERN" "$LOG_SOURCE" | tail -n "$LINES"
    else
        tail -n "$LINES" "$LOG_SOURCE"
    fi
fi
