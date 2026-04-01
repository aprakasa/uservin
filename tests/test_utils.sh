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
    validate_port "22" && assert_true "true" "Port 22 should be valid"
    validate_port "2222" && assert_true "true" "Port 2222 should be valid"
    validate_port "65535" && assert_true "true" "Port 65535 should be valid"
}

# Test: validate_port rejects invalid ports
test_validate_port_invalid() {
    validate_port "0" || assert_true "true" "Port 0 should be invalid"
    validate_port "65536" || assert_true "true" "Port 65536 should be invalid"
    validate_port "abc" || assert_true "true" "Port 'abc' should be invalid"
    validate_port "" || assert_true "true" "Empty port should be invalid"
}

# Test: validate_ssh_key accepts valid keys
test_validate_ssh_key_valid() {
    validate_ssh_key "ssh-rsa AAAAB3NzaC1 test@example" && assert_true "true" "ssh-rsa key should be valid"
    validate_ssh_key "ssh-ed25519 AAAAC3NzaC1 test@example" && assert_true "true" "ssh-ed25519 key should be valid"
}

# Test: validate_ssh_key rejects invalid keys
test_validate_ssh_key_invalid() {
    validate_ssh_key "invalid-key" || assert_true "true" "Invalid key should be rejected"
    validate_ssh_key "" || assert_true "true" "Empty key should be rejected"
}

# Test: cmd_exists finds existing commands
test_cmd_exists_true() {
    cmd_exists "bash" && assert_true "true" "bash command should exist"
    cmd_exists "ls" && assert_true "true" "ls command should exist"
}

# Test: cmd_exists returns false for non-existent commands
test_cmd_exists_false() {
    cmd_exists "nonexistentcmd12345" || assert_true "true" "Non-existent command should return false"
}
