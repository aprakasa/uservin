#!/bin/bash

if [[ -z "${LOG_LEVEL:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
fi

LOG_FILE="${LOG_FILE:-}"
STATUS_FILE="${STATUS_FILE:-}"
PID_FILE="${PID_FILE:-}"
NO_BACKGROUND=false

is_interactive_terminal() {
    [[ -t 0 ]] && [[ -t 1 ]] && [[ -t 2 ]]
}

is_backgrounded() {
    local ppid
    ppid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
    [[ "$ppid" -eq 1 ]]
}

get_log_dir() {
    local log_dir="/var/log/uservin"
    if mkdir -p "$log_dir" 2>/dev/null; then
        echo "$log_dir"
    else
        local fallback="/tmp/uservin-logs"
        mkdir -p "$fallback"
        echo "$fallback"
    fi
}

get_run_id() {
    echo "$(date '+%Y%m%d-%H%M%S')-$$"
}

set_run_paths() {
    if [[ -n "$LOG_FILE" ]]; then
        return 0
    fi
    local log_dir
    log_dir=$(get_log_dir)
    local run_id
    run_id=$(get_run_id)
    LOG_FILE="${log_dir}/uservin-${run_id}.log"
    STATUS_FILE="${log_dir}/status-${run_id}.json"
    PID_FILE="${log_dir}/uservin-${run_id}.pid"
}

update_status() {
    local status="$1"
    local message="${2:-}"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    if [[ -z "$STATUS_FILE" ]]; then
        set_run_paths
    fi

    message="${message//\\/\\\\}"
    message="${message//\"/\\\"}"

    printf '{\n  "status": "%s",\n  "timestamp": "%s",\n  "message": "%s",\n  "pid": %s\n}\n' \
        "$status" "$timestamp" "$message" "$$" > "$STATUS_FILE"
}

fork_to_background() {
    set_run_paths
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir" 2>/dev/null || {
        log_error "Cannot create log directory: $log_dir"
        return 1
    }

    echo "uservin is now running in background."
    echo ""
    echo "Log file: $LOG_FILE"
    echo "Status file: $STATUS_FILE"
    echo ""
    echo "Check progress with:"
    echo "  tail -f $LOG_FILE"
    echo ""
    echo "Check status with:"
    echo "  $0 --status"

    NO_BACKGROUND=true \
    LOG_FILE="$LOG_FILE" \
    STATUS_FILE="$STATUS_FILE" \
    PID_FILE="$PID_FILE" \
    nohup "$0" "$@" >> "$LOG_FILE" 2>&1 &

    local bg_pid=$!
    echo "$bg_pid" > "$PID_FILE"

    update_status "running" "Script started in background (PID: $bg_pid)"

    exit 0
}

should_auto_background() {
    [[ "$NO_BACKGROUND" != "true" ]] && [[ "$DRY_RUN" != "true" ]] && is_interactive_terminal
}

setup_background_execution() {
    if should_auto_background; then
        fork_to_background "$@"
    fi
}

get_latest_status_file() {
    local log_dir
    log_dir=$(get_log_dir)
    local latest
    latest=$(ls -t "$log_dir"/status-*.json 2>/dev/null | head -1)
    echo "${latest:-}"
}

get_latest_log_file() {
    local log_dir
    log_dir=$(get_log_dir)
    local latest
    latest=$(ls -t "$log_dir"/uservin-*.log 2>/dev/null | head -1)
    echo "${latest:-}"
}

show_status() {
    local status_file
    status_file=$(get_latest_status_file)
    local log_file
    log_file=$(get_latest_log_file)

    if [[ -z "$status_file" ]] || [[ ! -f "$status_file" ]]; then
        echo "No uservin runs found."
        echo ""
        echo "To start a new setup:"
        echo "  sudo $0"
        return 1
    fi

    local status="" timestamp="" message="" pid=""
    while IFS= read -r line; do
        case "$line" in
            *'"status"'*) status=$(echo "$line" | sed 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') ;;
            *'"timestamp"'*) timestamp=$(echo "$line" | sed 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') ;;
            *'"message"'*) message=$(echo "$line" | sed 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') ;;
            *'"pid"'*) pid=$(echo "$line" | grep -oE '[0-9]+' | head -1) ;;
        esac
    done < "$status_file"

    local run_id
    run_id=$(basename "$status_file" | sed 's/status-//;s/\.json//')

    echo "========================================"
    echo "   uservin Status"
    echo "========================================"
    echo ""
    echo "Run: $run_id"
    echo "Status: $status"
    echo "Started: $timestamp"
    [[ -n "$message" ]] && echo "Message: $message"
    [[ -n "$pid" ]] && echo "PID: $pid"
    echo ""

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "Process is currently running."
    elif [[ "$status" == "running" ]]; then
        echo "Process not found (may have crashed)."
    fi

    echo ""
    echo "Log file: $log_file"
    echo ""
    echo "View log:"
    echo "  tail -f $log_file"
}
