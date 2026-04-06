#!/usr/bin/env bash
set -euo pipefail

# Send a CIEM status report (text + screenshots) to the Devolutions team group DM.
# Usage: send-report.sh <report-dir>
# Example: send-report.sh reports/2026-04-04
#
# The report directory must contain:
#   report.md  — The message text to send
#   *.png      — Screenshots to upload (optional)
#
# Screenshots are uploaded first so they appear above the text in Slack.

CHANNEL="C0AFCLP7SUF"
PROFILE="devolutions"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <report-dir>"
    echo "Example: $0 reports/2026-04-04"
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

# Upload screenshots first (they appear above the text message in Slack)
screenshot_count=0
for img in "$REPORT_DIR"/*.png; do
    [[ -f "$img" ]] || continue
    filename=$(basename "$img" .png)
    title=$(echo "$filename" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    echo "Uploading screenshot: $img (title: $title)"
    slack --profile "$PROFILE" files upload "$img" --channels "$CHANNEL" --title "$title"
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
slack --profile "$PROFILE" dm send "$CHANNEL" "$message"

echo "Status report sent successfully."
