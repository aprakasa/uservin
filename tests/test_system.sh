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

test_download_openssh_deb_function_exists() {
    if type download_openssh_deb &>/dev/null; then
        assert_true "true" "download_openssh_deb function should exist"
    else
        assert_true "false" "download_openssh_deb function should exist"
    fi
}

test_get_openssh_deb_url_returns_github_release_url() {
    local url
    url=$(get_openssh_deb_url 2>/dev/null)
    if [[ "$url" == *"github.com"*"/releases/download/"*".deb" ]]; then
        assert_true "true" "get_openssh_deb_url should return a GitHub release URL ending in .deb"
    else
        assert_true "false" "get_openssh_deb_url should return a GitHub release URL ending in .deb, got: $url"
    fi
}

test_get_openssh_deb_url_includes_openssh_version() {
    local url
    url=$(get_openssh_deb_url 2>/dev/null)
    if [[ "$url" == *"openssh-"* ]]; then
        assert_true "true" "get_openssh_deb_url should include openssh- version in URL"
    else
        assert_true "false" "get_openssh_deb_url should include openssh- version, got: $url"
    fi
}

test_get_openssh_deb_url_includes_ubuntu_version() {
    local url
    url=$(get_openssh_deb_url 2>/dev/null)
    if [[ "$url" == *"ubuntu"* ]]; then
        assert_true "true" "get_openssh_deb_url should include ubuntu version in URL"
    else
        assert_true "false" "get_openssh_deb_url should include ubuntu version, got: $url"
    fi
}

test_get_openssh_deb_filename_returns_deb_name() {
    local filename
    filename=$(get_openssh_deb_filename 2>/dev/null)
    if [[ "$filename" == *".deb" ]]; then
        assert_true "true" "get_openssh_deb_filename should return a filename ending in .deb"
    else
        assert_true "false" "get_openssh_deb_filename should return .deb filename, got: $filename"
    fi
}

test_get_openssh_deb_filename_includes_arch() {
    local filename
    filename=$(get_openssh_deb_filename 2>/dev/null)
    if [[ "$filename" == *"amd64"* ]] || [[ "$filename" == *"arm64"* ]] || [[ "$filename" == *"aarch64"* ]]; then
        assert_true "true" "get_openssh_deb_filename should include architecture"
    else
        assert_true "false" "get_openssh_deb_filename should include architecture, got: $filename"
    fi
}
