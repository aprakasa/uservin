#!/bin/bash
#
# tests/test_security.sh - Tests for security.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/wizard.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/safety.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/security.sh"

# Setup and teardown
setup() {
    # Create temp directories for testing
    TEST_DIR=$(mktemp -d)
    TEST_BACKUP_DIR=$(mktemp -d)
    
    # Set up test environment
    BACKUP_DIR="$TEST_BACKUP_DIR"
    BACKUP_FILES=()
    ROLLBACK_NEEDED=false
    DRY_RUN=false
    
    # Set up configuration for tests
    CONFIG_HOSTNAME="test-server"
    CONFIG_TIMEZONE="UTC"
    CONFIG_USERNAME="testuser"
    CONFIG_SSH_PORT="2222"
    CONFIG_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID test@example.com"
    CONFIG_ENABLE_AUTO_UPDATES="true"
    CONFIG_ENABLE_SWAP="false"
    CONFIG_ENABLE_ZRAM="false"
}

teardown() {
    # Clean up test directories
    rm -rf "$TEST_DIR"
    rm -rf "$TEST_BACKUP_DIR"
    
    # Reset global state
    BACKUP_DIR=""
    BACKUP_FILES=()
    ROLLBACK_NEEDED=false
    DRY_RUN=false
}

# Test: harden_ssh() function exists and is defined
test_harden_ssh_function_exists() {
    setup
    
    # Verify the function exists
    if type harden_ssh &>/dev/null; then
        assert_true "true" "harden_ssh function exists"
    else
        assert_true "false" "harden_ssh function should exist"
    fi
    
    teardown
}

# Test: configure_ufw() function exists and is defined
test_configure_ufw_function_exists() {
    setup
    
    # Verify the function exists
    if type configure_ufw &>/dev/null; then
        assert_true "true" "configure_ufw function exists"
    else
        assert_true "false" "configure_ufw function should exist"
    fi
    
    teardown
}

# Test: configure_fail2ban() function exists and is defined
test_configure_fail2ban_function_exists() {
    setup
    
    # Verify the function exists
    if type configure_fail2ban &>/dev/null; then
        assert_true "true" "configure_fail2ban function exists"
    else
        assert_true "false" "configure_fail2ban function should exist"
    fi
    
    teardown
}

# Test: configure_auto_updates() function exists and is defined
test_configure_auto_updates_function_exists() {
    setup
    
    # Verify the function exists
    if type configure_auto_updates &>/dev/null; then
        assert_true "true" "configure_auto_updates function exists"
    else
        assert_true "false" "configure_auto_updates function should exist"
    fi
    
    teardown
}
