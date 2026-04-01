#!/bin/bash

if [[ -z "${LOG_LEVEL:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
fi

LOG_FILE=""
STATUS_FILE=""
PID_FILE=""
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
    date '+%Y%m%d-%H%M%S'
}

set_run_paths() {
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

    cat > "$STATUS_FILE" <<EOF
{
  "status": "$status",
  "timestamp": "$timestamp",
  "message": "$message",
  "pid": $$
}
EOF
}

fork_to_background() {
    if [[ -z "$LOG_FILE" ]]; then
        set_run_paths
    fi

    (
        exec > "$LOG_FILE" 2>&1
        echo $$ > "$PID_FILE"
        update_status "running" "Background execution started"
        trap '' HUP
    ) &

    local bg_pid=$!
    echo "$bg_pid" > "$PID_FILE"

    echo "uservin forked to background (PID: $bg_pid)"
    echo "  Log:    $LOG_FILE"
    echo "  Status: $STATUS_FILE"
    exit 0
}

should_auto_background() {
    [[ "$NO_BACKGROUND" != "true" ]] && [[ "$DRY_RUN" != "true" ]] && is_interactive_terminal
}

setup_background_execution() {
    if should_auto_background; then
        fork_to_background
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

    if [[ -z "$status_file" ]] || [[ ! -f "$status_file" ]]; then
        echo "No status file found."
        return 1
    fi

    local status timestamp message pid
    status=$(grep -o '"status": *"[^"]*"' "$status_file" | head -1 | sed 's/"status": *"//;s/"//')
    timestamp=$(grep -o '"timestamp": *"[^"]*"' "$status_file" | head -1 | sed 's/"timestamp": *"//;s/"//')
    message=$(grep -o '"message": *"[^"]*"' "$status_file" | head -1 | sed 's/"message": *"//;s/"//')
    pid=$(grep -o '"pid": *[0-9]*' "$status_file" | head -1 | sed 's/"pid": *//')

    local run_id
    run_id=$(basename "$status_file" | sed 's/status-//;s/\.json//')

    echo "Run ID:    $run_id"
    echo "Status:    $status"
    echo "Timestamp: $timestamp"
    echo "Message:   $message"
    echo "PID:       $pid"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "Process:   Running (PID $pid is active)"
    else
        echo "Process:   Not running (PID $pid not found)"
    fi
}
