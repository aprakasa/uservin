#!/bin/bash
#
# tests/test_integration.sh - Integration tests for uservin
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Test: Main script exists
test_main_script_exists() {
    assert_true "[[ -f '${SCRIPT_DIR}/uservin.sh' ]]" "Main script uservin.sh should exist"
}

# Test: Main script is executable
test_main_script_executable() {
    assert_true "[[ -x '${SCRIPT_DIR}/uservin.sh' ]]" "Main script uservin.sh should be executable"
}

# Test: All library files exist
test_all_libs_exist() {
    local required_libs=(
        "performance.sh"
        "report.sh"
        "safety.sh"
        "security.sh"
        "system.sh"
        "user.sh"
        "utils.sh"
        "wizard.sh"
    )
    
    for lib in "${required_libs[@]}"; do
        assert_true "[[ -f '${SCRIPT_DIR}/lib/${lib}' ]]" "Library $lib should exist"
    done
}

# Test: Main script is syntactically valid
test_main_script_syntax_valid() {
    assert_true "bash -n '${SCRIPT_DIR}/uservin.sh'" "Main script should have valid syntax"
}

# Test: All libraries are syntactically valid
test_all_libs_syntax_valid() {
    for lib_file in "${SCRIPT_DIR}/lib/"*.sh; do
        assert_true "bash -n '$lib_file'" "Library $(basename "$lib_file") should have valid syntax"
    done
}
