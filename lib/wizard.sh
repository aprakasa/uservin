#!/bin/bash
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
    echo -e '  _   _                 _           _'
    echo -e ' | | | | ___ _   _ _ __| | __ _ ___| |_'
    echo -e ' | | | |/ __| | | | '"'"'__'"'"'| |/ \` / __| __|'
    echo -e ' | |_| |\__ \ |_| | |  | | (_| \__ \ |_'
    echo -e '  \___/ |___/\__,_|_|  |_|\__,_|___/\__|'
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
        if [[ -n "$CONFIG_HOSTNAME" && "$CONFIG_HOSTNAME" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*$ ]]; then
            break
        fi
        log_error "Invalid hostname. Use alphanumeric characters and hyphens only."
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
        # Validate username format (lowercase, alphanumeric, underscore, hyphen; start with letter)
        if [[ "$CONFIG_USERNAME" =~ ^[a-z][-a-z0-9_]*$ && ${#CONFIG_USERNAME} -ge 1 && ${#CONFIG_USERNAME} -le 32 ]]; then
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
    if [[ -f /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_gb=$((mem_kb / 1024 / 1024))
    else
        mem_gb=4  # Default assumption if we can't detect
    fi
    
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
    local section=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Check for section header
        if [[ "$line" =~ ^\[([^]]+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
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
            case "$section:$key" in
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
    
    log_success "Configuration loaded successfully"
    return 0
}
