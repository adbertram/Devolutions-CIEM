#!/usr/bin/env bash
# block-test-pipe.sh — PreToolUse hook for Bash tool
# Blocks test commands that pipe output through filters.
# Enforces: "CRITICAL: Never truncate test output"

set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only inspect commands that look like test runs
if ! echo "$COMMAND" | grep -qE '(Invoke-Pester|npx playwright test)'; then
  exit 0
fi

# Block if the command pipes through output-truncating filters
if echo "$COMMAND" | grep -qE '\|\s*(tail|head|grep|sed|awk|cut|wc|tee)\b'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Test commands must not pipe through filters (tail, head, grep, tee, etc.). Show complete test output. This is a mandatory project rule."
    }
  }'
  exit 0
fi

exit 0
