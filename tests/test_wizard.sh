#!/bin/bash
#
# tests/test_wizard.sh - Tests for wizard.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/wizard.sh"

# Setup - set some config values for testing
setup() {
    CONFIG_HOSTNAME="test-server"
    CONFIG_TIMEZONE="America/New_York"
    CONFIG_USERNAME="testuser"
    CONFIG_SSH_PORT="2222"
    CONFIG_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDIhz2GK/XCUj4i6Q5yQJNL1MXMY0RxzPV2QrBqfHrDq test@example"
    CONFIG_ENABLE_AUTO_UPDATES="true"
    CONFIG_ENABLE_SWAP="false"
    CONFIG_ENABLE_ZRAM="true"
}

# Test: get_config() returns correct value for hostname
test_get_config_hostname() {
    setup
    local result
    result=$(get_config "hostname")
    assert_equals "test-server" "$result" "get_config hostname should return correct value"
}

# Test: get_config() returns correct value for timezone
test_get_config_timezone() {
    setup
    local result
    result=$(get_config "timezone")
    assert_equals "America/New_York" "$result" "get_config timezone should return correct value"
}

# Test: get_config() returns correct value for username
test_get_config_username() {
    setup
    local result
    result=$(get_config "username")
    assert_equals "testuser" "$result" "get_config username should return correct value"
}

# Test: get_config() returns correct value for ssh_port
test_get_config_ssh_port() {
    setup
    local result
    result=$(get_config "ssh_port")
    assert_equals "2222" "$result" "get_config ssh_port should return correct value"
}

# Test: get_config() returns correct value for ssh_key
test_get_config_ssh_key() {
    setup
    local result
    result=$(get_config "ssh_key")
    assert_contains "$result" "ssh-ed25519" "get_config ssh_key should return correct value"
}

# Test: get_config() returns correct boolean value for auto_updates
test_get_config_auto_updates() {
    setup
    local result
    result=$(get_config "auto_updates")
    assert_equals "true" "$result" "get_config auto_updates should return correct boolean value"
}

# Test: get_config() returns correct boolean value for enable_swap
test_get_config_enable_swap() {
    setup
    local result
    result=$(get_config "enable_swap")
    assert_equals "false" "$result" "get_config enable_swap should return correct boolean value"
}

# Test: get_config() returns correct boolean value for enable_zram
test_get_config_enable_zram() {
    setup
    local result
    result=$(get_config "enable_zram")
    assert_equals "true" "$result" "get_config enable_zram should return correct boolean value"
}

# Test: get_config() returns empty for unknown keys
test_get_config_unknown_key() {
    setup
    local result
    result=$(get_config "unknown_key")
    assert_equals "" "$result" "get_config should return empty for unknown keys"
}

# Test: load_config_file rejects missing file
test_load_config_file_missing() {
    CONFIG_FILE="/nonexistent/config.ini"
    if load_config_file 2>/dev/null; then
        assert_true "false" "load_config_file should fail for missing file"
    else
        assert_true "true" "load_config_file correctly rejects missing file"
    fi
}

# Test: load_config_file parses valid config
test_load_config_file_valid() {
    local tmp_config
    tmp_config=$(mktemp)
    cat > "$tmp_config" << 'EOF'
[system]
hostname = testhost
timezone = UTC

[user]
username = admin
ssh_key = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example

[ssh]
port = 2222

[updates]
auto_updates = false

[performance]
enable_zram = false
enable_swap = true
EOF
    CONFIG_FILE="$tmp_config"
    CONFIG_HOSTNAME=""
    CONFIG_TIMEZONE=""
    CONFIG_USERNAME=""
    CONFIG_SSH_KEY=""
    CONFIG_SSH_PORT=""
    CONFIG_ENABLE_AUTO_UPDATES=""
    CONFIG_ENABLE_ZRAM=""
    CONFIG_ENABLE_SWAP=""

    if load_config_file 2>/dev/null; then
        assert_equals "testhost" "$CONFIG_HOSTNAME" "hostname should be parsed"
        assert_equals "UTC" "$CONFIG_TIMEZONE" "timezone should be parsed"
        assert_equals "admin" "$CONFIG_USERNAME" "username should be parsed"
        assert_equals "2222" "$CONFIG_SSH_PORT" "ssh port should be parsed"
        assert_equals "false" "$CONFIG_ENABLE_AUTO_UPDATES" "auto_updates should be parsed"
        assert_equals "false" "$CONFIG_ENABLE_ZRAM" "enable_zram should be parsed"
        assert_equals "true" "$CONFIG_ENABLE_SWAP" "enable_swap should be parsed"
    else
        assert_true "false" "load_config_file should succeed with valid config"
    fi

    rm -f "$tmp_config"
    CONFIG_FILE=""
}

