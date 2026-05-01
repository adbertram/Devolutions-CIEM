#!/usr/bin/env bash
# Print archived CIEM status reports for duplicate-prevention review.

set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
SCRIPT_SOURCE_DIR="${SCRIPT_SOURCE%/*}"
if [[ "$SCRIPT_SOURCE_DIR" == "$SCRIPT_SOURCE" ]]; then
    SCRIPT_SOURCE_DIR="."
fi

REPO_ROOT="$(git -C "$SCRIPT_SOURCE_DIR" rev-parse --show-toplevel)"
. "$REPO_ROOT/scripts/lib/log.sh"

SCRIPT_NAME="${0##*/}"
SCRIPT_DIR="$(cd "$SCRIPT_SOURCE_DIR" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_DAYS=7
MODE="days"
DAYS="$DEFAULT_DAYS"
SINCE_DATE=""
REPORT_DIRS=()
SEEN_DATES=" "

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Print archived CIEM status report content.

Options:
  --days N             Include reports from the last N days. Default: 7.
  --since YYYY-MM-DD   Include reports dated on or after YYYY-MM-DD.
  --all                Include every archived report.
  -h, --help           Show this help.
EOF
}

validate_positive_integer() {
    local value="$1"
    local flag="$2"

    case "$value" in
        ""|*[!0-9]*)
            log_error "invalid $flag value: $value"
            usage >&2
            exit 2
            ;;
        0)
            log_error "$flag must be greater than zero"
            usage >&2
            exit 2
            ;;
    esac
}

validate_report_date() {
    local value="$1"
    local flag="$2"

    if [[ ! "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        log_error "invalid $flag date format: $value"
        usage >&2
        exit 2
    fi

    log_info "date validate $flag=$value"
    date -j -f "%Y-%m-%d" "$value" "+%Y-%m-%d" >/dev/null || {
        log_error "invalid $flag date: $value"
        exit 2
    }
    log_info "date validate $flag=$value completed"
}

add_report_dir() {
    local dir="$1"
    local resolved existing

    if [[ ! -d "$dir" ]]; then
        log_debug "report archive missing dir=$dir"
        return
    fi

    resolved="$(cd "$dir" && pwd)"
    if [[ "${#REPORT_DIRS[@]}" -gt 0 ]]; then
        for existing in "${REPORT_DIRS[@]}"; do
            if [[ "$existing" == "$resolved" ]]; then
                return
            fi
        done
    fi

    REPORT_DIRS+=("$resolved")
    log_info "report archive included dir=$resolved"
}

already_seen_date() {
    local value="$1"
    [[ "$SEEN_DATES" == *" $value "* ]]
}

mark_seen_date() {
    local value="$1"
    SEEN_DATES="${SEEN_DATES}${value} "
}

include_report_date() {
    local value="$1"

    if [[ "$MODE" == "all" ]]; then
        return 0
    fi

    [[ ! "$value" < "$SINCE_DATE" ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days)
            if [[ $# -lt 2 ]]; then
                log_error "--days requires a value"
                usage >&2
                exit 2
            fi
            validate_positive_integer "$2" "--days"
            MODE="days"
            DAYS="$2"
            shift 2
            ;;
        --since)
            if [[ $# -lt 2 ]]; then
                log_error "--since requires a value"
                usage >&2
                exit 2
            fi
            validate_report_date "$2" "--since"
            MODE="since"
            SINCE_DATE="$2"
            shift 2
            ;;
        --all)
            MODE="all"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "unknown flag: $1"
            usage >&2
            exit 2
            ;;
    esac
done

log_info "starting $SCRIPT_NAME mode=$MODE"
log_info "git rev-parse --show-toplevel completed repo=$REPO_ROOT"

if [[ "$MODE" == "days" ]]; then
    log_info "date compute cutoff days=$DAYS"
    SINCE_DATE="$(date -u -v-"${DAYS}"d +%Y-%m-%d)"
    log_info "date compute cutoff completed since=$SINCE_DATE"
fi

add_report_dir "$SKILL_DIR/reports"
add_report_dir "$REPO_ROOT/.agents/skills/status-reports/reports"
add_report_dir "$REPO_ROOT/.claude/skills/status-reports/reports"

if [[ "${#REPORT_DIRS[@]}" -eq 0 ]]; then
    log_warn "no status report archives found"
    printf '# Status Reports\n\nNo status reports found.\n'
    log_info "done matched=0"
    exit 0
fi

if [[ "$MODE" == "all" ]]; then
    printf '# Status Reports\n\nFilter: all archived reports\n'
else
    printf '# Status Reports\n\nFilter: reports dated on or after %s\n' "$SINCE_DATE"
fi

matched=0
shopt -s nullglob
for reports_dir in "${REPORT_DIRS[@]}"; do
    for report_file in "$reports_dir"/*/report.md; do
        report_parent="${report_file%/*}"
        report_date="${report_parent##*/}"

        if [[ ! "$report_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            log_warn "skipping report with invalid date dir=$report_parent"
            continue
        fi

        if already_seen_date "$report_date"; then
            log_debug "skipping duplicate report date=$report_date file=$report_file"
            continue
        fi

        if ! include_report_date "$report_date"; then
            log_debug "skipping report outside filter date=$report_date"
            continue
        fi

        if [[ ! -s "$report_file" ]]; then
            log_warn "skipping empty report file=$report_file"
            continue
        fi

        printf '\n## %s\n\nReport file: %s\n\n' "$report_date" "$report_file"
        while IFS= read -r line || [[ -n "$line" ]]; do
            printf '%s\n' "$line"
        done < "$report_file"

        mark_seen_date "$report_date"
        matched=$((matched + 1))
        log_info "included report date=$report_date file=$report_file"
    done
done

if [[ "$matched" -eq 0 ]]; then
    log_warn "no status reports matched filter mode=$MODE since=$SINCE_DATE"
    printf '\nNo status reports matched the selected filter.\n'
fi

log_info "done matched=$matched"
