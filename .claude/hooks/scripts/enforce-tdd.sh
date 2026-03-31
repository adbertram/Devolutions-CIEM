#!/usr/bin/env bash
# enforce-tdd.sh — PreToolUse hook for Edit|Write
# Blocks source code edits until a test file has been written/edited first.
# Enforces the project's mandatory TDD workflow: tests before implementation.
#
# Source files (gated): psu-app/**/(Classes|Public|Private|Pages)/**/*.ps1
# Test files (markers):  *.Tests.ps1, *.test.js
# Excludes: **/Tests/**, **/e2e/**, **/.universal/**, **/Checks/Test-*.ps1

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only inspect Edit and Write calls with a file path
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Marker file tracks whether tests have been touched this session.
MARKER_DIR="/tmp/claude-tdd-gate-ciem"
mkdir -p "$MARKER_DIR"
# Clean up markers older than 1 hour to avoid stale state from prior sessions
find "$MARKER_DIR" -type f -mmin +60 -delete 2>/dev/null || true
MARKER_FILE="$MARKER_DIR/${CLAUDE_SESSION_ID:-shared}"

# If the target IS a test file, create the marker and allow
if echo "$FILE_PATH" | grep -qE '\.(Tests\.ps1|test\.js)$'; then
  touch "$MARKER_FILE"
  exit 0
fi

# Check if the target is PowerShell source code in gated directories
IS_SOURCE=false
if echo "$FILE_PATH" | grep -qE 'psu-app/.*(Classes|Public|Private|Pages)/.*\.ps1$'; then
  # Exclude test directories, e2e, .universal config, and Prowler check scripts
  if ! echo "$FILE_PATH" | grep -qE '(/Tests/|/e2e/|/\.universal/|/Checks/Test-)'; then
    IS_SOURCE=true
  fi
fi

# If not gated source code, allow (docs, config, hooks, rules, schema, etc.)
if [ "$IS_SOURCE" = false ]; then
  exit 0
fi

# If any marker exists, tests have been touched — allow the source edit
if ls "$MARKER_DIR"/* >/dev/null 2>&1; then
  exit 0
fi

# No test activity yet — deny the source code edit
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "TDD VIOLATION: You must write failing tests BEFORE editing source code. Load the testing-expert or pester-tests skill and write tests first. Then retry this edit."
  }
}'
exit 0
