#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/background.sh"

test_is_interactive_terminal() {
    if [[ -t 0 ]] && [[ -t 1 ]] && [[ -t 2 ]]; then
        assert_true "is_interactive_terminal" "should detect interactive terminal"
    else
        assert_false "is_interactive_terminal" "should detect non-interactive terminal"
    fi
}

test_get_log_dir() {
    local log_dir
    log_dir=$(get_log_dir)
    assert_true "[[ -n \"\$log_dir\" ]]" "get_log_dir should return non-empty path"
    assert_true "[[ -d \"\$log_dir\" ]]" "get_log_dir should return existing directory"
}

test_get_run_id() {
    local run_id
    run_id=$(get_run_id)
    assert_true "[[ -n \"\$run_id\" ]]" "get_run_id should return non-empty value"
    assert_true "[[ \"\$run_id\" =~ ^[0-9]{8}-[0-9]{6}\$ ]]" "get_run_id should match YYYYMMDD-HHMMSS format"
}

test_set_run_paths() {
    LOG_FILE=""
    STATUS_FILE=""
    PID_FILE=""
    set_run_paths
    assert_true "[[ -n \"\$LOG_FILE\" ]]" "LOG_FILE should be set"
    assert_true "[[ -n \"\$STATUS_FILE\" ]]" "STATUS_FILE should be set"
    assert_true "[[ -n \"\$PID_FILE\" ]]" "PID_FILE should be set"
    assert_true "[[ \"\$LOG_FILE\" == *.log ]]" "LOG_FILE should have .log extension"
    assert_true "[[ \"\$STATUS_FILE\" == *.json ]]" "STATUS_FILE should have .json extension"
    assert_true "[[ \"\$PID_FILE\" == *.pid ]]" "PID_FILE should have .pid extension"
}

test_update_status() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    STATUS_FILE="$tmp_dir/test-status.json"
    update_status "testing" "test message"
    assert_true "[[ -f \"\$STATUS_FILE\" ]]" "status file should be created"
    local content
    content=$(cat "$STATUS_FILE")
    assert_contains "$content" '"status": "testing"' "status file should contain status"
    assert_contains "$content" '"message": "test message"' "status file should contain message"
    assert_contains "$content" '"pid":' "status file should contain pid"
    rm -rf "$tmp_dir"
}

test_should_auto_background_dry_run() {
    local saved_dry_run="$DRY_RUN"
    local saved_no_background="$NO_BACKGROUND"
    DRY_RUN=true
    NO_BACKGROUND=false
    assert_false "should_auto_background" "should not auto-background during dry-run"
    DRY_RUN="$saved_dry_run"
    NO_BACKGROUND="$saved_no_background"
}

test_should_auto_background_no_background() {
    local saved_dry_run="$DRY_RUN"
    local saved_no_background="$NO_BACKGROUND"
    DRY_RUN=false
    NO_BACKGROUND=true
    assert_false "should_auto_background" "should not auto-background when NO_BACKGROUND is set"
    DRY_RUN="$saved_dry_run"
    NO_BACKGROUND="$saved_no_background"
}

test_should_auto_background_not_interactive() {
    local saved_dry_run="$DRY_RUN"
    local saved_no_background="$NO_BACKGROUND"
    DRY_RUN=false
    NO_BACKGROUND=false
    if ! is_interactive_terminal; then
        assert_false "should_auto_background" "should not auto-background when not interactive"
    fi
    DRY_RUN="$saved_dry_run"
    NO_BACKGROUND="$saved_no_background"
}
