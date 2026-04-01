#!/bin/bash
#
# build.sh - Build script to bundle uservin into single executable
#
# This script concatenates all library files into uservin.sh for distribution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source directory
SRC_DIR="$SCRIPT_DIR"
LIB_DIR="$SRC_DIR/lib"

# Output file
OUTPUT_FILE="$SRC_DIR/uservin.sh"

# Temporary file for building
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

echo "Building uservin.sh..."

# Start with shebang and header
cat > "$TEMP_FILE" << 'HEADER'
#!/bin/bash
#
# uservin.sh - Ubuntu Server Initialization Tool
#
# This is a bundled single-file version. Generated automatically.
# Source: https://github.com/aprakasa/uservin
#

set -euo pipefail

# Script version
readonly VERSION="0.1.0"

# Configuration file path (can be overridden with --config)
CONFIG_FILE=""

# Logging level (0=quiet, 1=normal, 2=verbose)
LOG_LEVEL=1

# Dry run mode (true/false)
DRY_RUN=false

HEADER

# Function to process a library file - remove shebangs and source statements
process_lib_file() {
    local file="$1"
    
    python3 - "$file" << 'PYTHON_SCRIPT'
import re
import sys

file_path = sys.argv[1]

# Read entire file
with open(file_path, 'r') as f:
    lines = f.readlines()

# Patterns to match
source_pattern = re.compile(r'^\s*source\s+.*\.sh\s*"?\s*$')
shellcheck_pattern = re.compile(r'^\s*#\s*shellcheck\s')
shebang_pattern = re.compile(r'^#!/')

# State tracking
output = []
i = 0
while i < len(lines):
    line = lines[i]
    
    # Skip shebang on first line
    if i == 0 and shebang_pattern.match(line):
        i += 1
        continue
    
    # Check for source-only if block
    if re.match(r'^\s*if\s+.*then\s*$', line):
        # Found an if statement, check what it contains
        block_lines = [line]
        j = i + 1
        nested_ifs = 1
        
        while j < len(lines) and nested_ifs > 0:
            block_lines.append(lines[j])
            
            # Skip comments and empty lines for content check
            stripped = lines[j].strip()
            if stripped and not stripped.startswith('#'):
                if re.match(r'^\s*if\s+.*then', lines[j]):
                    nested_ifs += 1
                elif re.match(r'^\s*fi\s*$', lines[j]):
                    nested_ifs -= 1
            
            j += 1
        
        # Check if block only contains source statements (besides if/fi)
        has_non_source = False
        for k in range(1, len(block_lines) - 1):  # Skip first (if) and last (fi)
            blk_line = block_lines[k].strip()
            if blk_line and not blk_line.startswith('#'):
                if not source_pattern.match(block_lines[k]) and not shellcheck_pattern.match(block_lines[k]):
                    has_non_source = True
                    break
        
        if not has_non_source:
            # Skip this entire block
            i = j
            continue
    
    # Skip standalone source statements and shellcheck directives
    if source_pattern.match(line) or shellcheck_pattern.match(line):
        i += 1
        continue
    
    output.append(line)
    i += 1

# Write output
sys.stdout.writelines(output)
PYTHON_SCRIPT
}

# Add library files in dependency order
echo "# =========================================================" >> "$TEMP_FILE"
echo "# Bundled Library Files" >> "$TEMP_FILE"
echo "# =========================================================" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

# Order matters: utils first, then others
lib_files=(
    "utils.sh"
    "safety.sh"
    "wizard.sh"
    "system.sh"
    "security.sh"
    "user.sh"
    "performance.sh"
    "report.sh"
)

for lib in "${lib_files[@]}"; do
    if [[ -f "$LIB_DIR/$lib" ]]; then
        echo "Adding: $lib"
        echo "" >> "$TEMP_FILE"
        echo "# =========================================================" >> "$TEMP_FILE"
        echo "# Library: $lib" >> "$TEMP_FILE"
        echo "# =========================================================" >> "$TEMP_FILE"
        echo "" >> "$TEMP_FILE"
        process_lib_file "$LIB_DIR/$lib" >> "$TEMP_FILE"
    else
        echo "Warning: $lib not found" >&2
    fi
done

# Add main entry point logic
echo "" >> "$TEMP_FILE"
echo "# =========================================================" >> "$TEMP_FILE"
echo "# Main Entry Point" >> "$TEMP_FILE"
echo "# =========================================================" >> "$TEMP_FILE"
echo "" >> "$TEMP_FILE"

# Add the main script content (without the lib sourcing loop)
cat >> "$TEMP_FILE" << 'MAIN'
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

One-liner install:
    wget -qO- https://raw.githubusercontent.com/aprakasa/uservin/main/uservin.sh | sudo bash

For more information: https://github.com/aprakasa/uservin
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
    
    # Run preflight checks
    if ! run_preflight; then
        log_error "Preflight checks failed. Aborting."
        exit 1
    fi
    
    # Show welcome and run wizard
    show_welcome
    run_wizard
    
    # Execute the setup
    if ! execute_setup; then
        log_error "Setup failed. Check logs for details."
        exit 1
    fi
    
    # Show completion report
    show_completion
    
    log_success "Initialization complete!"
}

# Run main function if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
MAIN

# Replace the output file
mv "$TEMP_FILE" "$OUTPUT_FILE"
chmod +x "$OUTPUT_FILE"

echo ""
echo "Build complete: $OUTPUT_FILE"
echo ""
echo "Usage:"
echo "  Local:     ./uservin.sh"
echo "  Remote:    wget -qO- https://raw.githubusercontent.com/aprakasa/uservin/main/uservin.sh | sudo bash"
