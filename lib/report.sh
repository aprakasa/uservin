#!/bin/bash
#
# lib/report.sh - Report generation functions
#

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/wizard.sh"
source "$SCRIPT_DIR/safety.sh"
source "$SCRIPT_DIR/system.sh"
source "$SCRIPT_DIR/security.sh"
source "$SCRIPT_DIR/user.sh"
source "$SCRIPT_DIR/performance.sh"

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
    echo "  Backup Location: /root/uservin-backup-*"
    echo "  Log File: /root/uservin-*.log"
    echo "  Restore Command: /root/restore-uservin.sh"
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
te_setup() {
    local critical_failed=false
    
    log_info "Starting server setup..."
    
    # Initialize backup system
    log_info "Initializing backup system..."
    if ! init_backup; then
        log_error "Failed to initialize backup system"
        return 1
    fi
    
    # Run system updates - rollback on failure
    log_info "Running system updates..."
    if ! update_system; then
        log_error "Failed to update system"
        set_rollback_needed
        critical_failed=true
    fi
    
    # Install packages - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Installing packages..."
        if ! install_packages; then
            log_error "Failed to install packages"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Set hostname - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Setting hostname..."
        if ! set_hostname; then
            log_error "Failed to set hostname"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Set timezone - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Setting timezone..."
        if ! set_timezone; then
            log_error "Failed to set timezone"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Create admin user - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Creating admin user..."
        if ! create_admin_user; then
            log_error "Failed to create admin user"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Setup SSH keys - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Setting up SSH keys..."
        if ! setup_ssh_keys; then
            log_error "Failed to setup SSH keys"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Configure UFW - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Configuring firewall..."
        if ! configure_ufw; then
            log_error "Failed to configure UFW"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Configure Fail2ban - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Configuring fail2ban..."
        if ! configure_fail2ban; then
            log_error "Failed to configure fail2ban"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Harden SSH - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Hardening SSH..."
        if ! harden_ssh; then
            log_error "Failed to harden SSH"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Optimize performance - rollback on failure
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Optimizing performance..."
        if ! optimize_performance; then
            log_error "Failed to optimize performance"
            set_rollback_needed
            critical_failed=true
        fi
    fi
    
    # Configure swap - non-critical
    if [[ "$critical_failed" == "false" ]]; then
        log_info "Configuring swap..."
        if ! configure_swap; then
            log_warn "Failed to configure swap (non-critical)"
        fi
    fi
    
    # Configure zram - non-critical
    if [[ "$critical_failed" == "false" ]]; then
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
        check_rollback
        return 1
    fi
    
    log_info "Server setup completed successfully"
    return 0
}

# Alias for compatibility with test expectations
execute_setup() {
    te_setup "$@"
}
