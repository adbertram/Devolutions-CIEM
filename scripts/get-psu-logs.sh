#!/bin/bash
# Get PSU logs from all sources (REST API + Azure Docker logs)
# Usage: ./get-psu-logs.sh [lines] [options]
#
# Options:
#   --docker-only   Only show Azure Docker logs
#   --api-only      Only show PSU REST API logs
#   --db-only       Only show PSU database logs (LogEntry table)
#   --all-files     Include all rotated log files (not just current)
#   --search TERM   Search for TERM across all logs
#
# Examples:
#   ./get-psu-logs.sh 100                    # Last 100 lines from current logs
#   ./get-psu-logs.sh 500 --all-files        # Last 500 lines from ALL log files
#   ./get-psu-logs.sh 1000 --search "error"  # Search all logs for "error"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

PSU_URL="${PSU_URL:-https://devolutions-ciem-psu.azurewebsites.net}"
LINES=50
SOURCE="all"
ALL_FILES=false
SEARCH_TERM=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --docker-only)
      SOURCE="docker"
      shift
      ;;
    --api-only)
      SOURCE="api"
      shift
      ;;
    --db-only)
      SOURCE="db"
      shift
      ;;
    --all-files)
      ALL_FILES=true
      shift
      ;;
    --search)
      SEARCH_TERM="$2"
      ALL_FILES=true  # Search implies all files
      shift 2
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        LINES=$1
      fi
      shift
      ;;
  esac
done

get_api_logs() {
  if [ -z "$PSU_TOKEN" ]; then
    echo "Warning: PSU_TOKEN not set, skipping API logs" >&2
    return 1
  fi

  echo "=== PSU System Log (via REST API) ==="
  TEMP_ZIP=$(mktemp).zip
  TEMP_DIR=$(mktemp -d)

  curl -s -H "Authorization: Bearer $PSU_TOKEN" "$PSU_URL/api/v1/log" -o "$TEMP_ZIP"
  unzip -q "$TEMP_ZIP" -d "$TEMP_DIR" 2>/dev/null

  for log in "$TEMP_DIR"/*.txt; do
    if [ -f "$log" ]; then
      if [ -n "$SEARCH_TERM" ]; then
        grep -i "$SEARCH_TERM" "$log" | tail -n "$LINES"
      else
        tail -n "$LINES" "$log"
      fi
    fi
  done

  rm -f "$TEMP_ZIP"
  rm -rf "$TEMP_DIR"
}

get_docker_logs() {
  echo "=== Azure Docker Logs ==="

  # Get list of all log files
  ALL_LOG_LIST=$("$SCRIPT_DIR/azure_psu_file_manager.sh" list LogFiles 2>/dev/null)

  if [ "$ALL_FILES" = true ]; then
    # Get ALL docker log files (sorted by name for chronological order)
    LOG_FILES=$(echo "$ALL_LOG_LIST" | grep "_docker.*\.log" | awk '{print $2}' | sort)
  else
    # Get only current (non-rotated) docker log files from today
    TODAY=$(date -u +%Y_%m_%d)
    LOG_FILES=$(echo "$ALL_LOG_LIST" | grep "${TODAY}.*_docker\.log$" | awk '{print $2}' | sort)

    if [ -z "$LOG_FILES" ]; then
      # Fallback: get most recent docker logs
      LOG_FILES=$(echo "$ALL_LOG_LIST" | grep "_docker\.log$" | awk '{print $2}' | sort | tail -3)
    fi
  fi

  for logfile in $LOG_FILES; do
    echo "--- $logfile ---"
    if [ -n "$SEARCH_TERM" ]; then
      "$SCRIPT_DIR/azure_psu_file_manager.sh" read "LogFiles/$logfile" 2>/dev/null | grep -i "$SEARCH_TERM" | tail -n "$LINES"
    else
      "$SCRIPT_DIR/azure_psu_file_manager.sh" read "LogFiles/$logfile" 2>/dev/null | tail -n "$LINES"
    fi
  done
}

get_dashboard_logs() {
  if [ -z "$PSU_TOKEN" ]; then
    echo "Warning: PSU_TOKEN not set, skipping dashboard logs" >&2
    return 1
  fi

  echo "=== PSU Dashboard/App Logs ==="

  # Get list of dashboards
  DASHBOARDS=$(curl -s -H "Authorization: Bearer $PSU_TOKEN" "$PSU_URL/api/v1/dashboard" 2>/dev/null)

  if [ -z "$DASHBOARDS" ] || [ "$DASHBOARDS" = "[]" ]; then
    echo "No dashboards found"
    return 0
  fi

  # Extract dashboard IDs and names
  echo "$DASHBOARDS" | jq -r '.[] | "\(.id)|\(.name)"' 2>/dev/null | while IFS='|' read -r id name; do
    echo "--- Dashboard: $name (ID: $id) ---"
    LOG_CONTENT=$(curl -s -H "Authorization: Bearer $PSU_TOKEN" "$PSU_URL/api/v1/dashboard/$id/log" 2>/dev/null)
    if [ -n "$LOG_CONTENT" ]; then
      if [ -n "$SEARCH_TERM" ]; then
        echo "$LOG_CONTENT" | grep -i "$SEARCH_TERM" | tail -n "$LINES"
      else
        echo "$LOG_CONTENT" | tail -n "$LINES"
      fi
    else
      echo "(no logs via API - check database logs)"
    fi
  done
}

get_database_logs() {
  echo "=== PSU Database Logs (LogEntry table) ==="

  # Download database and query LogEntry table
  TEMP_DB=$(mktemp)
  "$SCRIPT_DIR/azure_psu_file_manager.sh" read database.db > "$TEMP_DB" 2>/dev/null

  if [ ! -s "$TEMP_DB" ]; then
    echo "Could not download database"
    rm -f "$TEMP_DB"
    return 1
  fi

  # Build query based on search term
  if [ -n "$SEARCH_TERM" ]; then
    QUERY="SELECT printf('[%s] [%s] [%s-%s] %s', TimeStamp, Level, Feature, Resource, Message) FROM LogEntry WHERE Message LIKE '%${SEARCH_TERM}%' OR Resource LIKE '%${SEARCH_TERM}%' OR Feature LIKE '%${SEARCH_TERM}%' ORDER BY LogId DESC LIMIT $LINES;"
  else
    QUERY="SELECT printf('[%s] [%s] [%s-%s] %s', TimeStamp, Level, Feature, Resource, Message) FROM LogEntry ORDER BY LogId DESC LIMIT $LINES;"
  fi

  sqlite3 "$TEMP_DB" "$QUERY" 2>/dev/null

  rm -f "$TEMP_DB"
}

# Show what we're doing
if [ -n "$SEARCH_TERM" ]; then
  echo "Searching for: '$SEARCH_TERM' (last $LINES matches per file)"
  echo ""
fi

case "$SOURCE" in
  docker)
    get_docker_logs
    ;;
  api)
    get_api_logs
    ;;
  db)
    get_database_logs
    ;;
  *)
    get_database_logs
    echo ""
    get_docker_logs
    echo ""
    get_api_logs
    ;;
esac
