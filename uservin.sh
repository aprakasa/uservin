#!/bin/bash
#
# uservin.sh - Ubuntu Server Initialization Tool
#
# This is a bundled single-file version. Generated automatically.
# Source: https://github.com/aprakasa/uservin
#

set -euo pipefail

# Script version
readonly SCRIPT_VERSION="1.0.2"

# Configuration file path (can be overridden with --config)
CONFIG_FILE=""

# Logging level (0=quiet, 1=normal, 2=verbose)
LOG_LEVEL=1

# Dry run mode (true/false)
DRY_RUN=false

# Background execution flag
NO_BACKGROUND=false

# =========================================================
# Bundled Library Files
# =========================================================


# =========================================================
# Library: utils.sh
# =========================================================

#
# lib/utils.sh - Shared utilities for uservin
#

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Configuration defaults
LOG_LEVEL=1
DRY_RUN=false
LOG_FILE=""
CONFIG_FILE=""

# Check if a command exists
cmd_exists() {
    command -v "$1" &>/dev/null
}

# Validate port number (1-65535)
validate_port() {
    local port="$1"
    
    # Check if empty
    [[ -z "$port" ]] && return 1
    
    # Check if it's a number
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        # Check range
        if [[ $port -ge 1 && $port -le 65535 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Validate SSH key format
validate_ssh_key() {
    local key="$1"
    
    # Check if empty
    [[ -z "$key" ]] && return 1
    
    # Check if it starts with a valid key type
    if [[ "$key" =~ ^(ssh-rsa|ssh-ed25519|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ]]; then
        return 0
    fi
    
    return 1
}

# Validate hostname format (simple or FQDN)
validate_hostname() {
    local hostname="$1"
    
    [[ -z "$hostname" ]] && return 1
    
    [[ "$hostname" =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?)*$ ]]
}

# Validate username format (lowercase, 1-32 chars, starts with letter)
validate_username() {
    local username="$1"
    
    [[ -z "$username" ]] && return 1
    
    [[ "$username" =~ ^[a-z][-a-z0-9_]*$ ]] && [[ ${#username} -le 32 ]]
}

# Initialize logging
init_logging() {
    if [[ -n "$LOG_FILE" ]]; then
        >"$LOG_FILE"
        chmod 600 "$LOG_FILE"
    fi
}

# Log raw message to file (if LOG_FILE is set)
log_raw() {
    local level="$1"
    local message="$2"
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    fi
}

# Log error (level 0)
log_error() {
    local message="$1"
    log_raw "ERROR" "$message"
    echo -e "${RED}[ERROR]${NC} $message"
}

# Log warning (level 1)
log_warn() {
    local message="$1"
    log_raw "WARN" "$message"
    if [[ $LOG_LEVEL -ge 1 ]]; then
        echo -e "${YELLOW}[WARN]${NC} $message"
    fi
}

# Log info (level 1)
log_info() {
    local message="$1"
    log_raw "INFO" "$message"
    if [[ $LOG_LEVEL -ge 1 ]]; then
        echo -e "${GREEN}[INFO]${NC} $message"
    fi
}

# Log success (level 1)
log_success() {
    local message="$1"
    log_raw "SUCCESS" "$message"
    if [[ $LOG_LEVEL -ge 1 ]]; then
        echo -e "${GREEN}[✓]${NC} $message"
    fi
}

# Log verbose (level 2)
log_verbose() {
    local message="$1"
    log_raw "VERBOSE" "$message"
    if [[ $LOG_LEVEL -ge 2 ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $message"
    fi
}

# Print section header
print_header() {
    local message="$1"
    echo -e "\n${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $message${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print step indicator
print_step() {
    local number="$1"
    local message="$2"
    echo -e "\n${CYAN}${BOLD}Step $number:${NC} $message"
}

# Check if running as root
check_root() {
    [[ $EUID -eq 0 ]]
}

# Execute command with logging and dry-run support
execute_cmd() {
    local cmd="$1"
    local description="${2:-$cmd}"
    
    log_verbose "Executing: $description"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $description"
        return 0
    fi
    
    if eval "$cmd"; then
        log_verbose "Successfully executed: $description"
        return 0
    else
        log_error "Failed to execute: $description"
        return 1
    fi
}

# Get user input with default value
prompt_input() {
    local prompt="$1"
    local default="${2:-}"
    local result
    
    if [[ -n "$default" ]]; then
        read -r -p "$prompt [$default]: " result
        result="${result:-$default}"
    else
        read -r -p "$prompt: " result
    fi
    
    echo "$result"
}

# Prompt yes/no with default
prompt_yesno() {
    local prompt="$1"
    local default="${2:-n}"
    local result
    
    local prompt_text="$prompt"
    case "$default" in
        y|Y) prompt_text="$prompt_text [Y/n]: " ;;
        n|N) prompt_text="$prompt_text [y/N]: " ;;
        *) prompt_text="$prompt_text [y/n]: " ;;
    esac
    
    read -r -p "$prompt_text" result
    result="${result:-$default}"
    
    case "$result" in
        y|Y|yes|Yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

# Detect Ubuntu version
detect_ubuntu_version() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            echo "$VERSION_ID"
            return 0
        fi
    fi
    echo ""
    return 1
}

# Check if Ubuntu version is supported
is_ubuntu_supported() {
    local version
    version=$(detect_ubuntu_version)
    
    case "$version" in
        "20.04"|"22.04"|"24.04"|"24.10") return 0 ;;
        *) return 1 ;;
    esac
}

# Get total system memory in GB
get_mem_gb() {
    if [[ -f /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo $((mem_kb / 1024 / 1024))
    else
        echo "0"
    fi
}

# Get system specifications
get_system_specs() {
    local specs=""
    
    # CPU cores
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")
    specs+="CPU: ${cpu_cores} cores\n"
    
    # Memory
    local mem_gb
    mem_gb=$(get_mem_gb)
    if [[ "$mem_gb" -eq 0 ]]; then
        mem_gb="Unknown"
    fi
    specs+="RAM: ${mem_gb}GB\n"
    
    # Disk space
    local disk_gb
    disk_gb=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
    specs+="Disk: ${disk_gb}GB available"
    
    echo -e "$specs"
}

# =========================================================
# Library: background.sh
# =========================================================



LOG_FILE="${LOG_FILE:-}"
STATUS_FILE="${STATUS_FILE:-}"
PID_FILE="${PID_FILE:-}"
NO_BACKGROUND="${NO_BACKGROUND:-false}"

is_interactive_terminal() {
    [[ -t 0 ]] && [[ -t 1 ]] && [[ -t 2 ]]
}

is_backgrounded() {
    local ppid
    ppid=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
    [[ "$ppid" -eq 1 ]]
}

get_log_dir() {
    local log_dir="/var/log/uservin"
    if mkdir -p "$log_dir" 2>/dev/null; then
        echo "$log_dir"
    else
        local fallback="/tmp/uservin-logs"
        mkdir -p "$fallback"
        echo "$fallback"
    fi
}

get_run_id() {
    echo "$(date '+%Y%m%d-%H%M%S')-$$"
}

set_run_paths() {
    if [[ -n "$LOG_FILE" ]]; then
        return 0
    fi
    local log_dir
    log_dir=$(get_log_dir)
    local run_id
    run_id=$(get_run_id)
    LOG_FILE="${log_dir}/uservin-${run_id}.log"
    STATUS_FILE="${log_dir}/status-${run_id}.json"
    PID_FILE="${log_dir}/uservin-${run_id}.pid"
}

update_status() {
    local status="$1"
    local message="${2:-}"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    if [[ -z "$STATUS_FILE" ]]; then
        set_run_paths
    fi

    message="${message//\\/\\\\}"
    message="${message//\"/\\\"}"

    printf '{\n  "status": "%s",\n  "timestamp": "%s",\n  "message": "%s",\n  "pid": %s\n}\n' \
        "$status" "$timestamp" "$message" "$$" > "$STATUS_FILE"
}

fork_to_background() {
    set_run_paths
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir" 2>/dev/null || {
        log_error "Cannot create log directory: $log_dir"
        return 1
    }

    echo "uservin is now running in background."
    echo ""
    echo "Log file: $LOG_FILE"
    echo "Status file: $STATUS_FILE"
    echo ""
    echo "Check progress with:"
    echo "  tail -f $LOG_FILE"
    echo ""
    echo "Check status with:"
    echo "  $0 --status"

    NO_BACKGROUND=true \
    LOG_FILE="$LOG_FILE" \
    STATUS_FILE="$STATUS_FILE" \
    PID_FILE="$PID_FILE" \
    nohup "$0" "$@" >> "$LOG_FILE" 2>&1 &

    local bg_pid=$!
    echo "$bg_pid" > "$PID_FILE"

    update_status "running" "Script started in background (PID: $bg_pid)"

    exit 0
}

should_auto_background() {
    [[ "$NO_BACKGROUND" != "true" ]] && [[ "$DRY_RUN" != "true" ]] && is_interactive_terminal
}

setup_background_execution() {
    if should_auto_background; then
        fork_to_background "$@"
    fi
}

get_latest_status_file() {
    local log_dir
    log_dir=$(get_log_dir)
    local latest
    latest=$(ls -t "$log_dir"/status-*.json 2>/dev/null | head -1)
    echo "${latest:-}"
}

get_latest_log_file() {
    local log_dir
    log_dir=$(get_log_dir)
    local latest
    latest=$(ls -t "$log_dir"/uservin-*.log 2>/dev/null | head -1)
    echo "${latest:-}"
}

show_status() {
    local status_file
    status_file=$(get_latest_status_file)
    local log_file
    log_file=$(get_latest_log_file)

    if [[ -z "$status_file" ]] || [[ ! -f "$status_file" ]]; then
        echo "No uservin runs found."
        echo ""
        echo "To start a new setup:"
        echo "  sudo $0"
        return 1
    fi

    local status="" timestamp="" message="" pid=""
    while IFS= read -r line; do
        case "$line" in
            *'"status"'*) status=$(echo "$line" | sed 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') ;;
            *'"timestamp"'*) timestamp=$(echo "$line" | sed 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') ;;
            *'"message"'*) message=$(echo "$line" | sed 's/.*"message"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') ;;
            *'"pid"'*) pid=$(echo "$line" | grep -oE '[0-9]+' | head -1) ;;
        esac
    done < "$status_file"

    local run_id
    run_id=$(basename "$status_file" | sed 's/status-//;s/\.json//')

    echo "========================================"
    echo "   uservin Status"
    echo "========================================"
    echo ""
    echo "Run: $run_id"
    echo "Status: $status"
    echo "Started: $timestamp"
    [[ -n "$message" ]] && echo "Message: $message"
    [[ -n "$pid" ]] && echo "PID: $pid"
    echo ""

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "Process is currently running."
    elif [[ "$status" == "running" ]]; then
        echo "Process not found (may have crashed)."
    fi

    echo ""
    echo "Log file: $log_file"
    echo ""
    echo "View log:"
    echo "  tail -f $log_file"
}

# =========================================================
# Library: safety.sh
# =========================================================

#
# lib/safety.sh - Safety checks and rollback functionality
#

# Source utils if not already sourced

# Safety module variables
BACKUP_DIR=""                    # Backup directory path
BACKUP_FILES=()                  # Array of backed up files (format: "original|backup")
ROLLBACK_NEEDED=false            # Flag for rollback on error
NONCRITICAL_DEPTH=0              # Depth counter for noncritical() wrapper

# Initialize backup directory with timestamp
init_backup() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="/root/uservin-backups/${timestamp}"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_verbose "Initialized backup directory: $BACKUP_DIR"
    else
        log_verbose "[DRY-RUN] Would create backup directory: $BACKUP_DIR"
    fi
}

# Backup a file before modification
# Arguments:
#   $1 - Path to file to backup
backup_file() {
    local file="$1"
    
    # Skip if dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log_verbose "[DRY-RUN] Would backup: $file"
        return 0
    fi
    
    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_warn "Cannot backup non-existent file: $file"
        return 0
    fi

    # Reject symlinks to prevent symlink-based attacks
    if [[ -L "$file" ]]; then
        log_warn "Skipping symlink backup: $file"
        return 0
    fi
    
    # Check if backup directory is initialized
    if [[ -z "$BACKUP_DIR" ]]; then
        init_backup
    fi
    
    # Get filename from path
    local filename
    filename=$(basename "$file")
    local backup_path="$BACKUP_DIR/$filename"
    
    # Handle duplicates by adding .backup.N extension
    local counter=1
    while [[ -f "$backup_path" ]]; do
        backup_path="$BACKUP_DIR/${filename}.backup.${counter}"
        ((counter++))
    done
    
    # Verify backup destination is not a symlink (possible attack)
    if [[ -L "$backup_path" ]]; then
        log_error "Backup destination is a symlink (possible attack): $backup_path"
        return 1
    fi

    # Copy file to backup
    if cp "$file" "$backup_path"; then
        BACKUP_FILES+=("$file|$backup_path")
        log_verbose "Backed up: $file → $backup_path"
        return 0
    else
        log_error "Failed to backup: $file"
        return 1
    fi
}

# Create a restore script in the backup directory
create_restore_script() {
    if [[ -z "$BACKUP_DIR" ]] || [[ ! -d "$BACKUP_DIR" ]]; then
        log_warn "Cannot create restore script: backup directory not initialized"
        return 1
    fi
    
    local restore_script="$BACKUP_DIR/restore.sh"
    
    # Start creating the restore script
    cat > "$restore_script" << 'EOF'
#!/bin/bash
#
# restore.sh - Auto-generated restore script
# Created by uservin backup system
#

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Restore a single file
restore_file() {
    local original="$1"
    local backup="$2"
    
    if [[ ! -f "$backup" ]]; then
        echo -e "${RED}✗${NC} Backup not found: $backup"
        return 1
    fi
    
    # Create parent directory if needed
    local parent_dir
    parent_dir=$(dirname "$original")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi
    
    if cp "$backup" "$original"; then
        echo -e "${GREEN}✓${NC} Restored: $original"
        return 0
    else
        echo -e "${RED}✗${NC} Failed to restore: $original"
        return 1
    fi
}

EOF

    # Add restore commands for each backed up file
    local entry
    for entry in "${BACKUP_FILES[@]}"; do
        local original="${entry%|*}"
        local backup="${entry#*|}"
        echo "restore_file \"$original\" \"${backup#$BACKUP_DIR/}\"" >> "$restore_script"
    done
    
    # Add summary at the end
    cat >> "$restore_script" << 'EOF'

echo ""
echo "Restore completed!"
EOF

    # Make it executable
    chmod +x "$restore_script"
    log_verbose "Created restore script: $restore_script"
}

# Rollback all changes from backup
rollback_changes() {
    if [[ ${#BACKUP_FILES[@]} -eq 0 ]]; then
        log_verbose "No files to rollback"
        return 0
    fi
    
    log_warn "Rolling back changes..."
    
    local success_count=0
    local fail_count=0
    local entry
    
    # Process in reverse order to restore in correct order
    for ((i=${#BACKUP_FILES[@]}-1; i>=0; i--)); do
        entry="${BACKUP_FILES[$i]}"
        local original="${entry%|*}"
        local backup="${entry#*|}"
        
        if [[ -f "$backup" ]]; then
            # Create parent directory if needed
            local parent_dir
            parent_dir=$(dirname "$original")
            if [[ ! -d "$parent_dir" ]]; then
                mkdir -p "$parent_dir"
            fi
            
            if cp "$backup" "$original"; then
                log_verbose "Restored: $original"
                ((success_count++))
            else
                log_error "Failed to restore: $original"
                ((fail_count++))
            fi
        else
            log_warn "Backup not found: $backup"
            ((fail_count++))
        fi
    done
    
    log_info "Rollback complete: $success_count restored, $fail_count failed"
    
    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Test SSH connection on given port
test_ssh_connection() {
    local port="${1:-22}"
    
    # Try to connect to localhost on the given port
    # Use timeout to avoid hanging
    if timeout 5 bash -c "echo '' > /dev/tcp/127.0.0.1/$port" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Comprehensive pre-flight checks
preflight_checks() {
    local has_errors=false
    
    print_header "Pre-flight Checks"
    
    # Check 1: Root privileges
    print_step "1" "Checking root privileges"
    if check_root; then
        log_success "Running as root"
    else
        log_error "Must run as root (use sudo)"
        has_errors=true
    fi
    
    # Check 2: Ubuntu version
    print_step "2" "Checking Ubuntu version"
    local ubuntu_version
    ubuntu_version=$(detect_ubuntu_version)
    if [[ -n "$ubuntu_version" ]]; then
        log_info "Ubuntu version: $ubuntu_version"
        if is_ubuntu_supported; then
            log_success "Ubuntu version is supported"
        else
            log_warn "Ubuntu $ubuntu_version may not be fully supported (tested on 20.04, 22.04, 24.04, 24.10)"
        fi
    else
        log_warn "Could not detect Ubuntu version"
    fi
    
    # Check 3: Internet connectivity
    print_step "3" "Checking internet connectivity"
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 || \
       ping -c 1 -W 5 google.com >/dev/null 2>&1; then
        log_success "Internet connectivity confirmed"
    else
        log_warn "No internet connectivity detected"
    fi
    
    # Check 4: Disk space (need at least 1GB)
    print_step "4" "Checking disk space"
    local available_gb
    available_gb=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
    if [[ $available_gb -ge 1 ]]; then
        log_success "Disk space: ${available_gb}GB available (minimum 1GB)"
    else
        log_error "Insufficient disk space: ${available_gb}GB available (need at least 1GB)"
        has_errors=true
    fi
    
    # Check 5: SSH session warning
    print_step "5" "Checking SSH session"
    if [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]]; then
        log_warn "Connected via SSH - be careful not to lock yourself out!"
        log_warn "Ensure you have console access or alternative connection method"
    else
        log_info "Not connected via SSH"
    fi
    
    # Check 6: Essential commands
    print_step "6" "Checking essential commands"
    local missing_cmds=()
    for cmd in cp mv mkdir rm chmod chown; do
        if ! cmd_exists "$cmd"; then
            missing_cmds+=("$cmd")
        fi
    done
    
    if [[ ${#missing_cmds[@]} -eq 0 ]]; then
        log_success "All essential commands available"
    else
        log_error "Missing essential commands: ${missing_cmds[*]}"
        has_errors=true
    fi
    
    if [[ "$has_errors" == "true" ]]; then
        log_error "Pre-flight checks failed - please fix the issues above"
        return 1
    fi
    
    log_success "All pre-flight checks passed"
    return 0
}

# Set rollback needed flag
set_rollback_needed() {
    ROLLBACK_NEEDED=true
    log_verbose "Rollback flag set - changes will be rolled back on exit"
}

# Check if rollback is needed and perform it
check_rollback() {
    if [[ "$ROLLBACK_NEEDED" == "true" ]]; then
        rollback_changes
    fi
}

# Cleanup function called on exit
cleanup() {
    # Check and perform rollback if needed
    check_rollback
    
    # Create restore script if there are backups
    if [[ ${#BACKUP_FILES[@]} -gt 0 ]] && [[ -n "$BACKUP_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
        create_restore_script
    fi
    
    log_verbose "Cleanup complete"
}

# Register traps
trap cleanup EXIT

_err_handler() {
    if [[ $NONCRITICAL_DEPTH -eq 0 ]]; then
        set_rollback_needed
    fi
}

trap '_err_handler' ERR

noncritical() {
    ((NONCRITICAL_DEPTH++))
    "$@"
    local rc=$?
    ((NONCRITICAL_DEPTH--)) || true
    return $rc
}

# =========================================================
# Library: wizard.sh
# =========================================================

#
# lib/wizard.sh - Interactive configuration wizard
#

# Global configuration variables (set by run_wizard)
CONFIG_HOSTNAME=""
CONFIG_TIMEZONE=""
CONFIG_USERNAME=""
CONFIG_SSH_PORT=""
CONFIG_SSH_KEY=""
CONFIG_ENABLE_AUTO_UPDATES=""
CONFIG_ENABLE_SWAP=""
CONFIG_ENABLE_ZRAM=""

# Get configuration value by key
# Arguments:
#   $1 - Configuration key (hostname, timezone, username, ssh_port, ssh_key,
#                           auto_updates, enable_swap, enable_zram)
# Returns: The configuration value, or empty string if key not found
get_config() {
    local key="$1"
    
    case "$key" in
        hostname)
            echo "$CONFIG_HOSTNAME"
            ;;
        timezone)
            echo "$CONFIG_TIMEZONE"
            ;;
        username)
            echo "$CONFIG_USERNAME"
            ;;
        ssh_port)
            echo "$CONFIG_SSH_PORT"
            ;;
        ssh_key)
            echo "$CONFIG_SSH_KEY"
            ;;
        auto_updates)
            echo "$CONFIG_ENABLE_AUTO_UPDATES"
            ;;
        enable_swap)
            echo "$CONFIG_ENABLE_SWAP"
            ;;
        enable_zram)
            echo "$CONFIG_ENABLE_ZRAM"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Show welcome banner with ASCII art and feature list
show_welcome() {
    echo -e "${CYAN}"
    echo -e '                           _       '
    echo -e '  _   _ ___  ___ _ ____   _(_)_ __  '
    echo -e ' | | | / __|/ _ \ '"'"'__\ \ / / | '"'"'_ \ '
    echo -e ' | |_| \__ \  __/ |   \ V /| | | | |'
    echo -e '  \__,_|___/\___|_|    \_/ |_|_| |_|'
    echo -e "${NC}"
    echo -e "${BOLD}Ubuntu Server Provisioning Wizard${NC}"
    echo ""
    echo -e "${CYAN}Features:${NC}"
    echo "  • System configuration (hostname, timezone)"
    echo "  • User setup with SSH key authentication"
    echo "  • SSH hardening (custom port, key-only auth)"
    echo "  • Firewall configuration (UFW)"
    echo "  • Automatic security updates"
    echo "  • Swap and Zram optimization"
    echo ""
    
    if prompt_yesno "Continue with configuration?" "y"; then
        return 0
    else
        log_info "Configuration cancelled by user"
        exit 0
    fi
}

# Run the interactive configuration wizard
run_wizard() {
    log_info "Starting configuration wizard..."
    
    # Step 1: Hostname
    local current_hostname
    current_hostname=$(hostname 2>/dev/null || echo "ubuntu-server")
    while true; do
        CONFIG_HOSTNAME=$(prompt_input "Enter hostname" "$current_hostname")
        if validate_hostname "$CONFIG_HOSTNAME"; then
            break
        fi
        log_error "Invalid hostname. Use alphanumeric characters, hyphens, and dots (for FQDNs)."
    done
    log_success "Hostname set to: $CONFIG_HOSTNAME"
    
    # Step 2: Timezone
    local current_timezone
    if [[ -f /etc/timezone ]]; then
        current_timezone=$(cat /etc/timezone)
    elif cmd_exists timedatectl; then
        current_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "")
    fi
    current_timezone="${current_timezone:-UTC}"
    CONFIG_TIMEZONE=$(prompt_input "Enter timezone" "$current_timezone")
    log_success "Timezone set to: $CONFIG_TIMEZONE"
    
    # Step 3: Admin username
    while true; do
        CONFIG_USERNAME=$(prompt_input "Enter admin username" "admin")
        if validate_username "$CONFIG_USERNAME"; then
            break
        fi
        log_error "Invalid username. Must start with lowercase letter, use lowercase letters, numbers, hyphens, or underscores only (1-32 chars)."
    done
    log_success "Username set to: $CONFIG_USERNAME"
    
    # Step 4: SSH port
    while true; do
        CONFIG_SSH_PORT=$(prompt_input "Enter SSH port" "22")
        if validate_port "$CONFIG_SSH_PORT"; then
            break
        fi
        log_error "Invalid port. Must be a number between 1 and 65535."
    done
    log_success "SSH port set to: $CONFIG_SSH_PORT"
    
    # Step 5: SSH public key
    while true; do
        CONFIG_SSH_KEY=$(prompt_input "Enter SSH public key" "")
        if validate_ssh_key "$CONFIG_SSH_KEY"; then
            break
        fi
        log_error "Invalid SSH key. Must start with ssh-rsa, ssh-ed25519, ssh-dss, or ecdsa-sha2-nistp*."
    done
    log_success "SSH key configured"
    
    # Step 6: Automatic updates
    if prompt_yesno "Enable automatic security updates?" "y"; then
        CONFIG_ENABLE_AUTO_UPDATES="true"
        log_success "Automatic updates enabled"
    else
        CONFIG_ENABLE_AUTO_UPDATES="false"
        log_info "Automatic updates disabled"
    fi
    
    # Step 7: Swap/Zram configuration (auto-detect based on RAM)
    local mem_gb
    mem_gb=$(get_mem_gb)
    [[ "$mem_gb" -eq 0 ]] && mem_gb=4
    
    log_info "Detected ${mem_gb}GB RAM"
    
    if [[ $mem_gb -lt 4 ]]; then
        # RAM < 4GB: enable both zram and swap
        CONFIG_ENABLE_ZRAM="true"
        CONFIG_ENABLE_SWAP="true"
        log_info "Low memory system detected - enabling both Zram and Swap"
    elif [[ $mem_gb -ge 4 && $mem_gb -lt 8 ]]; then
        # RAM 4-8GB: enable zram only
        CONFIG_ENABLE_ZRAM="true"
        CONFIG_ENABLE_SWAP="false"
        log_info "Medium memory system detected - enabling Zram only"
    else
        # RAM >= 8GB: ask user
        echo ""
        echo -e "${CYAN}Swap Configuration:${NC}"
        if prompt_yesno "Enable Zram (compressed RAM swap)?" "y"; then
            CONFIG_ENABLE_ZRAM="true"
        else
            CONFIG_ENABLE_ZRAM="false"
        fi
        
        if prompt_yesno "Enable traditional swap file?" "n"; then
            CONFIG_ENABLE_SWAP="true"
        else
            CONFIG_ENABLE_SWAP="false"
        fi
    fi
    
    if [[ "$CONFIG_ENABLE_ZRAM" == "true" ]]; then
        log_success "Zram will be enabled"
    fi
    if [[ "$CONFIG_ENABLE_SWAP" == "true" ]]; then
        log_success "Swap will be enabled"
    fi
    
    # Step 8: Show configuration summary
    echo ""
    print_header "Configuration Summary"
    echo "  Hostname:           $CONFIG_HOSTNAME"
    echo "  Timezone:           $CONFIG_TIMEZONE"
    echo "  Username:           $CONFIG_USERNAME"
    echo "  SSH Port:           $CONFIG_SSH_PORT"
    echo "  SSH Key:            ${CONFIG_SSH_KEY:0:50}..."
    echo "  Auto Updates:       $CONFIG_ENABLE_AUTO_UPDATES"
    echo "  Zram:               $CONFIG_ENABLE_ZRAM"
    echo "  Swap:               $CONFIG_ENABLE_SWAP"
    echo ""
    
    # Step 9: Confirm to proceed
    if prompt_yesno "Proceed with configuration?" "y"; then
        log_success "Configuration complete!"
        return 0
    else
        log_info "Configuration cancelled by user"
        exit 0
    fi
}

# Load configuration from INI file
# Arguments:
#   CONFIG_FILE - Global variable with path to config file
# Returns: 0 on success, 1 on failure
load_config_file() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
    
    log_info "Parsing configuration file: $CONFIG_FILE"
    
    # Parse the INI file
    local known_sections="system user ssh security updates performance"
    local known_keys="system:hostname system:timezone user:username user:ssh_key ssh:port security:enable_ufw security:enable_fail2ban updates:auto_updates performance:swap_size performance:enable_zram performance:enable_bbr"
    local section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip inline comments (space + #) but preserve values containing #
        line=$(echo "$line" | sed 's/[[:space:]]#[^"]*$//')
        # Skip empty lines
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Check for section header
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            case "$section" in
                system|user|ssh|security|updates|performance) ;;
                *) log_warn "  Unknown config section: [$section] (ignored)" ;;
            esac
            continue
        fi
        
        # Parse key=value pairs
        if [[ "$line" =~ ^[[:space:]]*([^=]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Trim whitespace and remove trailing newlines
            key=$(echo -n "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo -n "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            
            # Map configuration values
            local full_key="$section:$key"
            case "$full_key" in
                "system:hostname")
                    CONFIG_HOSTNAME="$value"
                    log_info "  Hostname: $value"
                    ;;
                "system:timezone")
                    CONFIG_TIMEZONE="$value"
                    log_info "  Timezone: $value"
                    ;;
                "user:username")
                    CONFIG_USERNAME="$value"
                    log_info "  Username: $value"
                    ;;
                "user:ssh_key")
                    CONFIG_SSH_KEY="$value"
                    log_info "  SSH key configured"
                    ;;
                "ssh:port")
                    CONFIG_SSH_PORT="$value"
                    log_info "  SSH Port: $value"
                    ;;
                "security:enable_ufw")
                    [[ "$value" == "true" ]] && log_info "  UFW: enabled"
                    ;;
                "security:enable_fail2ban")
                    [[ "$value" == "true" ]] && log_info "  Fail2ban: enabled"
                    ;;
                "updates:auto_updates")
                    CONFIG_ENABLE_AUTO_UPDATES="$value"
                    log_info "  Auto updates: $value"
                    ;;
                "performance:swap_size")
                    CONFIG_ENABLE_SWAP="true"
                    log_info "  Swap: enabled"
                    ;;
                "performance:enable_zram")
                    CONFIG_ENABLE_ZRAM="$value"
                    log_info "  Zram: $value"
                    ;;
                "performance:enable_bbr")
                    [[ "$value" == "true" ]] && log_info "  BBR: enabled"
                    ;;
                *)
                    log_warn "  Unknown config key: [$section] $key (ignored)"
                    ;;
            esac
        fi
    done < "$CONFIG_FILE"
    
    # Validate required fields
    if [[ -z "$CONFIG_HOSTNAME" ]]; then
        log_error "Missing required configuration: system.hostname"
        return 1
    fi
    
    if [[ -z "$CONFIG_USERNAME" ]]; then
        log_error "Missing required configuration: user.username"
        return 1
    fi
    
    if [[ -z "$CONFIG_SSH_KEY" ]]; then
        log_error "Missing required configuration: user.ssh_key"
        return 1
    fi
    
    # Set defaults for optional fields
    [[ -z "$CONFIG_TIMEZONE" ]] && CONFIG_TIMEZONE="UTC"
    [[ -z "$CONFIG_SSH_PORT" ]] && CONFIG_SSH_PORT="22"
    [[ -z "$CONFIG_ENABLE_AUTO_UPDATES" ]] && CONFIG_ENABLE_AUTO_UPDATES="true"
    [[ -z "$CONFIG_ENABLE_ZRAM" ]] && CONFIG_ENABLE_ZRAM="true"
    [[ -z "$CONFIG_ENABLE_SWAP" ]] && CONFIG_ENABLE_SWAP="true"
    
    # Validate config values
    if ! validate_hostname "$CONFIG_HOSTNAME"; then
        log_error "Invalid hostname in config: $CONFIG_HOSTNAME"
        return 1
    fi
    
    if ! validate_username "$CONFIG_USERNAME"; then
        log_error "Invalid username in config: $CONFIG_USERNAME"
        return 1
    fi
    
    if ! validate_port "$CONFIG_SSH_PORT"; then
        log_error "Invalid SSH port in config: $CONFIG_SSH_PORT"
        return 1
    fi
    
    if ! validate_ssh_key "$CONFIG_SSH_KEY"; then
        log_error "Invalid SSH key in config"
        return 1
    fi
    
    if [[ -n "$CONFIG_TIMEZONE" ]] && ! timedatectl list-timezones 2>/dev/null | grep -q "^${CONFIG_TIMEZONE}$"; then
        log_error "Invalid timezone in config: $CONFIG_TIMEZONE"
        return 1
    fi
    
    log_success "Configuration loaded successfully"
    return 0
}

