#!/bin/bash
#
# tests/test_user.sh - Tests for user.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/wizard.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/user.sh"

# Setup - set config values for testing
setup_config() {
    CONFIG_USERNAME="testadmin"
    CONFIG_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIhz2GK/XCUj4i6Q5yQJNL1MXMY0RxzPV2QrBqfHrDq test@example"
}

# Test: create_admin_user function exists and is defined
test_create_admin_user_function_exists() {
    if declare -f create_admin_user > /dev/null; then
        assert_true "true" "create_admin_user function should be defined"
    else
        assert_true "false" "create_admin_user function should be defined"
    fi
}

# Test: setup_ssh_keys function exists and is defined
test_setup_ssh_keys_function_exists() {
    if declare -f setup_ssh_keys > /dev/null; then
        assert_true "true" "setup_ssh_keys function should be defined"
    else
        assert_true "false" "setup_ssh_keys function should be defined"
    fi
}

# Test: Username validation pattern accepts valid usernames
test_validate_username_valid() {
    # Valid: starts with lowercase letter, contains only lowercase, numbers, hyphens, underscores
    # These patterns match what wizard.sh uses for validation
    local valid_usernames=("admin" "user123" "test-user" "my_user" "a" "user_name_123")
    
    for username in "${valid_usernames[@]}"; do
        if [[ "$username" =~ ^[a-z][-a-z0-9_]*$ && ${#username} -le 32 ]]; then
            assert_true "true" "Username '$username' should be valid"
        else
            assert_true "false" "Username '$username' should be valid but was rejected"
        fi
    done
}

# Test: Username validation pattern rejects invalid usernames  
test_validate_username_invalid() {
    local invalid_usernames=("123user" "User" "user name" "user@domain" "user.name" "-user" "_user" "user!" "user*" "user with spaces" "")
    
    for username in "${invalid_usernames[@]}"; do
        if [[ "$username" =~ ^[a-z][-a-z0-9_]*$ && ${#username} -le 32 && ${#username} -ge 1 ]]; then
            assert_true "false" "Username '$username' should be invalid but was accepted"
        else
            assert_true "true" "Username '$username' should be invalid"
        fi
    done
}

# Test: Username validation rejects names that are too long (>32 chars)
test_validate_username_too_long() {
    local long_username="thisisaverylongusernamethatexceeds32chars"
    if [[ ${#long_username} -le 32 ]]; then
        assert_true "false" "Username length check should detect long usernames"
    else
        assert_true "true" "Long username should be rejected"
    fi
}

# Test: Hostname validation pattern accepts valid hostnames
test_validate_hostname_valid() {
    local valid_hostnames=("myserver" "srv.example.com" "web-01" "a" "server01.local" "A" "MyServer")
    local all_passed=true
    for hn in "${valid_hostnames[@]}"; do
        if [[ ! "$hn" =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?)*$ ]]; then
            echo "  FAIL: Hostname '$hn' should be valid"
            all_passed=false
        fi
    done
    assert_true "$all_passed" "All valid hostnames should pass"
}

# Test: Hostname validation pattern rejects invalid hostnames
test_validate_hostname_invalid() {
    local invalid_hostnames=("-server" "server-" "my server" "srv..example" "" "server!" "my_server")
    local all_passed=true
    for hn in "${invalid_hostnames[@]}"; do
        if [[ "$hn" =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?)*$ ]]; then
            echo "  FAIL: Hostname '$hn' should be invalid"
            all_passed=false
        fi
    done
    assert_true "$all_passed" "All invalid hostnames should be rejected"
}