# Test: load_config_file rejects invalid hostname
test_load_config_file_invalid_hostname() {
    local tmp_config
    tmp_config=$(mktemp)
    cat > "$tmp_config" << 'EOF'
[system]
hostname = -invalid

[user]
username = admin
ssh_key = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example
EOF
    CONFIG_FILE="$tmp_config"
    CONFIG_HOSTNAME=""
    CONFIG_USERNAME=""
    CONFIG_SSH_KEY=""

    if load_config_file 2>/dev/null; then
        assert_true "false" "load_config_file should reject invalid hostname"
    else
        assert_true "true" "load_config_file correctly rejects invalid hostname"
    fi

    rm -f "$tmp_config"
    CONFIG_FILE=""
}

# Test: load_config_file rejects invalid username
test_load_config_file_invalid_username() {
    local tmp_config
    tmp_config=$(mktemp)
    cat > "$tmp_config" << 'EOF'
[system]
hostname = validhost

[user]
username = 123bad
ssh_key = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example
EOF
    CONFIG_FILE="$tmp_config"
    CONFIG_HOSTNAME=""
    CONFIG_USERNAME=""
    CONFIG_SSH_KEY=""

    if load_config_file 2>/dev/null; then
        assert_true "false" "load_config_file should reject invalid username"
    else
        assert_true "true" "load_config_file correctly rejects invalid username"
    fi

    rm -f "$tmp_config"
    CONFIG_FILE=""
}

# Test: load_config_file rejects invalid SSH port
test_load_config_file_invalid_port() {
    local tmp_config
    tmp_config=$(mktemp)
    cat > "$tmp_config" << 'EOF'
[system]
hostname = validhost

[user]
username = admin
ssh_key = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example

[ssh]
port = 99999
EOF
    CONFIG_FILE="$tmp_config"
    CONFIG_HOSTNAME=""
    CONFIG_USERNAME=""
    CONFIG_SSH_KEY=""
    CONFIG_SSH_PORT=""

    if load_config_file 2>/dev/null; then
        assert_true "false" "load_config_file should reject invalid port"
    else
        assert_true "true" "load_config_file correctly rejects invalid port"
    fi

    rm -f "$tmp_config"
    CONFIG_FILE=""
}

# Test: load_config_file handles inline comments
test_load_config_file_inline_comments() {
    local tmp_config
    tmp_config=$(mktemp)
    cat > "$tmp_config" << 'EOF'
[system]
hostname = testhost # this is a comment
timezone = UTC # UTC timezone

[user]
username = admin # admin user
ssh_key = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example

[ssh]
port = 2222 # custom port
EOF
    CONFIG_FILE="$tmp_config"
    CONFIG_HOSTNAME=""
    CONFIG_TIMEZONE=""
    CONFIG_USERNAME=""
    CONFIG_SSH_KEY=""
    CONFIG_SSH_PORT=""

    if load_config_file 2>/dev/null; then
        assert_equals "testhost" "$CONFIG_HOSTNAME" "hostname should strip inline comment"
        assert_equals "admin" "$CONFIG_USERNAME" "username should strip inline comment"
        assert_equals "2222" "$CONFIG_SSH_PORT" "port should strip inline comment"
    else
        assert_true "false" "load_config_file should handle inline comments"
    fi

    rm -f "$tmp_config"
    CONFIG_FILE=""
}

# Test: load_config_file warns on unknown sections
test_load_config_file_unknown_section() {
    local tmp_config
    tmp_config=$(mktemp)
    cat > "$tmp_config" << 'EOF'
[system]
hostname = testhost

[user]
username = admin
ssh_key = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example

[unknownsection]
somekey = someval
EOF
    CONFIG_FILE="$tmp_config"
    CONFIG_HOSTNAME=""
    CONFIG_USERNAME=""
    CONFIG_SSH_KEY=""

    local output
    output=$(load_config_file 2>&1)
    assert_contains "$output" "Unknown config section" "should warn about unknown section"

    rm -f "$tmp_config"
    CONFIG_FILE=""
}

# Test: load_config_file warns on unknown keys
test_load_config_file_unknown_key() {
    local tmp_config
    tmp_config=$(mktemp)
    cat > "$tmp_config" << 'EOF'
[system]
hostname = testhost
unknown_key = someval

[user]
username = admin
ssh_key = ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI test@example
EOF
    CONFIG_FILE="$tmp_config"
    CONFIG_HOSTNAME=""
    CONFIG_USERNAME=""
    CONFIG_SSH_KEY=""

    local output
    output=$(load_config_file 2>&1)
    assert_contains "$output" "Unknown config key" "should warn about unknown key"

    rm -f "$tmp_config"
    CONFIG_FILE=""
}