# =========================================================
# Library: system.sh
# =========================================================

#
# lib/system.sh - System configuration functions
#

# Source dependencies

# OpenSSH target version for source compile
readonly OPENSSH_TARGET_VERSION="9.9p1"
readonly OPENSSH_SHA256="b343fbcdbff87f15b1986e6e15d6d4fc9a7d36066be6b7fb507087ba8f966c02"

# GitHub repo for pre-built OpenSSH .deb packages
readonly OPENSSH_DEB_REPO="aprakasa/uservin"
readonly OPENSSH_DEB_SHA256="b5a0e82cae8b3dfc7f134a1e6f4c6ff9e4c00e44a4b87a8ed3e1f6f0a5c7d9e1"

# update_system() - Update system packages
# Performs full system update including:
# - apt-get update
# - apt-get dist-upgrade
# - apt-get autoremove --purge
# - apt-get clean
update_system() {
    log_info "Updating system packages..."
    print_header "System Update"
    
    # Set non-interactive mode for unattended operation
    export DEBIAN_FRONTEND=noninteractive

    log_info "Configuring DNS resolvers..."
    if [[ ! -f /etc/resolv.conf.bak ]]; then
        cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
    fi
    cat > /etc/resolv.conf << 'DNS'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 2001:4860:4860::8888
DNS
    log_success "DNS set to Cloudflare (1.1.1.1) and Google (8.8.8.8)"

    log_info "Cleaning package cache..."
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin 2>/dev/null
    apt-get clean -qq 2>/dev/null || true

    log_info "Running apt-get update..."
    local _update_ok=false
    for _attempt in 1 2 3; do
        if execute_cmd "apt-get update -qq -o Acquire::Retries=3" "apt-get update (attempt ${_attempt}/3)"; then
            _update_ok=true
            break
        fi
        if [[ "$_attempt" -lt 3 ]]; then
            local _wait=$(( _attempt * 10 ))
            log_warn "apt-get update attempt ${_attempt} failed, retrying in ${_wait}s..."
            sleep "$_wait"
            rm -rf /var/lib/apt/lists/partial 2>/dev/null
        fi
    done
    if [[ "$_update_ok" != "true" ]]; then
        log_warn "apt-get update had errors, attempting to continue..."
    fi
    
    log_info "Running apt-get dist-upgrade..."
    local _dist_ok=false
    for _attempt in 1 2 3; do
        if execute_cmd "apt-get dist-upgrade -y -qq --fix-missing -o Dpkg::Options::='--force-confdef' -o Dpkg::Options::='--force-confold'" "apt-get dist-upgrade (attempt ${_attempt}/3)"; then
            _dist_ok=true
            break
        fi
        if [[ "$_attempt" -lt 3 ]]; then
            local _wait=$(( _attempt * 15 ))
            log_warn "dist-upgrade attempt ${_attempt} failed, retrying in ${_wait}s..."
            sleep "$_wait"
            apt-get update -qq 2>/dev/null || true
        fi
    done
    if [[ "$_dist_ok" != "true" ]]; then
        log_error "Failed to upgrade packages after 3 attempts"
        return 1
    fi
    
    log_info "Removing unnecessary packages..."
    if ! execute_cmd "apt-get autoremove --purge -y -qq" "apt-get autoremove --purge"; then
        log_warn "Failed to remove some unnecessary packages"
    fi
    
    log_info "Cleaning package cache..."
    if ! execute_cmd "apt-get clean" "apt-get clean"; then
        log_warn "Failed to clean package cache"
    fi
    
    log_success "System packages updated successfully"
    return 0
}

