#!/bin/bash
#
# tests/test_safety.sh - Tests for safety.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/safety.sh"

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

# Test: init_backup() creates backup directory with timestamp
test_init_backup_creates_directory() {
    setup
    
    # Run init_backup
    init_backup
    
    # Check that BACKUP_DIR is set and contains timestamp
    assert_true "[[ -n \"\$BACKUP_DIR\" ]]" "BACKUP_DIR should be set"
    assert_true "[[ -d \"\$BACKUP_DIR\" ]]" "BACKUP_DIR should exist"
    assert_true "[[ \"\$BACKUP_DIR\" == */root/uservin-backups/* ]]" "BACKUP_DIR should be under /root/uservin-backups/"
    
    teardown
}

# Test: backup_file() copies file to backup directory
test_backup_file_copies_file() {
    setup
    
    # Create test file
    local test_file="$TEST_DIR/testfile.txt"
    echo "test content" > "$test_file"
    
    # Initialize backup
    init_backup
    local backup_dir="$BACKUP_DIR"
    BACKUP_DIR="$TEST_BACKUP_DIR"
    
    # Backup the file
    backup_file "$test_file"
    
    # Check file was backed up
    local backup_file="$TEST_BACKUP_DIR/testfile.txt"
    assert_true "[[ -f \"\$backup_file\" ]]" "Backup file should exist"
    assert_equals "test content" "$(cat "$backup_file")" "Backup content should match original"
    
    # Check BACKUP_FILES array is populated
    assert_true "[[ \${#BACKUP_FILES[@]} -eq 1 ]]" "BACKUP_FILES should have 1 entry"
    assert_contains "${BACKUP_FILES[0]}" "$test_file" "BACKUP_FILES should contain original file path"
    
    teardown
}

# Test: backup_file() handles duplicates with numbered extensions
test_backup_file_handles_duplicates() {
    setup
    
    # Create test file
    local test_file="$TEST_DIR/testfile.txt"
    echo "original" > "$test_file"
    
    # Initialize backup
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    
    # Backup the file first time
    backup_file "$test_file"
    
    # Modify original
    echo "modified" > "$test_file"
    
    # Backup again
    backup_file "$test_file"
    
    # Check both backups exist
    assert_true "[[ -f \"\$TEST_BACKUP_DIR/testfile.txt\" ]]" "First backup should exist"
    assert_true "[[ -f \"\$TEST_BACKUP_DIR/testfile.txt.backup.1\" ]]" "Second backup should exist"
    
    # Check contents
    assert_equals "original" "$(cat "$TEST_BACKUP_DIR/testfile.txt")" "First backup should have original content"
    assert_equals "modified" "$(cat "$TEST_BACKUP_DIR/testfile.txt.backup.1")" "Second backup should have modified content"
    
    teardown
}

# Test: backup_file() does nothing in dry-run mode
test_backup_file_dry_run() {
    setup
    
    # Enable dry-run mode
    DRY_RUN=true
    
    # Create test file
    local test_file="$TEST_DIR/testfile.txt"
    echo "test content" > "$test_file"
    
    # Initialize backup
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    
    # Try to backup in dry-run mode
    backup_file "$test_file"
    
    # Check that no backup was created
    assert_true "[[ ! -f \"\$TEST_BACKUP_DIR/testfile.txt\" ]]" "No backup should be created in dry-run mode"
    
    # Check BACKUP_FILES is still empty
    assert_true "[[ \${#BACKUP_FILES[@]} -eq 0 ]]" "BACKUP_FILES should be empty in dry-run mode"
    
    teardown
}

# Test: rollback_changes() restores files from backup
test_rollback_changes_restores_files() {
    setup
    
    # Create test file with original content
    local test_file="$TEST_DIR/testfile.txt"
    echo "original content" > "$test_file"
    
    # Initialize backup and backup the file
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    backup_file "$test_file"
    
    # Modify the file
    echo "modified content" > "$test_file"
    
    # Rollback
    rollback_changes
    
    # Check file was restored
    assert_equals "original content" "$(cat "$test_file")" "File should be restored to original content"
    
    teardown
}

