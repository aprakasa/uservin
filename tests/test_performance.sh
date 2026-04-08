#!/bin/bash
#
# tests/test_performance.sh - Tests for performance.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/wizard.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/safety.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/performance.sh"

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

# Test: optimize_performance() function exists and is defined
test_optimize_performance_function_exists() {
    setup
    
    # Check that function exists
    if type optimize_performance &>/dev/null; then
        assert_true "true" "optimize_performance function exists"
    else
        assert_true "false" "optimize_performance function should exist"
    fi
    
    teardown
}

# Test: configure_swap() function exists and is defined
test_configure_swap_function_exists() {
    setup
    
    # Check that function exists
    if type configure_swap &>/dev/null; then
        assert_true "true" "configure_swap function exists"
    else
        assert_true "false" "configure_swap function should exist"
    fi
    
    teardown
}

# Test: configure_zram() function exists and is defined
test_configure_zram_function_exists() {
    setup
    
    # Check that function exists
    if type configure_zram &>/dev/null; then
        assert_true "true" "configure_zram function exists"
    else
        assert_true "false" "configure_zram function should exist"
    fi
    
    teardown
}

# Test: get_cached_mem_gb returns positive value
test_get_cached_mem_gb_positive() {
    setup
    local mem
    mem=$(get_cached_mem_gb)
    assert_true "[[ \$mem -gt 0 ]]" "get_cached_mem_gb should return a positive value"
    teardown
}

# Test: get_cached_mem_gb caches result
test_get_cached_mem_gb_caches() {
    setup
    _CACHED_MEM_GB=""
    local first
    first=$(get_cached_mem_gb)
    local second
    second=$(get_cached_mem_gb)
    assert_equals "$first" "$second" "get_cached_mem_gb should return same value on second call"
    teardown
}

# Test: configure_swap skips when disabled
test_configure_swap_disabled() {
    setup
    CONFIG_ENABLE_SWAP="false"
    if configure_swap 2>/dev/null; then
        assert_true "true" "configure_swap should succeed when disabled (skip)"
    else
        assert_true "false" "configure_swap should not fail when disabled"
    fi
    teardown
}

# Test: configure_zram skips when disabled
test_configure_zram_disabled() {
    setup
    CONFIG_ENABLE_ZRAM="false"
    if configure_zram 2>/dev/null; then
        assert_true "true" "configure_zram should succeed when disabled (skip)"
    else
        assert_true "false" "configure_zram should not fail when disabled"
    fi
    teardown
}
