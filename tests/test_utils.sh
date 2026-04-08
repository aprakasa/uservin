#!/bin/bash
#
# tests/test_utils.sh - Tests for utils.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/utils.sh"

# Test: LOG_LEVEL should default to 1
test_log_level_default() {
    assert_equals "1" "$LOG_LEVEL" "LOG_LEVEL should default to 1 (standard)"
}

# Test: DRY_RUN should default to false
test_dry_run_default() {
    assert_equals "false" "$DRY_RUN" "DRY_RUN should default to false"
}

# Test: validate_port accepts valid ports
test_validate_port_valid() {
    local all_passed=true
    for port in 22 2222 65535 1 80 443 1024; do
        if ! validate_port "$port"; then
            echo "  FAIL: Port $port should be valid"
            all_passed=false
        fi
    done
    assert_true "$all_passed" "All standard ports should be valid"
}

# Test: validate_port rejects invalid ports
test_validate_port_invalid() {
    local all_passed=true
    for port in 0 65536 -1 "abc" "" "22abc" "  "; do
        if validate_port "$port" 2>/dev/null; then
            echo "  FAIL: Port '$port' should be invalid"
            all_passed=false
        fi
    done
    assert_true "$all_passed" "All invalid ports should be rejected"
}

# Test: validate_ssh_key accepts valid keys
test_validate_ssh_key_valid() {
    local all_passed=true
    validate_ssh_key "ssh-rsa AAAAB3NzaC1 test@example" || { echo "  FAIL: ssh-rsa should be valid"; all_passed=false; }
    validate_ssh_key "ssh-ed25519 AAAAC3NzaC1 test@example" || { echo "  FAIL: ssh-ed25519 should be valid"; all_passed=false; }
    validate_ssh_key "ecdsa-sha2-nistp256 AAAAC3NzaC1 test@example" || { echo "  FAIL: ecdsa-sha2-nistp256 should be valid"; all_passed=false; }
    validate_ssh_key "ssh-dss AAAAB3NzaC1 test@example" || { echo "  FAIL: ssh-dss should be valid"; all_passed=false; }
    assert_true "$all_passed" "All valid key types should be accepted"
}

# Test: validate_ssh_key rejects invalid keys
test_validate_ssh_key_invalid() {
    local all_passed=true
    for key in "invalid-key" "" "rsa AAAAB3NzaC1" "ssh- ABC"; do
        if validate_ssh_key "$key" 2>/dev/null; then
            echo "  FAIL: Key '$key' should be rejected"
            all_passed=false
        fi
    done
    assert_true "$all_passed" "All invalid keys should be rejected"
}

# Test: cmd_exists finds existing commands
test_cmd_exists_true() {
    local all_passed=true
    cmd_exists "bash" || { echo "  FAIL: bash should exist"; all_passed=false; }
    cmd_exists "ls" || { echo "  FAIL: ls should exist"; all_passed=false; }
    cmd_exists "cat" || { echo "  FAIL: cat should exist"; all_passed=false; }
    assert_true "$all_passed" "Standard commands should exist"
}

# Test: cmd_exists returns false for non-existent commands
test_cmd_exists_false() {
    if cmd_exists "nonexistentcmd12345"; then
        assert_true "false" "Non-existent command should return false"
    else
        assert_true "true" "Non-existent command correctly returned false"
    fi
}

# Test: get_mem_gb returns a positive number
test_get_mem_gb_positive() {
    local mem
    mem=$(get_mem_gb)
    assert_true "[[ \$mem -ge 0 ]]" "get_mem_gb should return a non-negative number"
}

# Test: validate_port boundary values
test_validate_port_boundaries() {
    local all_passed=true
    validate_port "1" || { echo "  FAIL: Port 1 should be valid"; all_passed=false; }
    validate_port "65535" || { echo "  FAIL: Port 65535 should be valid"; all_passed=false; }
    validate_port "0" && { echo "  FAIL: Port 0 should be invalid"; all_passed=false; }
    validate_port "65536" && { echo "  FAIL: Port 65536 should be invalid"; all_passed=false; }
    assert_true "$all_passed" "Port boundary values should be handled correctly"
}

# Test: log functions do not crash
test_log_functions_no_crash() {
    LOG_LEVEL=2
    log_error "test error" >/dev/null 2>&1
    log_warn "test warn" >/dev/null 2>&1
    log_info "test info" >/dev/null 2>&1
    log_success "test success" >/dev/null 2>&1
    log_verbose "test verbose" >/dev/null 2>&1
    assert_true "true" "Log functions should not crash"
}

# Test: LOG_LEVEL controls output
test_log_level_quiet() {
    LOG_LEVEL=0
    local output
    output=$(log_info "should not appear" 2>&1)
    assert_true "[[ -z \"\$output\" ]]" "log_info should produce no output at level 0"
    LOG_LEVEL=1
}

# Test: init_logging creates log file
test_init_logging_creates_file() {
    local tmp_log
    tmp_log=$(mktemp)
    rm -f "$tmp_log"
    LOG_FILE="$tmp_log"
    init_logging
    assert_true "[[ -f \"\$LOG_FILE\" ]]" "init_logging should create the log file"
    rm -f "$tmp_log"
    LOG_FILE=""
}

# Test: print_header outputs text
test_print_header_output() {
    local output
    output=$(print_header "Test Section")
    assert_contains "$output" "Test Section" "print_header should contain the section name"
}

# Test: check_root returns correct value
test_check_root() {
    if [[ $EUID -eq 0 ]]; then
        assert_true "check_root" "check_root should return true when running as root"
    else
        assert_false "check_root" "check_root should return false when not running as root"
    fi
}