# install_packages() - Install essential packages
# Installs core utilities and security packages
install_packages() {
    log_info "Installing essential packages..."
    print_header "Package Installation"
    
    # Define package groups
    local core_packages="curl git unzip zip nano htop tree"
    local security_packages="ufw fail2ban"
    local auto_update_packages="unattended-upgrades apt-listchanges"
    local util_packages="bc"
    
    # Combine all packages
    local all_packages="$core_packages $security_packages $auto_update_packages $util_packages"
    
    # Check if zram-tools is available (Ubuntu 22.04+)
    if apt-cache show zram-tools &>/dev/null; then
        log_verbose "zram-tools is available, adding to install list"
        all_packages="$all_packages zram-tools"
    else
        log_verbose "zram-tools not available on this system"
    fi
    
    # Install packages using execute_cmd
    log_verbose "Installing packages: $all_packages"
    if execute_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $all_packages" "Installing essential packages"; then
        log_success "Essential packages installed successfully"
        
        # Upgrade OpenSSH to version with post-quantum support
        upgrade_openssh
        
        return 0
    else
        log_error "Failed to install some packages"
        return 1
    fi
}

upgrade_openssh() {
    log_info "Checking OpenSSH version..."
    
    local current_version
    current_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "0.0")
    
    log_info "Current OpenSSH version: $current_version"
    
    if [[ "$(printf '%s\n' "$current_version" "9.7" | sort -V | head -n1)" = "9.7" ]]; then
        log_success "OpenSSH $current_version already has post-quantum support"
        return 0
    fi
    
    log_info "OpenSSH $current_version does not support post-quantum key exchange (requires 9.7+)"
    
    local available_version
    local apt_candidate
    apt_candidate=$(apt-cache policy openssh-server 2>/dev/null | grep Candidate | awk '{print $2}')
    available_version=$(echo "$apt_candidate" | sed 's/^[0-9]*://' | grep -oP '^[0-9]+\.[0-9]+' || echo "0.0")
    
    if [[ "$(printf '%s\n' "$available_version" "$current_version" | sort -V | head -n1)" = "$available_version" ]] && [[ "$available_version" != "$current_version" ]] && [[ "$(printf '%s\n' "$available_version" "9.7" | sort -V | head -n1)" = "9.7" ]]; then
        print_header "OpenSSH Upgrade (apt)"
        log_info "Newer OpenSSH $available_version available in repos with PQ support, upgrading..."
        
        if [[ -f /etc/ssh/sshd_config ]]; then
            backup_file /etc/ssh/sshd_config
        fi
        
        if execute_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server openssh-client" "Upgrading OpenSSH via apt"; then
            local new_version
            new_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "unknown")
            log_success "OpenSSH upgraded to $new_version"
        else
            log_warn "Failed to upgrade OpenSSH via apt"
        fi
        return 0
    fi
    
    log_info "Repository doesn't have OpenSSH 9.7+, trying pre-built package"

    if [[ -f /etc/ssh/sshd_config ]]; then
        backup_file /etc/ssh/sshd_config
    fi

    if download_openssh_deb; then
        return 0
    fi

    log_info "Pre-built package not available, will compile from source"
    
    if compile_openssh_from_source; then
        if install_openssh_binaries; then
            local new_version
            new_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "unknown")
            log_success "OpenSSH upgraded to $new_version with post-quantum support"
            
            if sshd -T -o "kexalgorithms=+mlkem768x25519-sha256" 2>/dev/null | grep -q mlkem; then
                log_success "ML-KEM post-quantum key exchange confirmed available"
            elif ssh -Q kex 2>/dev/null | grep -q mlkem; then
                log_success "ML-KEM post-quantum key exchange confirmed available"
            fi
        else
            log_warn "Failed to install compiled OpenSSH binaries"
        fi
    else
        log_warn "Failed to compile OpenSSH from source"
        log_info "Post-quantum support will come through Ubuntu updates when available"
    fi
    
    return 0
}

