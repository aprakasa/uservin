#!/bin/bash
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
    
    if bash -c "$cmd"; then
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
        # shellcheck source=/dev/null
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
