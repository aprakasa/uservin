#!/bin/bash
#
# lib/user.sh - User management functions
#

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/utils.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/wizard.sh"

# Create admin user with sudo privileges
create_admin_user() {
    local username
    username=$(get_config "username")
    
    if [[ -z "$username" ]]; then
        log_error "No username configured"
        return 1
    fi
    
    # Validate username format
    if [[ ! "$username" =~ ^[a-z][-a-z0-9_]*$ ]] || [[ ${#username} -lt 1 ]] || [[ ${#username} -gt 32 ]]; then
        log_error "Invalid username format: $username"
        return 1
    fi
    
    # Check if user already exists
    if id "$username" &> /dev/null; then
        log_warn "User '$username' already exists"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${YELLOW}[DRY-RUN]${NC} Would ask to continue with existing user"
        else
            if ! prompt_yesno "Continue with existing user '$username'?" "y"; then
                log_info "Skipping user creation"
                return 0
            fi
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
    
    # Display credentials prominently
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  USER CREDENTIALS - SAVE THIS!${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}  Username: $username${NC}"
    echo -e "${YELLOW}  Password: $password${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    # Save credentials to log file if set
    if [[ -n "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') USER CREATED: username=$username password=$password" >> "$LOG_FILE"
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
    home_dir=$(eval echo "~$username")
    
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
    
    # Append SSH key to authorized_keys
    echo "$ssh_key" >> "$auth_keys"
    
    # Set permissions
    chmod 600 "$auth_keys"
    chown "$username:$username" "$auth_keys"
    
    # Count keys in authorized_keys
    local key_count
    key_count=$(grep -c "^ssh-" "$auth_keys" 2>/dev/null || echo "0")
    
    log_success "SSH key added for user '$username' (total keys: $key_count)"
    
    return 0
}
