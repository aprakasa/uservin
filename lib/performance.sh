#!/bin/bash
#
# lib/performance.sh - Performance optimization functions
#

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/wizard.sh"
source "$SCRIPT_DIR/safety.sh"

# Optimize system performance
# Creates sysctl configuration, sets resource limits, and tunes TCP/network settings
optimize_performance() {
    log_info "Optimizing system performance..."
    
    # Detect system specs
    local cpu_cores mem_kb mem_gb disk_type
    cpu_cores=$(nproc 2>/dev/null || echo "1")
    
    if [[ -f /proc/meminfo ]]; then
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_gb=$((mem_kb / 1024 / 1024))
    else
        mem_gb=2
    fi
    
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
    local mem_kb mem_gb swap_size
    if [[ -f /proc/meminfo ]]; then
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_gb=$((mem_kb / 1024 / 1024))
    else
        mem_gb=2
    fi
    
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
            # Fallback to dd if fallocate fails
            dd if=/dev/zero of=/swapfile bs=1M count=$((${swap_size%G} * 1024)) 2>/dev/null
        fi
        
        # Set proper permissions
        chmod 600 /swapfile
        
        # Initialize swap
        mkswap /swapfile >/dev/null 2>&1
        
        # Enable swap
        swapon /swapfile
        
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
    local mem_kb mem_gb zram_size
    if [[ -f /proc/meminfo ]]; then
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        mem_gb=$((mem_kb / 1024 / 1024))
    else
        mem_gb=2
    fi
    
    # Set size to 50% of RAM, minimum 512M
    local zram_mb=$((mem_gb * 1024 / 2))
    if [[ $zram_mb -lt 512 ]]; then
        zram_mb=512
    fi
    
    log_info "Setting up zram (${zram_mb}MB)..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Load zram module
        modprobe zram 2>/dev/null || true
        
        # Set compression algorithm (zstd preferred, fallback to lzo)
        local comp_algo="lzo"
        if [[ -f /sys/block/zram0/comp_algorithm ]]; then
            if grep -q "zstd" /sys/block/zram0/comp_algorithm 2>/dev/null; then
                comp_algo="zstd"
            fi
            echo "$comp_algo" > /sys/block/zram0/comp_algorithm 2>/dev/null || true
        fi
        
        log_verbose "Using compression algorithm: $comp_algo"
        
        # Set zram size
        if [[ -f /sys/block/zram0/disksize ]]; then
            echo "${zram_mb}M" > /sys/block/zram0/disksize 2>/dev/null || true
        fi
        
        # Initialize swap on zram
        mkswap /dev/zram0 >/dev/null 2>&1 || true
        swapon /dev/zram0 >/dev/null 2>&1 || true
        
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