compile_openssh_from_source() {
    local openssh_version="$OPENSSH_TARGET_VERSION"
    local tar_url="https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${openssh_version}.tar.gz"
    local expected_sha256="$OPENSSH_SHA256"
    local build_dir
    build_dir=$(mktemp -d "${TMPDIR:-/tmp}/openssh-build.XXXXXX")
    chmod 700 "$build_dir"
    local src_dir="$build_dir/openssh-${openssh_version}"

    log_info "Compiling OpenSSH $openssh_version from source..."
    print_header "OpenSSH Source Compile"

    if [[ -f "/usr/local/sbin/sshd" ]]; then
        local installed_version
        installed_version=$(/usr/local/sbin/sshd -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "0.0")
        if [[ "$installed_version" == "${openssh_version%%p*}" ]]; then
            log_success "OpenSSH $openssh_version already installed to /usr/local"
            return 0
        fi
    fi

    mkdir -p "$build_dir"

    log_verbose "Fixing any broken package state..."
    execute_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -f -y -qq" "Fixing broken dependencies"

    log_verbose "Installing build dependencies..."
    if ! execute_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential libssl-dev zlib1g-dev libpam0g-dev libkrb5-dev libedit-dev libselinux1-dev" "Installing build dependencies"; then
        log_error "Failed to install build dependencies"
        return 1
    fi

    log_verbose "Downloading OpenSSH $openssh_version..."
    if ! execute_cmd "curl -fSL -o $build_dir/openssh.tar.gz $tar_url" "Downloading OpenSSH source"; then
        log_error "Failed to download OpenSSH source"
        return 1
    fi

    log_verbose "Verifying SHA256 checksum..."
    local actual_sha256
    actual_sha256=$(sha256sum "$build_dir/openssh.tar.gz" | awk '{print $1}')
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
        log_error "SHA256 checksum mismatch for openssh-${openssh_version}.tar.gz"
        log_error "Expected: $expected_sha256"
        log_error "Got:      $actual_sha256"
        rm -f "$build_dir/openssh.tar.gz"
        return 1
    fi
    log_verbose "SHA256 checksum verified"
    
    if [[ ! -d "$src_dir" ]]; then
        log_verbose "Extracting source..."
        if ! execute_cmd "tar -xzf $build_dir/openssh.tar.gz -C $build_dir" "Extracting OpenSSH source"; then
            log_error "Failed to extract OpenSSH source"
            return 1
        fi
    else
        log_verbose "Source already extracted"
    fi
    
    if [[ ! -f "$src_dir/Makefile" ]]; then
        log_verbose "Configuring OpenSSH..."
        if ! execute_cmd "cd $src_dir && ./configure --prefix=/usr/local --with-pam --with-privsep-path=/run/sshd --with-pid-dir=/run" "Configuring OpenSSH build"; then
            log_error "Failed to configure OpenSSH"
            return 1
        fi
    else
        log_verbose "OpenSSH already configured"
    fi
    
    if [[ ! -f "$src_dir/sshd" ]]; then
        log_verbose "Compiling OpenSSH..."
        if ! execute_cmd "make -C $src_dir -j\$(nproc)" "Compiling OpenSSH (this may take a few minutes)"; then
            log_error "Failed to compile OpenSSH"
            return 1
        fi
    else
        log_verbose "OpenSSH already compiled"
    fi
    
    log_verbose "Installing to /usr/local prefix..."
    if ! execute_cmd "make -C $src_dir install" "Installing OpenSSH to /usr/local"; then
        log_error "Failed to install OpenSSH"
        return 1
    fi
    
    log_success "OpenSSH $openssh_version compiled and installed to /usr/local"
    return 0
}

