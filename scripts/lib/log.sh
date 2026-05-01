#!/usr/bin/env bash
# Shared append-only logger for project shell scripts.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _LOG_SH_EXECUTED=1
else
    _LOG_SH_EXECUTED=0
fi

if [[ "$_LOG_SH_EXECUTED" -eq 0 ]]; then
    if [[ -n "${_LOG_SH_LOADED:-}" ]]; then return 0; fi
    _LOG_SH_LOADED=1
fi

_log_resolve_file() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        printf '%s' "$LOG_FILE"
        return
    fi

    local script="$0"
    if [[ -z "$script" || "$script" == "-bash" || "$script" == "bash" || "$script" == "-zsh" || "$script" == "zsh" ]]; then
        echo "log.sh: cannot resolve calling script ($0); set LOG_FILE explicitly" >&2
        return 1
    fi

    local dir name
    dir="$(cd "$(dirname "$script")" && pwd)"
    name="$(basename "$script")"
    name="${name%.sh}"
    printf '%s/%s.log' "$dir" "$name"
}

_log_write() {
    local level="$1"
    shift
    local message="$*"
    local file ts
    file="$(_log_resolve_file)" || return 1
    ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    mkdir -p "$(dirname "$file")"
    printf '[%s] [%s] %s\n' "$ts" "$level" "$message" >> "$file"
}

log_info() { _log_write "INFO" "$@"; }
log_warn() { _log_write "WARN" "$@"; }
log_error() { _log_write "ERROR" "$@"; }
log_debug() {
    [[ "${LOG_DEBUG:-0}" == "1" ]] || return 0
    _log_write "DEBUG" "$@"
}

log_path() { _log_resolve_file; }

_log_resolve_target() {
    local target="$1"
    if [[ "$target" == *.log ]]; then
        printf '%s' "$target"
        return
    fi
    if [[ "$target" == *.sh ]]; then
        local dir name
        dir="$(cd "$(dirname "$target")" && pwd)"
        name="$(basename "$target" .sh)"
        printf '%s/%s.log' "$dir" "$name"
        return
    fi
    if [[ -f "$target.log" ]]; then
        printf '%s.log' "$target"
        return
    fi
    printf '%s' "$target"
}

log_read() {
    local follow=0
    local lines=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--follow) follow=1; shift ;;
            -n|--lines) lines="$2"; shift 2 ;;
            -h|--help)
                cat <<'EOF'
log_read [-f|--follow] [-n N] <script-or-log-path>
  Read or tail a log file produced by this logger.
EOF
                return 0
                ;;
            -*) echo "log_read: unknown flag: $1" >&2; return 2 ;;
            *) break ;;
        esac
    done

    if [[ $# -ne 1 ]]; then
        echo "log_read: expected exactly one path argument" >&2
        return 2
    fi

    local file
    file="$(_log_resolve_target "$1")"

    if [[ ! -f "$file" ]]; then
        echo "log_read: file not found: $file" >&2
        return 1
    fi

    if [[ "$follow" -eq 1 ]]; then
        if [[ -n "$lines" ]]; then
            tail -n "$lines" -f "$file"
        else
            tail -n 0 -f "$file"
        fi
    else
        if [[ -n "$lines" ]]; then
            tail -n "$lines" "$file"
        else
            cat "$file"
        fi
    fi
}

_log_print_path_on_exit() {
    local rc=$?
    local file
    file="$(_log_resolve_file 2>/dev/null)" || return "$rc"
    printf 'Log: %s\n' "$file" >&2
    return "$rc"
}

if [[ "$_LOG_SH_EXECUTED" -eq 0 && "${LOG_NO_EXIT_TRAP:-0}" != "1" ]]; then
    trap '_log_print_path_on_exit' EXIT
fi

if [[ "$_LOG_SH_EXECUTED" -eq 1 ]]; then
    set -euo pipefail

    _log_cli_usage() {
        cat <<'EOF'
Usage:
  log.sh read [-f|--follow] [-n N] <script-or-log-path>
  log.sh path <script-or-log-path>
EOF
    }

    cmd="${1:-}"
    if [[ $# -gt 0 ]]; then shift; fi

    case "$cmd" in
        read) log_read "$@" ;;
        path)
            if [[ $# -ne 1 ]]; then
                echo "log.sh path: expected one argument" >&2
                exit 2
            fi
            _log_resolve_target "$1"
            echo
            ;;
        -h|--help|"") _log_cli_usage ;;
        *) echo "log.sh: unknown command: $cmd" >&2; _log_cli_usage >&2; exit 2 ;;
    esac
fi
