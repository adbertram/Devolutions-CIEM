#!/bin/bash
# Download PSU logs and diagnostics from all sources to a local file
# Usage: ./download-psu-logs.sh [--local] [output_file]
#
# Downloads from:
#   - PSU database (LogEntry table) - App-level logs like [App-Devolutions CIEM]
#   - Azure Docker logs - Container stdout
#   - PSU REST API logs - Infrastructure logs
#   - Azure Instance Status - Container health, VNETFailure, etc.
#   - Azure Resource Health - Availability status
#   - App configuration - Settings and container config
#
# After downloading, search the file locally with grep:
#   grep -i "CIEM" _temp/psu-logs.log
#   grep -i "error" _temp/psu-logs.log
#   grep -i "VNETFailure" _temp/psu-logs.log

set -euo pipefail

LOCAL_MODE=false
if [[ "${1:-}" == "--local" ]]; then
    LOCAL_MODE=true
    shift
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$(cd "$(dirname "$0")/.." && pwd)/local-psu"
LOCAL_PSU_URL="http://localhost:5001"
ENV_FILE="$SCRIPT_DIR/../.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

# Azure resource configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-devolutions-ciem-rg}"
SITE_NAME="${SITE_NAME:-devolutions-ciem-psu}"
PSU_URL="${PSU_URL:-https://${SITE_NAME}.azurewebsites.net}"

# Output file (default: _temp/ with timestamped filename)
PROJECT_ROOT="$SCRIPT_DIR/.."
TEMP_DIR="$PROJECT_ROOT/_temp"
mkdir -p "$TEMP_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_FILE="${1:-${TEMP_DIR}/psu-logs-${TIMESTAMP}.log}"

echo "Downloading PSU logs to: $OUTPUT_FILE" >&2