install_openssh_binaries() {
    log_info "Installing compiled OpenSSH binaries to system paths..."
    
    local binaries="sshd ssh scp sftp ssh-keygen ssh-add ssh-agent ssh-keyscan"
    for binary in $binaries; do
        local src="/usr/local/sbin/$binary"
        [[ ! -f "$src" ]] && src="/usr/local/bin/$binary"
        [[ ! -f "$src" ]] && continue
        
        local dest="/usr/sbin/$binary"
        [[ "$binary" != "sshd" ]] && dest="/usr/bin/$binary"
        
        log_verbose "Installing $binary: $src -> $dest"
        install -m 755 "$src" "$dest" || log_warn "Failed to install $binary"
    done
    
    local libexec_binaries="sftp-server ssh-keysign ssh-pkcs11-helper"
    for binary in $libexec_binaries; do
        local src="/usr/local/libexec/$binary"
        local dest="/usr/lib/openssh/$binary"
        if [[ -f "$src" ]]; then
            log_verbose "Installing $binary: $src -> $dest"
            install -m 755 "$src" "$dest" || log_warn "Failed to install $binary"
        fi
    done
    
    local sshd_session="/usr/local/libexec/sshd-session"
    if [[ -f "$sshd_session" ]]; then
        log_verbose "Installing sshd-session (required by OpenSSH 9.9+)"
        mkdir -p /usr/libexec
        install -m 755 "$sshd_session" /usr/libexec/sshd-session || log_warn "Failed to install sshd-session"
    fi
    
    log_verbose "Symlinking config and host keys..."
    mkdir -p /usr/local/etc
    ln -sf /etc/ssh/sshd_config /usr/local/etc/sshd_config
    for keyfile in ssh_host_rsa_key ssh_host_ecdsa_key ssh_host_ed25519_key; do
        if [[ -f "/etc/ssh/$keyfile" ]]; then
            ln -sf "/etc/ssh/$keyfile" "/usr/local/etc/$keyfile"
        fi
    done
    
    log_verbose "Switching from ssh.socket to ssh.service..."
    disable_ssh_socket
    execute_cmd "systemctl start ssh" "Starting ssh.service"
    
    log_success "OpenSSH binaries installed to system paths"
    return 0
}

get_openssh_deb_filename() {
    local arch
    arch=$(dpkg-architecture -qDEB_BUILD_ARCH 2>/dev/null || echo "amd64")
    local ubuntu_ver
    ubuntu_ver=$(detect_ubuntu_version 2>/dev/null || echo "24.04")
    echo "openssh-${OPENSSH_TARGET_VERSION}-ubuntu${ubuntu_ver}-${arch}.deb"
}

get_openssh_deb_url() {
    local filename
    filename=$(get_openssh_deb_filename)
    local ubuntu_ver
    ubuntu_ver=$(detect_ubuntu_version 2>/dev/null || echo "24.04")
    local tag="openssh-${OPENSSH_TARGET_VERSION}-ubuntu${ubuntu_ver}"
    echo "https://github.com/${OPENSSH_DEB_REPO}/releases/download/${tag}/${filename}"
}

download_openssh_deb() {
    local deb_url
    deb_url=$(get_openssh_deb_url)
    local deb_file
    deb_file=$(get_openssh_deb_filename)
    local tmp_deb="/tmp/${deb_file}"
    local extract_dir="/tmp/openssh-deb"
    local sha256_url="${deb_url}.sha256"

    log_info "Trying pre-built OpenSSH package from GitHub Releases..."
    print_header "OpenSSH Pre-built Package"

    if ! execute_cmd "curl -fSL -o $tmp_deb $deb_url" "Downloading OpenSSH .deb package"; then
        log_verbose "Pre-built package not available at $deb_url"
        rm -f "$tmp_deb"
        return 1
    fi

    log_verbose "Verifying .deb SHA256 checksum..."
    local sha256_file="${tmp_deb}.sha256"
    if curl -fSL -o "$sha256_file" "$sha256_url" 2>/dev/null && [[ -s "$sha256_file" ]]; then
        local expected_deb_sha256
        expected_deb_sha256=$(awk '{print $1}' "$sha256_file")
        local actual_deb_sha256
        actual_deb_sha256=$(sha256sum "$tmp_deb" | awk '{print $1}')
        if [[ "$actual_deb_sha256" != "$expected_deb_sha256" ]]; then
            log_error "SHA256 checksum mismatch for $deb_file"
            log_error "Expected: $expected_deb_sha256"
            log_error "Got:      $actual_deb_sha256"
            rm -f "$tmp_deb" "$sha256_file"
            return 1
        fi
        log_verbose "SHA256 checksum verified"
    else
        log_warn "No SHA256 checksum file available for $deb_file — skipping integrity verification"
        rm -f "$sha256_file"
    fi

    log_info "Extracting OpenSSH binaries from package..."
    rm -rf "$extract_dir"
    mkdir -p "$extract_dir"

    if ! execute_cmd "dpkg-deb -x $tmp_deb $extract_dir" "Extracting .deb contents"; then
        log_error "Failed to extract .deb package"
        rm -f "$tmp_deb"
        rm -rf "$extract_dir"
        return 1
    fi

    log_info "Installing OpenSSH binaries to /usr/local..."
    for binary in sshd ssh-keysign ssh-pkcs11-helper ssh-sk-helper; do
        local src="$extract_dir/usr/sbin/$binary"
        [[ ! -f "$src" ]] && src="$extract_dir/usr/libexec/$binary"
        if [[ -f "$src" ]]; then
            install -m 755 "$src" "/usr/local/sbin/$binary" || log_warn "Failed to install $binary"
        fi
    done

    for binary in ssh scp sftp ssh-keygen ssh-add ssh-agent ssh-keyscan; do
        local src="$extract_dir/usr/bin/$binary"
        if [[ -f "$src" ]]; then
            install -m 755 "$src" "/usr/local/bin/$binary" || log_warn "Failed to install $binary"
        fi
    done

    for binary in sftp-server ssh-keysign ssh-pkcs11-helper ssh-sk-helper; do
        local src="$extract_dir/usr/libexec/$binary"
        if [[ -f "$src" ]]; then
            mkdir -p /usr/local/libexec
            install -m 755 "$src" "/usr/local/libexec/$binary" || log_warn "Failed to install $binary"
        fi
    done

    local sshd_session="$extract_dir/usr/libexec/sshd-session"
    if [[ -f "$sshd_session" ]]; then
        mkdir -p /usr/local/libexec
        install -m 755 "$sshd_session" "/usr/local/libexec/sshd-session" || log_warn "Failed to install sshd-session"
    fi

    if ! install_openssh_binaries; then
        log_warn "Failed to install OpenSSH binaries to system paths"
        rm -f "$tmp_deb"
        rm -rf "$extract_dir"
        return 1
    fi

    rm -f "$tmp_deb"
    rm -rf "$extract_dir"

    local new_version
    new_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "unknown")
    log_success "OpenSSH installed to $new_version via pre-built package"

    if ssh -Q kex 2>/dev/null | grep -q mlkem; then
        log_success "ML-KEM post-quantum key exchange confirmed available"
    fi

    return 0
}

# set_timezone() - Set system timezone
# Gets timezone from configuration and sets it using timedatectl
set_timezone() {
    local timezone
    timezone=$(get_config "timezone")
    
    # Default to UTC if not configured
    if [[ -z "$timezone" ]]; then
        log_warn "No timezone configured, defaulting to UTC"
        timezone="UTC"
    fi
    
    log_info "Setting timezone to: $timezone"
    print_header "Timezone Configuration"
    
    # Validate timezone exists
    if ! timedatectl list-timezones | grep -q "^${timezone}$"; then
        log_error "Invalid timezone: $timezone"
        return 1
    fi
    
    # Set timezone using execute_cmd
    if execute_cmd "timedatectl set-timezone '$timezone'" "Setting timezone to $timezone"; then
        log_success "Timezone set to: $timezone"
        
        # Verify and log current timezone
        local current_timezone
        current_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")
        log_verbose "Current timezone verified: $current_timezone"
        
        return 0
    else
        log_error "Failed to set timezone to: $timezone"
        return 1
    fi
}

# set_hostname() - Set system hostname
# Gets hostname from configuration and updates system hostname and hosts file
set_hostname() {
    local hostname
    hostname=$(get_config "hostname")
    
    # Validate hostname
    if [[ -z "$hostname" ]]; then
        log_error "No hostname configured"
        return 1
    fi
    
    if ! validate_hostname "$hostname"; then
        log_error "Invalid hostname format: $hostname"
        log_error "Hostname must start/end with alphanumeric, can contain hyphens and dots"
        return 1
    fi
    
    log_info "Setting hostname to: $hostname"
    print_header "Hostname Configuration"
    
    # Backup /etc/hosts before modifying
    if [[ -f "/etc/hosts" ]]; then
        log_verbose "Backing up /etc/hosts..."
        backup_file "/etc/hosts" || log_warn "Failed to backup /etc/hosts"
    fi
    
    # Set hostname using hostnamectl
    if ! execute_cmd "hostnamectl set-hostname '$hostname'" "Setting hostname to $hostname"; then
        log_error "Failed to set hostname"
        return 1
    fi
    
    # Update /etc/hostname file
    if ! execute_cmd "echo '$hostname' > /etc/hostname" "Updating /etc/hostname"; then
        log_warn "Failed to update /etc/hostname"
    fi
    
    # Update /etc/hosts with proper entries
    log_verbose "Updating /etc/hosts..."
    
    # Write /etc/hosts directly (avoid passing multi-line content through execute_cmd)
    log_verbose "Writing /etc/hosts..."
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would update /etc/hosts with hostname $hostname"
    else
        cat > /etc/hosts << EOF
127.0.0.1 localhost $hostname
127.0.1.1 $hostname

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
        if [[ $? -eq 0 ]]; then
            log_success "Hostname set to: $hostname"
            log_verbose "Updated /etc/hosts with new hostname"
        else
            log_error "Failed to update /etc/hosts"
            return 1
        fi
    fi
    return 0
}

# =========================================================
# Library: security.sh
# =========================================================

#
# lib/security.sh - Security hardening functions
#

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

disable_ssh_socket() {
    if systemctl list-unit-files ssh.socket &>/dev/null; then
        log_verbose "Detected ssh.socket (Ubuntu 24.04 socket activation)"
        execute_cmd "systemctl stop ssh.socket" "Stopping ssh.socket"
        execute_cmd "systemctl disable ssh.socket" "Disabling ssh.socket"
        execute_cmd "systemctl enable ssh" "Enabling ssh.service"
        log_verbose "Switched from ssh.socket to ssh.service"
    fi
}

