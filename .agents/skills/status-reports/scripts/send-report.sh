#!/usr/bin/env bash
set -euo pipefail

# Send a CIEM status report (text + screenshots) to the Devolutions team group DM.
# Usage: send-report.sh [--dryrun] <report-dir>
# Example: send-report.sh reports/2026-04-04
# Example: send-report.sh --dryrun reports/2026-04-04
#
# The report directory must contain:
#   report.md  — The message text to send
#   *.png      — Screenshots to upload (optional)
#
# Screenshots are uploaded first so they appear above the text in Slack.
#
# --dryrun: Send report as a DM to adbertram for review instead of the team channel.

CHANNEL="C0AFCLP7SUF"
DRYRUN_USER="adbertram"
DRYRUN_DM_CHANNEL="D01S2QLN4AF"
PROFILE="devolutions"
DRYRUN=false

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dryrun)
            DRYRUN=true
            shift
            ;;
        -*)
            echo "Unknown flag: $1"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [--dryrun] <report-dir>"
    echo "Example: $0 reports/2026-04-04"
    echo "Example: $0 --dryrun reports/2026-04-04"
    exit 1
fi

REPORT_DIR="$1"

if [[ ! -d "$REPORT_DIR" ]]; then
    echo "Error: Report directory not found: $REPORT_DIR"
    exit 1
fi

REPORT_FILE="$REPORT_DIR/report.md"
if [[ ! -f "$REPORT_FILE" ]]; then
    echo "Error: report.md not found in $REPORT_DIR"
    exit 1
fi

# Determine target based on dryrun mode
if [[ "$DRYRUN" == "true" ]]; then
    TARGET="$DRYRUN_USER"
    echo "[DRYRUN] Sending report to $TARGET for review (not the team channel)"
else
    TARGET="$CHANNEL"
fi

# Upload screenshots first (they appear above the text message in Slack)
screenshot_count=0
for img in "$REPORT_DIR"/*.png; do
    [[ -f "$img" ]] || continue
    filename=$(basename "$img" .png)
    title=$(echo "$filename" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    echo "Uploading screenshot: $img (title: $title)"
    if [[ "$DRYRUN" == "true" ]]; then
        slack --profile "$PROFILE" files upload "$img" --channels "$DRYRUN_DM_CHANNEL" --title "$title"
    else
        slack --profile "$PROFILE" files upload "$img" --channels "$CHANNEL" --title "$title"
    fi
    screenshot_count=$((screenshot_count + 1))
done

if [[ $screenshot_count -gt 0 ]]; then
    echo "Uploaded $screenshot_count screenshot(s)"
else
    echo "No screenshots found in $REPORT_DIR"
fi

# Send the report text
message=$(cat "$REPORT_FILE")
echo "Sending report message..."
slack --profile "$PROFILE" dm send "$TARGET" "$message"

if [[ "$DRYRUN" == "true" ]]; then
    echo "[DRYRUN] Status report sent to $DRYRUN_USER for review. Run without --dryrun to send to the team."
else
    echo "Status report sent successfully."
fi