if [ "$LOCAL_MODE" = true ]; then
  # ============================================
  # LOCAL MODE: Collect logs from local PSU instance
  # ============================================
  {
    echo "=============================================="
    echo "PSU Diagnostics Report (Local)"
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Source: $DATA_DIR"
    echo "=============================================="
    echo ""

    # ============================================
    # SECTION 1: PSU Database Logs (most useful for app debugging)
    # ============================================
    echo "=== PSU Database Logs (LogEntry table) ==="
    echo ""
    LOCAL_DB="$DATA_DIR/database.db"
    if [ -f "$LOCAL_DB" ]; then
      sqlite3 "$LOCAL_DB" "SELECT printf('[%s] [%s] [%s-%s] %s', TimeStamp, Level, Feature, Resource, Message) FROM LogEntry ORDER BY LogId DESC LIMIT 1000;" 2>/dev/null || echo "(database query failed)"
    else
      echo "(database not found: $LOCAL_DB)"
    fi
    echo ""

    # ============================================
    # SECTION 2: PSU REST API Logs
    # ============================================
    echo "=== PSU REST API Logs ==="
    echo ""
    API_TEMP_ZIP=$(mktemp).zip
    API_TEMP_DIR=$(mktemp -d)

    HTTP_CODE=$(curl -s -w "%{http_code}" "$LOCAL_PSU_URL/api/v1/log" -o "$API_TEMP_ZIP" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
      unzip -q "$API_TEMP_ZIP" -d "$API_TEMP_DIR" 2>/dev/null || true
      for log in "$API_TEMP_DIR"/*.txt; do
        if [ -f "$log" ]; then
          echo "--- $(basename "$log") ---"
          cat "$log"
          echo ""
        fi
      done
    else
      echo "(failed to fetch API logs from $LOCAL_PSU_URL - HTTP $HTTP_CODE)"
    fi
    rm -f "$API_TEMP_ZIP"
    rm -rf "$API_TEMP_DIR"
    echo ""

    # ============================================
    # SECTION 3: PSU Stdout Log
    # ============================================
    echo "=== PSU Stdout Log ==="
    echo ""
    STDOUT_LOG="$DATA_DIR/LogFiles/psu-stdout.log"
    if [ -f "$STDOUT_LOG" ]; then
      cat "$STDOUT_LOG"
    else
      echo "(not found: $STDOUT_LOG)"
    fi
    echo ""

    # ============================================
    # SECTION 4: Additional Log Files
    # ============================================
    echo "=== Additional Log Files ==="
    echo ""
    if [ -d "$DATA_DIR/LogFiles" ]; then
      for logfile in "$DATA_DIR/LogFiles/"*; do
        if [ -f "$logfile" ] && [ "$logfile" != "$STDOUT_LOG" ]; then
          echo "--- $(basename "$logfile") ---"
          cat "$logfile"
          echo ""
        fi
      done
    else
      echo "(LogFiles directory not found: $DATA_DIR/LogFiles)"
    fi

    echo "=============================================="
    echo "End of Diagnostics Report (Local)"
    echo "=============================================="
  } > "$OUTPUT_FILE"

else
  # ============================================
  # AZURE MODE: Collect logs from Azure PSU instance
  # ============================================

# Check Azure CLI login
if ! az account show &>/dev/null; then
  echo "WARNING: Not logged in to Azure CLI. Some diagnostics will be skipped." >&2
  AZURE_LOGGED_IN=false
else
  AZURE_LOGGED_IN=true
  SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

# Get Kudu credentials
get_kudu_credentials() {
  if [ "$AZURE_LOGGED_IN" = true ]; then
    KUDU_CREDS=$(az webapp deployment list-publishing-credentials \
      --resource-group "$RESOURCE_GROUP" \
      --name "$SITE_NAME" \
      --query "[publishingUserName, publishingPassword]" -o tsv 2>/dev/null || true)
    KUDU_USER=$(echo "$KUDU_CREDS" | head -1)
    KUDU_PASS=$(echo "$KUDU_CREDS" | tail -1)
  fi
}

get_kudu_credentials

{
  echo "=============================================="
  echo "PSU Diagnostics Report"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Site: $SITE_NAME"
  echo "Resource Group: $RESOURCE_GROUP"
  echo "=============================================="
  echo ""

  # ============================================
  # SECTION 1: Azure Instance Status
  # ============================================
  echo "=== Azure Instance Status ==="
  echo ""

  if [ "$AZURE_LOGGED_IN" = true ]; then
    # Get webapp state
    echo "--- Web App State ---"
    az webapp show --resource-group "$RESOURCE_GROUP" --name "$SITE_NAME" \
      --query "{state:state, availabilityState:availabilityState, usageState:usageState, enabled:enabled, hostNames:hostNames}" \
      -o json 2>/dev/null || echo "(failed to get webapp state)"
    echo ""

    # List instances with detailed status
    echo "--- Instance List ---"
    INSTANCES=$(az webapp list-instances --resource-group "$RESOURCE_GROUP" --name "$SITE_NAME" -o json 2>/dev/null || echo "[]")
    echo "$INSTANCES" | jq -r '.[] | "Instance: \(.name)\nState: \(.state)\nStatusUrl: \(.statusUrl)\nConsoleUrl: \(.consoleUrl)\nDetectorUrl: \(.detectorUrl)\n"' 2>/dev/null || echo "$INSTANCES"
    echo ""

    # Fetch status URL for each instance (contains VNETFailure, container health)
    echo "--- Instance Status Details ---"
    if [ -n "$KUDU_USER" ] && [ -n "$KUDU_PASS" ]; then
      for STATUS_URL in $(echo "$INSTANCES" | jq -r '.[].statusUrl' 2>/dev/null); do
        if [ -n "$STATUS_URL" ] && [ "$STATUS_URL" != "null" ]; then
          echo "Fetching: $STATUS_URL"
          curl -s -u "$KUDU_USER:$KUDU_PASS" --max-time 30 "$STATUS_URL" 2>/dev/null || echo "(failed to fetch)"
          echo ""
        fi
      done
    else
      echo "(Kudu credentials not available)"
    fi
    echo ""
  else
    echo "(Azure CLI not logged in, skipping instance status)"
    echo ""
  fi

  # ============================================
  # SECTION 2: Azure Resource Health
  # ============================================
  echo "=== Azure Resource Health ==="
  echo ""

  if [ "$AZURE_LOGGED_IN" = true ]; then
    TOKEN=$(az account get-access-token --query accessToken -o tsv 2>/dev/null || true)
    if [ -n "$TOKEN" ]; then
      curl -s -H "Authorization: Bearer $TOKEN" \
        "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$SITE_NAME/providers/Microsoft.ResourceHealth/availabilityStatuses/current?api-version=2023-10-01-preview" 2>/dev/null \
        | jq . 2>/dev/null || echo "(failed to get resource health)"
    else
      echo "(failed to get access token)"
    fi
  else
    echo "(Azure CLI not logged in, skipping resource health)"
  fi
  echo ""

  # ============================================
  # SECTION 3: Container Configuration
  # ============================================
  echo "=== Container Configuration ==="
  echo ""

  if [ "$AZURE_LOGGED_IN" = true ]; then
    echo "--- Linux FX Version ---"
    az webapp config show --resource-group "$RESOURCE_GROUP" --name "$SITE_NAME" \
      --query "linuxFxVersion" -o tsv 2>/dev/null || echo "(failed)"
    echo ""

    echo "--- App Settings ---"
    az webapp config appsettings list --resource-group "$RESOURCE_GROUP" --name "$SITE_NAME" \
      --query "[].{name:name, slotSetting:slotSetting}" -o table 2>/dev/null || echo "(failed)"
    echo ""

    echo "--- Container Settings ---"
    az webapp config container show --resource-group "$RESOURCE_GROUP" --name "$SITE_NAME" \
      -o table 2>/dev/null || echo "(failed)"
    echo ""
  else
    echo "(Azure CLI not logged in, skipping container config)"
    echo ""
  fi

  # ============================================
  # SECTION 4: Container Logs (ARM API)
  # ============================================
  echo "=== Container Logs (ARM API) ==="
  echo ""

  if [ "$AZURE_LOGGED_IN" = true ] && [ -n "${TOKEN:-}" ]; then
    # POST to get container logs
    CONTAINER_LOGS=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" \
      "https://management.azure.com/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$SITE_NAME/containerlogs?api-version=2023-12-01" 2>/dev/null || true)
    if [ -n "$CONTAINER_LOGS" ]; then
      echo "$CONTAINER_LOGS" | head -500
    else
      echo "(no container logs via ARM API)"
    fi
  else
    echo "(skipped - requires Azure CLI)"
  fi
  echo ""

  # ============================================
  # SECTION 5: PSU Database Logs
  # ============================================
  echo "=== PSU Database Logs (LogEntry table) ==="
  echo ""

  # Download database and query LogEntry table
  TEMP_DB=$(mktemp)
  "$SCRIPT_DIR/azure_psu_file_manager.sh" read database.db > "$TEMP_DB" 2>/dev/null || true

  if [ -s "$TEMP_DB" ]; then
    sqlite3 "$TEMP_DB" "SELECT printf('[%s] [%s] [%s-%s] %s', TimeStamp, Level, Feature, Resource, Message) FROM LogEntry ORDER BY LogId DESC LIMIT 1000;" 2>/dev/null || echo "(database query failed)"
  else
    echo "(could not download database)"
  fi
  rm -f "$TEMP_DB"
  echo ""

  # ============================================
  # SECTION 6: All Log Files (Kudu)
  # ============================================
  echo "=== Log Files (Kudu) ==="
  echo ""

  # Get all log files in LogFiles folder
  ALL_LOG_LIST=$("$SCRIPT_DIR/azure_psu_file_manager.sh" list LogFiles 2>/dev/null || true)
  LOG_FILES=$(echo "$ALL_LOG_LIST" | grep "text/plain" | awk '{print $2}' | sort)

  if [ -z "$LOG_FILES" ]; then
    echo "(no log files found)"
  else
    for logfile in $LOG_FILES; do
      echo "--- $logfile ---"
      "$SCRIPT_DIR/azure_psu_file_manager.sh" read "LogFiles/$logfile" 2>/dev/null || echo "(failed to read)"
      echo ""
    done
  fi

  # ============================================
  # SECTION 7: PSU REST API Logs
  # ============================================
  echo "=== PSU REST API Logs ==="
  echo ""

  if [ -z "${PSU_TOKEN:-}" ]; then
    echo "(PSU_TOKEN not set, skipping API logs)"
  else
    TEMP_ZIP=$(mktemp).zip
    TEMP_DIR=$(mktemp -d)

    HTTP_CODE=$(curl -s -w "%{http_code}" -H "Authorization: Bearer $PSU_TOKEN" "$PSU_URL/api/v1/log" -o "$TEMP_ZIP" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
      unzip -q "$TEMP_ZIP" -d "$TEMP_DIR" 2>/dev/null || true

      for log in "$TEMP_DIR"/*.txt; do
        if [ -f "$log" ]; then
          echo "--- $(basename "$log") ---"
          cat "$log"
          echo ""
        fi
      done
    else
      echo "(failed to fetch API logs - HTTP $HTTP_CODE)"
    fi

    rm -f "$TEMP_ZIP"
    rm -rf "$TEMP_DIR"
  fi

  # ============================================
  # SECTION 8: Recent Activity Log
  # ============================================
  echo "=== Azure Activity Log (last 10 events) ==="
  echo ""

  if [ "$AZURE_LOGGED_IN" = true ]; then
    az monitor activity-log list --resource-group "$RESOURCE_GROUP" --max-events 10 \
      --query "[].{time:eventTimestamp, operation:operationName.localizedValue, status:status.localizedValue, caller:caller}" \
      -o table 2>/dev/null || echo "(failed to get activity log)"
  else
    echo "(Azure CLI not logged in, skipping activity log)"
  fi
  echo ""

  echo "=============================================="
  echo "End of Diagnostics Report"
  echo "=============================================="

} > "$OUTPUT_FILE"

fi  # end LOCAL_MODE / AZURE_MODE branch

LINE_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
echo "Done. Downloaded $LINE_COUNT lines to: $OUTPUT_FILE" >&2
echo "" >&2
DISPLAY_PATH=$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1]))" "$OUTPUT_FILE" 2>/dev/null || echo "$OUTPUT_FILE")
echo "Search examples:" >&2
echo "  grep -i 'error' $DISPLAY_PATH" >&2
echo "  grep -i 'VNETFailure' $DISPLAY_PATH" >&2
echo "  grep -i 'CIEM' $DISPLAY_PATH" >&2