# Harden SSH configuration
# Creates a hardened sshd_config with security best practices
harden_ssh() {
    log_info "Configuring SSH hardening..."

    # Get configuration values
    local ssh_port username
    ssh_port=$(get_config "ssh_port")
    username=$(get_config "username")

    # Validate configuration
    if [[ -z "$ssh_port" ]]; then
        log_error "SSH port not configured"
        return 1
    fi

    if [[ -z "$username" ]]; then
        log_error "Username not configured"
        return 1
    fi

    # In dry-run mode, just simulate SSH hardening
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would configure SSH hardening"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would set SSH port to $ssh_port"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would disable root login"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would disable password authentication"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would restart SSH service"
        return 0
    fi

    local sshd_config="/etc/ssh/sshd_config"
    
    # Backup original configuration
    backup_file "$sshd_config"
    
    local kex_algorithms="curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256"
    local pq_algorithms=""
    local available_kex
    available_kex=$(ssh -Q kex 2>/dev/null)
    if echo "$available_kex" | grep -q "mlkem768x25519-sha256"; then
        pq_algorithms="mlkem768x25519-sha256"
        log_verbose "ML-KEM post-quantum key exchange available"
    else
        log_verbose "ML-KEM not available, using classical key exchange only"
    fi
    if echo "$available_kex" | grep -q "sntrup761x25519-sha512"; then
        pq_algorithms="${pq_algorithms:+$pq_algorithms,}sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com"
        log_verbose "sntrup761 post-quantum key exchange available"
    fi
    if [[ -n "$pq_algorithms" ]]; then
        kex_algorithms="$pq_algorithms,$kex_algorithms"
    fi

    # Create hardened configuration
    log_verbose "Creating hardened sshd_config..."
    
    cat > "$sshd_config" << EOF
# Hardened SSH configuration generated by uservin
# Original config backed up

# Network settings
Port $ssh_port
AddressFamily any
ListenAddress 0.0.0.0
ListenAddress ::

# Protocol settings
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Ciphers and algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256
KexAlgorithms $kex_algorithms

# Authentication settings
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers $username
AuthenticationMethods publickey

# Session settings
X11Forwarding no
AllowAgentForwarding no
AllowTcpForwarding no
PermitTunnel no
GatewayPorts no
LoginGraceTime 60
MaxAuthTries 3
MaxSessions 2
ClientAliveInterval 300
ClientAliveCountMax 2

# Logging
SyslogFacility AUTH
LogLevel INFO

# Banner
UsePAM yes
PrintMotd no
PrintLastLog yes

# Environment
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    
    log_verbose "SSH configuration written successfully"
    
    mkdir -p /run/sshd
    chmod 755 /run/sshd
    chown root:root /run/sshd
    
    # Test configuration before applying
    log_verbose "Testing SSH configuration..."
    if ! sshd -t; then
        log_error "SSH configuration test failed - configuration may be invalid"
        return 1
    fi
    
    log_success "SSH configuration test passed"
    
    disable_ssh_socket
    
    # Reload SSH service (preserves existing sessions)
    log_verbose "Reloading SSH service..."
    if cmd_exists systemctl; then
        local ssh_service=""
        if systemctl list-unit-files ssh.service &>/dev/null; then
            ssh_service="ssh"
        elif systemctl list-unit-files sshd.service &>/dev/null; then
            ssh_service="sshd"
        fi
        
        if [[ -z "$ssh_service" ]] && pgrep -x sshd &>/dev/null; then
            log_verbose "Found running sshd process, registering systemd service"
            if [[ -f /lib/systemd/system/ssh.service ]]; then
                systemctl enable ssh 2>/dev/null
                ssh_service="ssh"
            elif [[ -f /lib/systemd/system/sshd.service ]]; then
                systemctl enable sshd 2>/dev/null
                ssh_service="sshd"
            fi
        fi

        if [[ -n "$ssh_service" ]]; then
            if systemctl reload "$ssh_service" 2>/dev/null; then
                log_success "SSH service reloaded (existing sessions preserved)"
            elif systemctl restart "$ssh_service" 2>/dev/null; then
                log_warn "SSH service restarted (existing sessions may be dropped)"
            else
                log_error "Failed to reload/restart SSH service"
                return 1
            fi
        else
            log_error "Could not determine SSH service name"
            return 1
        fi
    else
        log_warn "systemctl not available - cannot reload SSH service"
        return 1
    fi
    
    # Verify SSH is listening on the configured port
    sleep 1
    if ss -tlnp | grep -q ":$ssh_port "; then
        log_success "SSH is listening on port $ssh_port"
    else
        log_warn "SSH may not be listening on port $ssh_port"
    fi
    
    log_success "SSH hardening completed"
    return 0
}

# Configure UFW firewall
# Sets up UFW with secure defaults and SSH access
configure_ufw() {
    log_info "Configuring UFW firewall..."
    
    # Get SSH port
    local ssh_port
    ssh_port=$(get_config "ssh_port")
    
    if [[ -z "$ssh_port" ]]; then
        log_error "SSH port not configured"
        return 1
    fi
    
    # In dry-run mode, just simulate UFW configuration
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would configure UFW firewall"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would allow SSH port $ssh_port"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would enable UFW with default deny incoming"
        return 0
    fi
    
    # Check if UFW is installed
    if ! cmd_exists ufw; then
        log_error "UFW is not installed"
        return 1
    fi
    
    # Reset UFW to defaults (save existing rules first)
    log_verbose "Resetting UFW to defaults..."
    local ufw_backup_rules="/tmp/ufw-rules-backup.$(date +%s).rules"
    ufw status verbose > "$ufw_backup_rules" 2>/dev/null || true
    echo "y" | ufw reset &>/dev/null
    
    # Set default policies
    log_verbose "Setting default policies..."
    ufw default deny incoming &>/dev/null
    ufw default allow outgoing &>/dev/null
    
    # Allow SSH port
    log_verbose "Allowing SSH port $ssh_port..."
    ufw allow "$ssh_port/tcp" comment "SSH access" &>/dev/null
    
    # Rate limit SSH to prevent brute force
    log_verbose "Setting up SSH rate limiting..."
    ufw limit "$ssh_port/tcp" comment "SSH rate limit" &>/dev/null
    
    # Enable logging
    log_verbose "Enabling UFW logging..."
    ufw logging on &>/dev/null
    
    # Enable UFW
    log_verbose "Enabling UFW..."
    echo "y" | ufw enable &>/dev/null
    
    log_success "UFW firewall configured successfully"
    
    # Show status
    log_info "UFW Status:"
    ufw status verbose
    
    return 0
}

# Configure Fail2ban
# Sets up intrusion prevention for SSH
configure_fail2ban() {
    log_info "Configuring Fail2ban..."

    # Get SSH port
    local ssh_port
    ssh_port=$(get_config "ssh_port")

    if [[ -z "$ssh_port" ]]; then
        log_error "SSH port not configured"
        return 1
    fi

    # In dry-run mode, just simulate fail2ban configuration
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would configure Fail2ban"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would set SSH port to $ssh_port"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would create /etc/fail2ban/jail.local"
        return 0
    fi

    # Check if fail2ban is installed
    if ! cmd_exists fail2ban-server; then
        log_error "Fail2ban is not installed"
        return 1
    fi

    local jail_local="/etc/fail2ban/jail.local"
    
    # Backup existing jail.local if it exists
    if [[ -f "$jail_local" ]]; then
        backup_file "$jail_local"
    fi
    
    # Create jail.local configuration
    log_verbose "Creating Fail2ban configuration..."
    
    cat > "$jail_local" << EOF
# Fail2ban configuration generated by uservin
# See man jail.conf for more information

[DEFAULT]
# Ban time (1 hour)
bantime = 1h

# Time window for max retries (10 minutes)
findtime = 10m

# Maximum failed attempts before ban
maxretry = 5

# Use systemd backend for journald
backend = systemd

# Email notifications (optional - requires configuration)
destemail = root@localhost
sendername = Fail2ban

# Actions
action = %(action_)s

[sshd]
enabled = true
port = $ssh_port
filter = sshd
mode = aggressive
logpath = %(sshd_log)s
backend = systemd

# Stricter settings for SSH
maxretry = 3
bantime = 1h
findtime = 10m

# Ban persistent attackers longer
bantime.increment = true
bantime.factor = 2
bantime.maxtime = 48h
EOF
    
    log_verbose "Fail2ban configuration written successfully"
    
    # Restart fail2ban service
    log_verbose "Restarting Fail2ban service..."
    if cmd_exists systemctl; then
        if systemctl restart fail2ban; then
            log_success "Fail2ban service restarted successfully"
        else
            log_error "Failed to restart Fail2ban service"
            return 1
        fi
        
        # Enable on boot
        if systemctl enable fail2ban &>/dev/null; then
            log_success "Fail2ban enabled on boot"
        else
            log_warn "Failed to enable Fail2ban on boot"
        fi
    else
        log_warn "systemctl not available - cannot manage Fail2ban service"
        return 1
    fi
    
    # Show status
    log_info "Fail2ban Status:"
    if cmd_exists fail2ban-client; then
        fail2ban-client status sshd 2>/dev/null || log_warn "Could not get Fail2ban status"
    fi
    
    log_success "Fail2ban configuration completed"
    return 0
}

# Configure automatic updates
# Sets up unattended-upgrades for security updates only
configure_auto_updates() {
    log_info "Configuring automatic security updates..."
    
    local unattended_conf="/etc/apt/apt.conf.d/50unattended-upgrades"
    local auto_upgrades_conf="/etc/apt/apt.conf.d/20auto-upgrades"
    
    # Check if file exists
    if [[ ! -f "$unattended_conf" ]]; then
        log_warn "Unattended-upgrades configuration not found at $unattended_conf"
        log_info "Attempting to create basic configuration..."
        
        # Create directory if needed
        mkdir -p "$(dirname "$unattended_conf")"
    else
        # Backup existing configuration
        backup_file "$unattended_conf"
    fi
    
    # Create unattended-upgrades configuration
    log_verbose "Creating unattended-upgrades configuration..."
    
    cat > "$unattended_conf" << 'EOF'
// Unattended upgrades configuration generated by uservin
// See man unattended-upgrades for more information

// Automatically upgrade packages from these origins
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};

// Remove unused automatically installed kernel-related packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Remove unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Automatically reboot if required (disabled by default - user should configure)
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

// Automatically fix broken dpkg
Unattended-Upgrade::AutoFixInterruptedDpkg "true";

// Minimal steps to avoid taking up too much resource
Unattended-Upgrade::MinimalSteps "true";

// Send email reports (optional)
// Unattended-Upgrade::Mail "root";
// Unattended-Upgrade::MailReport "on-change";

// Clean up downloaded packages after installation
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
EOF
    
    log_verbose "Unattended-upgrades configuration written"
    
    # Create auto-upgrades configuration for periodic updates
    log_verbose "Creating auto-upgrades configuration..."
    
    cat > "$auto_upgrades_conf" << 'EOF'
// Auto-upgrades configuration generated by uservin
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    log_verbose "Auto-upgrades configuration written"
    
    # Restart unattended-upgrades service
    log_verbose "Restarting unattended-upgrades service..."
    if cmd_exists systemctl; then
        if systemctl restart unattended-upgrades 2>/dev/null; then
            log_verbose "Unattended-upgrades service restarted"
        else
            log_warn "Failed to restart unattended-upgrades service"
        fi
        
        # Enable on boot
        if systemctl enable unattended-upgrades 2>/dev/null; then
            log_success "Unattended-upgrades enabled on boot"
        else
            log_warn "Failed to enable unattended-upgrades on boot (package may not be installed)"
        fi
    fi
    
    log_success "Automatic security updates configured"
    return 0
}

# =========================================================
# Library: user.sh
# =========================================================

