#!/bin/bash
#
# uservin.sh - Main entry point for uservin
#
# Ubuntu Server Initialization Script
#

set -euo pipefail

# Script version
readonly VERSION="0.1.0"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all library files
for lib_file in "$SCRIPT_DIR"/lib/*.sh; do
    if [[ -f "$lib_file" ]]; then
        # shellcheck source=/dev/null
        source "$lib_file"
    fi
done

# Show help message
show_help() {
    cat << EOF
uservin - Ubuntu Server Initialization Tool v${VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
    --dry-run        Simulate changes without making them
    --quiet, -q      Minimal output (errors only)
    --verbose, -v    Detailed output
    --config FILE    Use custom configuration file
    --help, -h       Show this help message
    --version        Show version information

Description:
    Initializes and configures Ubuntu servers with security hardening,
    user management, system optimization, and more.

Examples:
    $(basename "$0")                    # Run with default settings
    $(basename "$0") --dry-run          # Preview changes
    $(basename "$0") --config my.cfg    # Use custom config

For more information: https://github.com/example/uservin
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --quiet|-q)
                LOG_LEVEL=0
                shift
                ;;
            --verbose|-v)
                LOG_LEVEL=2
                shift
                ;;
            --config)
                if [[ -n "${2:-}" ]]; then
                    CONFIG_FILE="$2"
                    shift 2
                else
                    echo "Error: --config requires an argument" >&2
                    exit 1
                fi
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version)
                echo "uservin version $VERSION"
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Initialize logging
    init_logging
    
    # Show banner
    print_header "uservin - Ubuntu Server Initialization"
    
    # Check if running as root
    if ! check_root; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Detect and validate Ubuntu version
    local ubuntu_version
    if ! ubuntu_version=$(detect_ubuntu_version); then
        log_error "Could not detect Ubuntu version"
        exit 1
    fi
    
    log_info "Detected Ubuntu $ubuntu_version"
    
    if ! is_ubuntu_supported; then
        log_error "Ubuntu $ubuntu_version is not supported"
        log_error "Supported versions: 20.04, 22.04, 24.04, 24.10"
        exit 1
    fi
    
    # Show dry-run mode if enabled
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "Running in DRY-RUN mode. No changes will be made."
    fi
    
    # Show system specs
    log_info "System specifications:"
    get_system_specs | while IFS= read -r line; do
        log_info "  $line"
    done
    
    # TODO: Load config if specified
    # TODO: Run initialization wizard/modules
    
    log_success "Initialization complete!"
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
