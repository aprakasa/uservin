#!/bin/bash
#
# tests/test_system.sh - Tests for system.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/utils.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/wizard.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/safety.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/lib/system.sh"

# Test: update_system() function exists and is defined
test_update_system_function_exists() {
    if type update_system &>/dev/null; then
        assert_true "true" "update_system function should exist"
    else
        assert_true "false" "update_system function should exist"
    fi
}

# Test: install_packages() function exists and is defined
test_install_packages_function_exists() {
    if type install_packages &>/dev/null; then
        assert_true "true" "install_packages function should exist"
    else
        assert_true "false" "install_packages function should exist"
    fi
}

# Test: set_timezone() function exists and is defined
test_set_timezone_function_exists() {
    if type set_timezone &>/dev/null; then
        assert_true "true" "set_timezone function should exist"
    else
        assert_true "false" "set_timezone function should exist"
    fi
}

# Test: set_hostname() function exists and is defined
test_set_hostname_function_exists() {
    if type set_hostname &>/dev/null; then
        assert_true "true" "set_hostname function should exist"
    else
        assert_true "false" "set_hostname function should exist"
    fi
}

test_upgrade_openssh_function_exists() {
    if type upgrade_openssh &>/dev/null; then
        assert_true "true" "upgrade_openssh function should exist"
    else
        assert_true "false" "upgrade_openssh function should exist"
    fi
}

test_compile_openssh_from_source_function_exists() {
    if type compile_openssh_from_source &>/dev/null; then
        assert_true "true" "compile_openssh_from_source function should exist"
    else
        assert_true "false" "compile_openssh_from_source function should exist"
    fi
}

test_install_openssh_binaries_function_exists() {
    if type install_openssh_binaries &>/dev/null; then
        assert_true "true" "install_openssh_binaries function should exist"
    else
        assert_true "false" "install_openssh_binaries function should exist"
    fi
}