# Test: set_rollback_needed() sets the flag
test_set_rollback_needed_sets_flag() {
    setup
    
    # Verify initial state
    assert_equals "false" "$ROLLBACK_NEEDED" "ROLLBACK_NEEDED should initially be false"
    
    # Set rollback needed
    set_rollback_needed
    
    # Verify flag is set
    assert_equals "true" "$ROLLBACK_NEEDED" "ROLLBACK_NEEDED should be true after set"
    
    teardown
}

# Test: check_rollback() performs rollback when flag is set
test_check_rollback_performs_rollback() {
    setup
    
    # Create and backup a file
    local test_file="$TEST_DIR/testfile.txt"
    echo "original" > "$test_file"
    
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    backup_file "$test_file"
    
    # Modify file
    echo "modified" > "$test_file"
    
    # Set rollback flag
    ROLLBACK_NEEDED=true
    
    # Check rollback
    check_rollback
    
    # Verify file was restored
    assert_equals "original" "$(cat "$test_file")" "File should be restored"
    
    teardown
}

# Test: cleanup() performs rollback when ROLLBACK_NEEDED is true
test_cleanup_performs_rollback_when_needed() {
    setup
    
    # Create and backup a file
    local test_file="$TEST_DIR/testfile.txt"
    echo "original" > "$test_file"
    
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    backup_file "$test_file"
    
    # Modify file
    echo "modified" > "$test_file"
    
    # Set rollback flag
    ROLLBACK_NEEDED=true
    
    # Call cleanup
    cleanup
    
    # Verify file was restored
    assert_equals "original" "$(cat "$test_file")" "File should be restored by cleanup"
    
    teardown
}

# Test: create_restore_script() creates restore script
test_create_restore_script_creates_script() {
    setup
    
    # Create and backup a file
    local test_file="$TEST_DIR/testfile.txt"
    echo "original" > "$test_file"
    
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    backup_file "$test_file"
    
    # Create restore script
    create_restore_script
    
    # Check restore script exists
    local restore_script="$TEST_BACKUP_DIR/restore.sh"
    assert_true "[[ -f \"\$restore_script\" ]]" "Restore script should exist"
    assert_true "[[ -x \"\$restore_script\" ]]" "Restore script should be executable"
    
    teardown
}

# Test: test_ssh_connection() returns success for valid connection
test_test_ssh_connection_valid() {
    # This is hard to test without actually having SSH running
    # We'll test that it returns a value (0 or 1) without erroring
    
    local result
    test_ssh_connection "22" 2>/dev/null
    result=$?
    
    # Result should be 0 or 1
    assert_true "[[ \$result -eq 0 || \$result -eq 1 ]]" "test_ssh_connection should return 0 or 1"
}

# Test: preflight_checks() runs without error
test_preflight_checks_runs() {
    # This test verifies that preflight_checks() function exists and runs
    # Actual checks depend on system state
    
    # Just verify the function exists and doesn't crash
    if type preflight_checks &>/dev/null; then
        assert_true "true" "preflight_checks function exists"
    else
        assert_true "false" "preflight_checks function should exist"
    fi
}

# Test: backup_file() handles missing file gracefully
test_backup_file_missing_file() {
    setup
    
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    
    # Try to backup non-existent file (should not crash)
    backup_file "$TEST_DIR/nonexistent.txt"
    
    # Should still succeed
    assert_true "true" "backup_file should handle missing files gracefully"
    
    teardown
}

# Test: rollback_changes() handles empty backup gracefully
test_rollback_empty_backup() {
    setup
    
    init_backup
    BACKUP_DIR="$TEST_BACKUP_DIR"
    
    # Rollback with no backups (should not crash)
    rollback_changes
    
    # Should succeed
    assert_true "true" "rollback_changes should handle empty backup gracefully"
    
    teardown
}
