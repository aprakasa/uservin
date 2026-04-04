#!/bin/bash
#
# lib/safety.sh - Safety checks and rollback functionality
#

# Source utils if not already sourced
if [[ -z "${LOG_LEVEL:-}" ]]; then
    # shellcheck source=/dev/null
    source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
fi

# Safety module variables
BACKUP_DIR=""                    # Backup directory path
BACKUP_FILES=()                  # Array of backed up files (format: "original|backup")
ROLLBACK_NEEDED=false            # Flag for rollback on error

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
trap 'set_rollback_needed' ERR