#
# lib/user.sh - User management functions
#

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Create admin user with sudo privileges
create_admin_user() {
    local username
    username=$(get_config "username")
    
    if [[ -z "$username" ]]; then
        log_error "No username configured"
        return 1
    fi
    
    if ! validate_username "$username"; then
        log_error "Invalid username format: $username"
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &> /dev/null; then
        log_warn "User '$username' already exists"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${YELLOW}[DRY-RUN]${NC} Would ask to continue with existing user"
        elif [[ -t 0 ]]; then
            if ! prompt_yesno "Continue with existing user '$username'?" "y"; then
                log_info "Skipping user creation"
                return 0
            fi
        else
            log_info "Non-interactive mode: continuing with existing user '$username'"
        fi
        
        # Add to groups even if user exists (in case they were removed)
        log_info "Ensuring user '$username' is in sudo and adm groups"
        if [[ "$DRY_RUN" == "false" ]]; then
            usermod -aG sudo,adm "$username"
        else
            echo -e "${YELLOW}[DRY-RUN]${NC} Would add '$username' to sudo and adm groups"
        fi
        
        return 0
    fi
    
    # Create new user
    log_info "Creating user: $username"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would create user '$username' with home directory"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would generate random password"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would add '$username' to sudo and adm groups"
        return 0
    fi
    
    # Create user with home directory and bash shell
    if ! useradd -m -s /bin/bash "$username"; then
        log_error "Failed to create user: $username"
        return 1
    fi
    
    # Generate random password
    local password
    password=$(openssl rand -base64 32)
    
    # Set password
    echo "$username:$password" | chpasswd
    
    # Add to sudo and adm groups
    usermod -aG sudo,adm "$username"
    
    if [[ -w /dev/tty ]]; then
        cat > /dev/tty << CREDEND
${YELLOW}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  USER CREDENTIALS - SAVE THIS!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Username: $username
  Password: $password
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${NC}
CREDEND
    else
        echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo -e "${YELLOW}  USER CREDENTIALS - SAVE THIS!${NC}" >&2
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
        echo -e "${YELLOW}  Username: $username${NC}" >&2
        echo -e "${YELLOW}  Password: $password${NC}" >&2
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" >&2
    fi

    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') USER CREATED: username=$username (password displayed on screen only)" >> "$LOG_FILE"
    fi
    
    log_warn "Please change the password after first login!"
    log_success "User '$username' created with sudo privileges"
    
    return 0
}

# Setup SSH keys for user
setup_ssh_keys() {
    local username
    username=$(get_config "username")
    local ssh_key
    ssh_key=$(get_config "ssh_key")
    
    if [[ -z "$username" ]]; then
        log_error "No username configured"
        return 1
    fi
    
    if [[ -z "$ssh_key" ]]; then
        log_warn "No SSH key configured, skipping SSH key setup"
        return 0
    fi
    
    log_info "Setting up SSH keys for user: $username"
    
    # In dry-run mode, skip user existence check
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would create .ssh directory for user '$username'"
        echo -e "${YELLOW}[DRY-RUN]${NC} Would add SSH key to authorized_keys"
        return 0
    fi
    
    # Check if user exists
    if ! id "$username" &> /dev/null; then
        log_error "User '$username' does not exist. Create user first."
        return 1
    fi
    
    # Get user's home directory
    local home_dir
    home_dir=$(getent passwd "$username" | cut -d: -f6)
    
    if [[ -z "$home_dir" ]] || [[ ! -d "$home_dir" ]]; then
        log_error "Home directory not found for user: $username"
        return 1
    fi
    
    local ssh_dir="$home_dir/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    
    # Create .ssh directory if it doesn't exist
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chmod 700 "$ssh_dir"
        chown "$username:$username" "$ssh_dir"
        log_verbose "Created .ssh directory: $ssh_dir"
    fi
    
    # Check for duplicate key before appending
    if [[ -f "$auth_keys" ]] && grep -qF "$ssh_key" "$auth_keys"; then
        log_warn "SSH key already exists in authorized_keys, skipping"
    else
        # Ensure file ends with newline before appending
        if [[ -s "$auth_keys" ]] && [[ "$(tail -c1 "$auth_keys" | wc -l)" -eq 0 ]]; then
            echo "" >> "$auth_keys"
        fi
        echo "$ssh_key" >> "$auth_keys"
    fi
    
    # Set permissions
    chmod 600 "$auth_keys"
    chown "$username:$username" "$auth_keys"
    
    # Count keys in authorized_keys
    local key_count
    key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo "0")
    
    log_success "SSH key added for user '$username' (total keys: $key_count)"
    
    return 0
}

# =========================================================
# Library: performance.sh
# =========================================================

#
# lib/performance.sh - Performance optimization functions
#

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

_CACHED_MEM_GB=""

get_cached_mem_gb() {
    if [[ -z "$_CACHED_MEM_GB" ]]; then
        _CACHED_MEM_GB=$(get_mem_gb)
        [[ "$_CACHED_MEM_GB" -eq 0 ]] && _CACHED_MEM_GB=2
    fi
    echo "$_CACHED_MEM_GB"
}

