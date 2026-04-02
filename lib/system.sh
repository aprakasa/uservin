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
    
    log_info "Repository doesn't have OpenSSH 9.7+, will compile from source"
    
    if compile_openssh_from_source; then
        if install_openssh_binaries; then
            local new_version
            new_version=$(ssh -V 2>&1 | grep -oP 'OpenSSH_\K[0-9]+\.[0-9]+' || echo "unknown")
            log_success "OpenSSH upgraded to $new_version with post-quantum support"
            
            if ssh -Q kex 2>/dev/null | grep -q mlkem; then
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
    local openssh_version="9.9p1"
    local tar_url="https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${openssh_version}.tar.gz"
    local build_dir
    
    build_dir=$(mktemp -d /tmp/openssh-build.XXXXXX)
    
    log_info "Compiling OpenSSH $openssh_version from source..."
    print_header "OpenSSH Source Compile"
    
    log_verbose "Installing build dependencies..."
    if ! execute_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -y -qq build-essential libssl-dev zlib1g-dev libpam0g-dev libkrb5-dev libedit-dev libselinux1-dev" "Installing build dependencies"; then
        log_error "Failed to install build dependencies"
        rm -rf "$build_dir"
        return 1
    fi
    
    log_verbose "Downloading OpenSSH $openssh_version..."
    if ! execute_cmd "curl -fSL -o $build_dir/openssh.tar.gz $tar_url" "Downloading OpenSSH source"; then
        log_error "Failed to download OpenSSH source"
        rm -rf "$build_dir"
        return 1
    fi
    
    log_verbose "Extracting source..."
    if ! execute_cmd "tar -xzf $build_dir/openssh.tar.gz -C $build_dir" "Extracting OpenSSH source"; then
        log_error "Failed to extract OpenSSH source"
        rm -rf "$build_dir"
        return 1
    fi
    
    local src_dir="$build_dir/openssh-${openssh_version}"
    
    log_verbose "Configuring OpenSSH..."
    if ! execute_cmd "cd $src_dir && ./configure --prefix=/usr/local --with-pam --with-privsep-path=/run/sshd --with-pid-dir=/run" "Configuring OpenSSH build"; then
        log_error "Failed to configure OpenSSH"
        rm -rf "$build_dir"
        return 1
    fi
    
    log_verbose "Compiling OpenSSH..."
    if ! execute_cmd "make -C $src_dir -j\$(nproc)" "Compiling OpenSSH (this may take a few minutes)"; then
        log_error "Failed to compile OpenSSH"
        rm -rf "$build_dir"
        return 1
    fi
    
    log_verbose "Installing to /usr/local prefix..."
    if ! execute_cmd "make -C $src_dir install" "Installing OpenSSH to /usr/local"; then
        log_error "Failed to install OpenSSH"
        rm -rf "$build_dir"
        return 1
    fi
    
    rm -rf "$build_dir"
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
        install -m 755 "$sshd_session" /usr/lib/openssh/sshd-session || log_warn "Failed to install sshd-session"
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
