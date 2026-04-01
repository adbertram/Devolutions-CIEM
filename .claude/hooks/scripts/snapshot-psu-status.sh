#!/bin/bash
# SessionStart hook: Snapshot psu-app/ git status so the Stop hook can detect session-only changes.
# Reads session_id from stdin JSON, saves snapshot keyed by session.

set -euo pipefail

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || true)

if [ -z "$SESSION_ID" ]; then
    echo '{}'
    exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SNAPSHOT_FILE="/tmp/claude-psu-status-${SESSION_ID}.snapshot"

cd "$PROJECT_DIR"

# Snapshot current psu-app/ status (same filter as the publish hook)
git status --porcelain psu-app/ 2>/dev/null \
    | grep -v 'psu-app/ui/e2e/' \
    | grep -v 'psu-app/.*/Tests/' \
    | grep -v 'psu-app/data/' \
    | sort \
    > "$SNAPSHOT_FILE" 2>/dev/null || true

echo '{}'
exit 0