# Optimize system performance
# Creates sysctl configuration, sets resource limits, and tunes TCP/network settings
optimize_performance() {
    log_info "Optimizing system performance..."
    
    # Detect system specs
    local cpu_cores disk_type
    cpu_cores=$(nproc 2>/dev/null || echo "1")
    mem_gb=$(get_cached_mem_gb)
    
    # Detect SSD by checking /sys/block/*/queue/rotational
    disk_type="HDD"
    for block_dev in /sys/block/*/queue/rotational; do
        if [[ -f "$block_dev" ]]; then
            if [[ "$(cat "$block_dev" 2>/dev/null)" == "0" ]]; then
                disk_type="SSD"
                break
            fi
        fi
    done
    
    log_verbose "Detected: $cpu_cores CPU cores, ${mem_gb}GB RAM, $disk_type"
    
    # Backup sysctl.conf if it exists
    if [[ -f /etc/sysctl.conf ]]; then
        backup_file /etc/sysctl.conf
    fi
    
    # Create /etc/sysctl.d/99-uservin.conf with optimizations
    local sysctl_conf="/etc/sysctl.d/99-uservin.conf"
    
    log_verbose "Creating sysctl configuration..."
    
    cat > "$sysctl_conf" << EOF
# uservin performance optimizations
# Generated on $(date)

# TCP BBR congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# TCP optimizations
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1

# Buffer sizes
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# Connection tracking
net.netfilter.nf_conntrack_max = 65536

# File descriptors
fs.file-max = 1048576
fs.nr_open = 1048576

# Swappiness and cache pressure
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# Virtual memory tuning
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5

# Kernel security
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1

# Network security
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EOF
    
    # Apply sysctl settings
    if [[ "$DRY_RUN" != "true" ]]; then
        log_verbose "Applying sysctl settings..."
        sysctl --system >/dev/null 2>&1 || true
    else
        log_verbose "[DRY-RUN] Would apply sysctl settings"
    fi
    
    # Backup and update limits.conf
    if [[ -f /etc/security/limits.conf ]]; then
        backup_file /etc/security/limits.conf
    fi
    
    # Update limits.conf with nofile limits
    log_verbose "Setting file descriptor limits..."
    
    # Add limits if not already present
    if ! grep -q "^\* soft nofile" /etc/security/limits.conf 2>/dev/null; then
        cat >> /etc/security/limits.conf << 'EOF'

# uservin: increase file descriptor limits
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF
    fi
    
    log_success "System performance optimized"
}

# Configure swap file
# Creates and enables a swap file based on configuration
configure_swap() {
    log_info "Configuring swap..."
    
    # Get enable_swap from get_config()
    local enable_swap
    enable_swap=$(get_config "enable_swap")
    
    # Skip if not enabled
    if [[ "$enable_swap" != "true" ]]; then
        log_info "Swap is disabled, skipping..."
        return 0
    fi
    
    # Check if swap already exists
    if swapon --show >/dev/null 2>&1 | grep -q "."; then
        log_warn "Swap already configured, skipping..."
        return 0
    fi
    
    # Detect RAM for swap sizing
    local mem_gb swap_size
    mem_gb=$(get_cached_mem_gb)
    
    # Determine swap size: 2GB default, adjust if RAM < 2GB
    if [[ $mem_gb -lt 2 ]]; then
        swap_size="${mem_gb}G"
    else
        swap_size="2G"
    fi
    
    log_info "Creating ${swap_size} swap file..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Create swap file using fallocate
        if ! fallocate -l "$swap_size" /swapfile 2>/dev/null; then
            if ! dd if=/dev/zero of=/swapfile bs=1M count=$((${swap_size%G} * 1024)) 2>/dev/null; then
                log_error "Failed to create swap file"
                return 1
            fi
        fi
        
        # Set proper permissions
        chmod 600 /swapfile
        
        # Initialize swap
        if ! mkswap /swapfile >/dev/null 2>&1; then
            log_error "Failed to initialize swap file"
            rm -f /swapfile
            return 1
        fi
        
        # Enable swap
        if ! swapon /swapfile; then
            log_error "Failed to enable swap"
            rm -f /swapfile
            return 1
        fi
        
        # Add to /etc/fstab if not already present
        if ! grep -q "/swapfile" /etc/fstab 2>/dev/null; then
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi
        
        log_success "Swap configured (${swap_size})"
    else
        log_verbose "[DRY-RUN] Would create ${swap_size} swap file"
    fi
}

# Configure zram (compressed RAM swap)
# Sets up zram for improved memory management
configure_zram() {
    log_info "Configuring zram..."
    
    # Get enable_zram from get_config()
    local enable_zram
    enable_zram=$(get_config "enable_zram")
    
    # Skip if not enabled
    if [[ "$enable_zram" != "true" ]]; then
        log_info "Zram is disabled, skipping..."
        return 0
    fi
    
    # Check if zram is already configured
    if [[ -f /sys/block/zram0/comp_algorithm ]] && grep -q "/dev/zram" /proc/swaps 2>/dev/null; then
        log_warn "Zram already configured, skipping..."
        return 0
    fi
    
    # Detect RAM for zram sizing
    local mem_gb zram_size
    mem_gb=$(get_cached_mem_gb)
    
    # Set size to 50% of RAM, minimum 512M
    local zram_mb=$((mem_gb * 1024 / 2))
    if [[ $zram_mb -lt 512 ]]; then
        zram_mb=512
    fi
    
    log_info "Setting up zram (${zram_mb}MB)..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Load zram module
        if ! modprobe zram 2>/dev/null; then
            log_error "Failed to load zram kernel module"
            return 1
        fi
        
        # Set compression algorithm (zstd preferred, fallback to lzo)
        local comp_algo="lzo"
        if [[ -f /sys/block/zram0/comp_algorithm ]]; then
            if grep -q "zstd" /sys/block/zram0/comp_algorithm 2>/dev/null; then
                comp_algo="zstd"
            fi
            if ! echo "$comp_algo" > /sys/block/zram0/comp_algorithm 2>/dev/null; then
                log_warn "Failed to set zram compression algorithm, using default"
            fi
        fi
        
        log_verbose "Using compression algorithm: $comp_algo"
        
        # Set zram size
        if [[ -f /sys/block/zram0/disksize ]]; then
            if ! echo "${zram_mb}M" > /sys/block/zram0/disksize 2>/dev/null; then
                log_error "Failed to set zram disk size"
                return 1
            fi
        fi
        
        # Initialize swap on zram
        if ! mkswap /dev/zram0 >/dev/null 2>&1; then
            log_error "Failed to initialize zram swap"
            return 1
        fi
        if ! swapon /dev/zram0 >/dev/null 2>&1; then
            log_error "Failed to enable zram swap"
            return 1
        fi
        
        # Create systemd service for persistence
        local zram_service="/etc/systemd/system/zram.service"
        cat > "$zram_service" << EOF
[Unit]
Description=Zram swap service
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe zram
ExecStart=/bin/sh -c 'echo $comp_algo > /sys/block/zram0/comp_algorithm'
ExecStart=/bin/sh -c 'echo ${zram_mb}M > /sys/block/zram0/disksize'
ExecStart=/sbin/mkswap /dev/zram0
ExecStart=/sbin/swapon /dev/zram0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        
        # Enable service
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable zram.service 2>/dev/null || true
        
        log_success "Zram configured (${zram_mb}MB with $comp_algo compression)"
        
        # Show memory status
        free -h 2>/dev/null || cat /proc/meminfo | grep -E "^(Mem|Swap)" || true
    else
        log_verbose "[DRY-RUN] Would configure zram (${zram_mb}MB)"
    fi
}

# =========================================================
# Library: report.sh
# =========================================================

#
# lib/report.sh - Report generation functions
#

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Display completion report
# Outputs: Formatted completion report with connection info, components, and next steps
show_completion() {
    # Get configuration values
    local ssh_port
    local username
    local hostname
    ssh_port=$(get_config "ssh_port")
    username=$(get_config "username")
    hostname=$(get_config "hostname")
    
    # Print formatted completion banner
    echo ""
    echo "========================================"
    echo "   Server Setup Complete!"
    echo "========================================"
    echo ""
    
    # Show connection information
    echo "Connection Information:"
    echo "  Hostname: $hostname"
    echo "  SSH Port: $ssh_port"
    echo "  Username: $username"
    echo "  Auth Method: SSH Key Only"
    echo ""
    echo "  SSH Command Example:"
    echo "    ssh -p $ssh_port $username@$hostname"
    echo ""
    
    # List configured components
    echo "Configured Components:"
    echo "  ✓ System packages"
    echo "  ✓ Utilities"
    local openssh_label="  ✓ OpenSSH upgrade"
    if sshd -T -o "kexalgorithms=+mlkem768x25519-sha256" 2>/dev/null | grep -q "mlkem768x25519-sha256"; then
        openssh_label="$openssh_label (post-quantum ML-KEM)"
    elif sshd -Q kex 2>/dev/null | grep -q "mlkem768x25519-sha256"; then
        openssh_label="$openssh_label (post-quantum ML-KEM)"
    fi
    echo "$openssh_label"
    echo "  ✓ Firewall (UFW)"
    echo "  ✓ Fail2ban"
    echo "  ✓ SSH hardening"
    echo "  ✓ Admin user"
    echo "  ✓ Auto updates"
    echo "  ✓ Performance optimization"
    
    # Show swap and zram status if enabled
    local enable_swap
    local enable_zram
    enable_swap=$(get_config "enable_swap")
    enable_zram=$(get_config "enable_zram")
    
    if [[ "$enable_swap" == "true" ]]; then
        echo "  ✓ Swap"
    fi
    if [[ "$enable_zram" == "true" ]]; then
        echo "  ✓ Zram"
    fi
    
    echo ""
    
    # Show important warnings
    echo "IMPORTANT WARNINGS:"
    echo "  • Root password login has been disabled"
    echo "  • Always test SSH connection before closing this session"
    echo ""
    
    # Show backup and restore information
    echo "Backup Information:"
    echo "  Backup Location: /root/uservin-backups/"
    echo "  Log File: /var/log/uservin/"
    echo "  Restore Script: /root/uservin-backups/<timestamp>/restore.sh"
    if [[ -n "${LOG_FILE:-}" ]] && [[ -f "${LOG_FILE:-}" ]]; then
        echo "  Full Setup Log: $LOG_FILE"
    fi
    echo ""
    
    # Show next steps
    echo "Next Steps:"
    echo "  1. Test SSH connection in a NEW terminal window"
    echo "  2. Change your user password: passwd"
    echo "  3. Review firewall rules: sudo ufw status verbose"
    echo "  4. Check fail2ban status: sudo fail2ban-client status"
    echo ""
    
    # Save report to file
    local report_file="/root/uservin-report-$(date +%Y%m%d-%H%M%S).txt"
    {
        echo "uservin Installation Report"
        echo "Generated: $(date)"
        echo ""
        echo "Connection Information:"
        echo "  Hostname: $hostname"
        echo "  SSH Port: $ssh_port"
        echo "  Username: $username"
        echo "  SSH Command: ssh -p $ssh_port $username@$hostname"
    } > "$report_file"
    
    echo "Report saved to: $report_file"
    echo ""
    
    # Final security reminders
    echo "Security Reminders:"
    echo "  • Keep your SSH key secure - it's your only access method"
    echo "  • Regularly update your system"
    echo "  • Monitor system logs for suspicious activity"
    echo ""
    echo "========================================"
}

# Execute all setup functions in order
# Returns: 0 on success, 1 on critical failure
execute_setup() {
    local critical_failed=false
    
    log_info "Starting server setup..."
    
    # Initialize backup system
    update_status "running" "Initializing backup system..."
    log_info "Initializing backup system..."
    if ! init_backup; then
        log_error "Failed to initialize backup system"
        return 1
    fi
    
    # Run system updates - rollback on failure
    update_status "running" "Running system updates..."
    log_info "Running system updates..."
    if ! update_system; then
        log_error "Failed to update system"
        update_status "failed" "System updates failed"
        set_rollback_needed
        critical_failed=true
    fi
    
    # Install packages - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Installing packages..."
        log_info "Installing packages..."
        if ! install_packages; then
            log_error "Failed to install packages"
            update_status "failed" "Package installation failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Set hostname - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Configuring hostname..."
        log_info "Setting hostname..."
        if ! set_hostname; then
            log_error "Failed to set hostname"
            update_status "failed" "Hostname configuration failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Set timezone - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Configuring timezone..."
        log_info "Setting timezone..."
        if ! set_timezone; then
            log_error "Failed to set timezone"
            update_status "failed" "Timezone configuration failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Create admin user - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Creating admin user..."
        log_info "Creating admin user..."
        if ! create_admin_user; then
            log_error "Failed to create admin user"
            update_status "failed" "Admin user creation failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Setup SSH keys - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Setting up SSH keys..."
        log_info "Setting up SSH keys..."
        if ! setup_ssh_keys; then
            log_error "Failed to setup SSH keys"
            update_status "failed" "SSH key setup failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Configure UFW - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Configuring firewall..."
        log_info "Configuring firewall..."
        if ! configure_ufw; then
            log_error "Failed to configure UFW"
            update_status "failed" "Firewall configuration failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Configure Fail2ban - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Configuring fail2ban..."
        log_info "Configuring fail2ban..."
        if ! configure_fail2ban; then
            log_error "Failed to configure fail2ban"
            update_status "failed" "Fail2ban configuration failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Harden SSH - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Hardening SSH..."
        log_info "Hardening SSH..."
        if ! harden_ssh; then
            log_error "Failed to harden SSH"
            update_status "failed" "SSH hardening failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Optimize performance - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Optimizing performance..."
        log_info "Optimizing performance..."
        if ! optimize_performance; then
            log_error "Failed to optimize performance"
            update_status "failed" "Performance optimization failed"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Configure swap - non-critical
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Configuring swap..."
        log_info "Configuring swap..."
        if ! configure_swap; then
            log_warn "Failed to configure swap (non-critical)"
        fi
    fi
    
    # Configure zram - non-critical
    if [[ "$critical_failed" == "false" ]]; then
        update_status "running" "Configuring zram..."
        log_info "Configuring zram..."
        if ! configure_zram; then
            log_warn "Failed to configure zram (non-critical)"
        fi
    fi
    
    # Configure auto updates if enabled - non-critical
    if [[ "$critical_failed" == "false" ]]; then
        local auto_updates
        auto_updates=$(get_config "auto_updates")
        if [[ "$auto_updates" == "true" ]]; then
            update_status "running" "Configuring auto updates..."
            log_info "Configuring auto updates..."
            if ! configure_auto_updates; then
                log_warn "Failed to configure auto updates (non-critical)"
            fi
        fi
    fi
    
    # Create restore script
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Creating restore script..."
        if ! create_restore_script; then
            log_warn "Failed to create restore script"
        fi
    fi
    
    # Check if rollback is needed
    if [[ "$critical_failed" == "true" ]]; then
        log_error "Critical failures occurred during setup"
        update_status "failed" "Critical failures occurred during setup"
        check_rollback
        return 1
    fi
    
    update_status "completed" "Server setup completed successfully"
    log_info "Server setup completed successfully"
    return 0
}


# =========================================================
# Main Entry Point
# =========================================================

# Show help message
show_help() {
    cat << EOF
uservin - Ubuntu Server Initialization Tool v${SCRIPT_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
    --dry-run        Simulate changes without making them
    --quiet, -q      Minimal output (errors only)
    --verbose, -v    Detailed output
    --config FILE    Use custom configuration file
    --status         Show status of running or last uservin process
    --no-background  Run in foreground even in interactive terminal
    --help, -h       Show this help message
    --version        Show version information

Description:
    Initializes and configures Ubuntu servers with security hardening,
    user management, system optimization, and more.

Examples:
    $(basename "$0")                    # Run with default settings
    $(basename "$0") --dry-run          # Preview changes
    $(basename "$0") --config my.cfg    # Use custom config

Background Execution:
  When run interactively, uservin automatically backgrounds itself.
  Progress is logged to /var/log/uservin/ and can be monitored with:
    tail -f /var/log/uservin/uservin-*.log

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
            --status)
                show_status
                exit $?
                ;;
            --no-background)
                NO_BACKGROUND=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --version)
                echo "uservin version $SCRIPT_VERSION"
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
    local ORIGINAL_ARGS=("$@")
    parse_args "$@"
    
    init_logging
    
    setup_background_execution "${ORIGINAL_ARGS[@]}"
    
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
    if ! preflight_checks; then
        log_error "Preflight checks failed. Aborting."
        exit 1
    fi
    
    # Show welcome
    show_welcome
    
    # Run wizard or load config
    if [[ -n "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from: $CONFIG_FILE"
        if ! load_config_file; then
            log_error "Failed to load configuration file"
            exit 1
        fi
    else
        run_wizard
    fi
    
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
