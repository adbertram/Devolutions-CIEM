#!/bin/bash
# Stop hook: Auto-publish Devolutions.CIEM to local PSU after turns that modify psu-app/ files.
# Compares current git status against the SessionStart snapshot to detect session-only changes.
# If no snapshot exists (e.g., old session), falls back to checking all uncommitted changes.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG="/tmp/claude-hook-auto-publish-psu.log"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG"; }

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || true)

cd "$PROJECT_DIR"

# Get current psu-app/ status (excluding test-only paths)
current=$(git status --porcelain psu-app/ 2>/dev/null \
    | grep -v 'psu-app/ui/e2e/' \
    | grep -v 'psu-app/.*/Tests/' \
    | grep -v 'psu-app/data/' \
    | sort \
    || true)

SNAPSHOT_FILE="/tmp/claude-psu-status-${SESSION_ID}.snapshot"

if [ -n "$SESSION_ID" ] && [ -f "$SNAPSHOT_FILE" ]; then
    # Compare against session start snapshot
    snapshot=$(cat "$SNAPSHOT_FILE")
    if [ "$current" = "$snapshot" ]; then
        log "No new psu-app/ changes since session start. Skipping publish."
        echo '{}'
        exit 0
    fi
    log "Detected psu-app/ changes since session start (snapshot diff)."
else
    # No snapshot available — check if there are any changes at all
    if [ -z "$current" ]; then
        log "No publishable psu-app/ changes detected. Skipping."
        echo '{}'
        exit 0
    fi
    log "No session snapshot found. Detected uncommitted psu-app/ changes, publishing."
fi

log "Changed files (current vs snapshot delta):"
log "$current"

# Run publish
output=$(pwsh -NoProfile -Command "Import-Module ./Devolutions.CIEM.Admin; Publish-PSUModule -ModulePath ./psu-app -LocalOnly" 2>&1) || {
    log "Publish FAILED: $output"
    echo "{\"systemMessage\": \"Auto-publish to local PSU failed. Check /tmp/claude-hook-auto-publish-psu.log\"}"
    exit 0
}

log "Publish succeeded."

# Extract version from output if present
version=$(echo "$output" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | tail -1 || true)
msg="Auto-published Devolutions.CIEM${version:+ $version} to local PSU"

echo "{\"systemMessage\": \"$msg\"}"
exit 0
