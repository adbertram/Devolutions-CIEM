#!/bin/bash
# Query CIEM application log from the active local PSU module installation.
# The log location depends on which module version PSU loaded — this script
# finds it automatically.
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

# Find the most recently modified ciem.log across all possible locations
find_log() {
    local candidates=()

    # PSU data root (where DataRoot resolves in PSU context)
    local psu_data_root="$PROJECT_ROOT/local-psu/data/ciem.log"
    if [[ -f "$psu_data_root" ]]; then
        candidates+=("$psu_data_root")
    fi

    # Published module location (legacy — before DataRoot migration)
    local local_psu_modules="$PROJECT_ROOT/local-psu/Repository/Modules/Devolutions.CIEM"
    if [[ -d "$local_psu_modules" ]]; then
        while IFS= read -r f; do
            candidates+=("$f")
        done < <(find "$local_psu_modules" -name "ciem.log" 2>/dev/null)
    fi

    # Working copy location (dev / direct import)
    local working_copy="$PROJECT_ROOT/psu-app/data/ciem.log"
    if [[ -f "$working_copy" ]]; then
        candidates+=("$working_copy")
    fi

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "ERROR: No ciem.log found" >&2
        exit 1
    fi

    # Return the most recently modified
    local newest=""
    local newest_time=0
    for f in "${candidates[@]}"; do
        local mtime
        mtime=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
        if [[ "$mtime" -gt "$newest_time" ]]; then
            newest_time="$mtime"
            newest="$f"
        fi
    done
    echo "$newest"
}

LOG_FILE=$(find_log)

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

if $PATH_ONLY; then
    echo "$LOG_FILE"
    exit 0
fi

# Show which file we're reading
echo "# Log: $LOG_FILE" >&2

if $FOLLOW; then
    if [[ -n "$GREP_PATTERN" ]]; then
        tail -f "$LOG_FILE" | grep --line-buffered -i "$GREP_PATTERN"
    else
        tail -f "$LOG_FILE"
    fi
elif [[ -n "$GREP_PATTERN" ]]; then
    grep -i "$GREP_PATTERN" "$LOG_FILE" | tail -n "$LINES"
else
    tail -n "$LINES" "$LOG_FILE"
fi
