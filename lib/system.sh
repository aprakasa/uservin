#!/bin/bash
#
# lib/system.sh - System configuration functions
#

# Source dependencies
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/wizard.sh"
# shellcheck source=/dev/null
source "$(dirname "${BASH_SOURCE[0]}")/safety.sh"

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
    
    # Update package lists
    log_verbose "Running apt-get update..."
    if ! execute_cmd "apt-get update -qq" "apt-get update"; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    # Upgrade installed packages
    log_verbose "Running apt-get dist-upgrade..."
    if ! execute_cmd "apt-get dist-upgrade -y -qq" "apt-get dist-upgrade"; then
        log_error "Failed to upgrade packages"
        return 1
    fi
    
    # Remove unnecessary packages
    log_verbose "Removing unnecessary packages..."
    if ! execute_cmd "apt-get autoremove --purge -y -qq" "apt-get autoremove --purge"; then
        log_warn "Failed to remove some unnecessary packages"
    fi
    
    # Clean package cache
    log_verbose "Cleaning package cache..."
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
    if apt-cache show zram-tools &>/dev/null 2>&1; then
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

# upgrade_openssh() - Upgrade OpenSSH to version 9.7+ with post-quantum support
# Checks current version and upgrades if necessary
upgrade_openssh() {
    log_info "Checking OpenSSH version..."
    
    # Get current OpenSSH version
    local current_version
    current_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "0.0")
    
    log_info "Current OpenSSH version: $current_version"
    
    # Check if version is >= 9.7
    if [[ "$(printf '%s\n' "$current_version" "9.7" | sort -V | head -n1)" = "9.7" ]]; then
        log_success "OpenSSH $current_version already has post-quantum support"
        return 0
    fi
    
    log_info "Upgrading OpenSSH to version 9.7+ for post-quantum cryptography support..."
    print_header "OpenSSH Upgrade"
    
    # Backup SSH configuration
    if [[ -f /etc/ssh/sshd_config ]]; then
        backup_file /etc/ssh/sshd_config
    fi
    
    # Install prerequisites
    execute_cmd "apt-get install -y -qq software-properties-common" "Installing prerequisites"
    
    # Add PPA for newer OpenSSH on Ubuntu 24.04
    # Using the official Ubuntu backports or a trusted PPA
    log_verbose "Adding PPA for OpenSSH updates..."
    
    # Try to add PPA (this may fail on some systems, which is okay)
    if execute_cmd "add-apt-repository -y ppa:openssh/ppa 2>/dev/null || true" "Adding OpenSSH PPA"; then
        execute_cmd "apt-get update -qq" "Updating package lists"
    else
        log_warn "Could not add OpenSSH PPA, trying standard repository..."
    fi
    
    # Install/upgrade OpenSSH
    if execute_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq openssh-server openssh-client" "Upgrading OpenSSH"; then
        # Get new version
        local new_version
        new_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "unknown")
        
        log_success "OpenSSH upgraded to version $new_version"
        
        # Restart SSH service to apply changes
        log_info "Restarting SSH service..."
        if execute_cmd "systemctl restart sshd || systemctl restart ssh" "Restarting SSH service"; then
            log_success "SSH service restarted successfully"
        else
            log_warn "Could not restart SSH service automatically"
        fi
        
        # Note about post-quantum algorithms
        if [[ "$(printf '%s\n' "$new_version" "9.7" | sort -V | head -n1)" = "9.7" ]]; then
            log_info "OpenSSH now supports post-quantum key exchange algorithms"
        else
            log_warn "OpenSSH version $new_version may not fully support all post-quantum algorithms"
            log_info "Post-quantum support requires OpenSSH 9.7+. Ubuntu will receive this through normal updates."
        fi
        
        return 0
    else
        log_error "Failed to upgrade OpenSSH"
        log_info "Ubuntu will provide OpenSSH updates through the standard update process"
        return 1
    fi
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
    
    # Validate hostname - allow simple hostnames and FQDNs
    # Simple hostname: alphanum + hyphens (e.g., "myserver")
    # FQDN: hostname + dots + domain (e.g., "srv.stackengineer.dev")
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([-a-zA-Z0-9]*[a-zA-Z0-9])?)*$ ]]; then
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
    
    # Create new hosts file content
    local hosts_content
    hosts_content="127.0.0.1 localhost $hostname
127.0.1.1 $hostname

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters"
    
    if execute_cmd "echo '$hosts_content' > /etc/hosts" "Updating /etc/hosts"; then
        log_success "Hostname set to: $hostname"
        log_verbose "Updated /etc/hosts with new hostname"
        return 0
    else
        log_error "Failed to update /etc/hosts"
        return 1
    fi
}
