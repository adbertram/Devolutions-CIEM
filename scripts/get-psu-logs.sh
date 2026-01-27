#!/bin/bash
# Get PSU logs via REST API
# Usage: ./get-psu-logs.sh [lines]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

PSU_URL="${PSU_URL:-https://devolutions-ciem-psu.azurewebsites.net}"
LINES=${1:-50}

if [ -z "$PSU_TOKEN" ]; then
  echo "Error: PSU_TOKEN not set"
  echo "Add to .env: PSU_TOKEN=your-app-token"
  exit 1
fi

# Download logs (returns ZIP), extract, and show last N lines
TEMP_ZIP=$(mktemp).zip
TEMP_DIR=$(mktemp -d)

curl -s -H "Authorization: Bearer $PSU_TOKEN" "$PSU_URL/api/v1/log" -o "$TEMP_ZIP"
unzip -q "$TEMP_ZIP" -d "$TEMP_DIR" 2>/dev/null

# Find and display log files
for log in "$TEMP_DIR"/*.txt; do
  if [ -f "$log" ]; then
    tail -n "$LINES" "$log"
  fi
done

# Cleanup
rm -f "$TEMP_ZIP"
rm -rf "$TEMP_DIR"
