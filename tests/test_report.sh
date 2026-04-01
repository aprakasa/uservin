#!/bin/bash
#
# tests/test_report.sh - Tests for report.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/report.sh"

# Test: show_completion function exists and is defined
test_show_completion_function_exists() {
    assert_true "type -t show_completion | grep -q 'function'" "show_completion function should be defined"
}

# Test: execute_setup function exists and is defined
test_execute_setup_function_exists() {
    assert_true "type -t execute_setup | grep -q 'function'" "execute_setup function should be defined"
}
