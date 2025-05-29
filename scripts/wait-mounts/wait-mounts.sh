#!/bin/bash

#===============================================================================
# LXC Container Mount Dependency Manager for Proxmox
#===============================================================================
# Description: Automated mount monitoring and container management tool
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script monitors specified mount points and manages LXC container
# lifecycle based on mount availability. It ensures containers that depend
# on network storage or external mounts only start when dependencies are met.
#
# Features:
# - Interactive and command-line configuration
# - Multiple mount point monitoring
# - Flexible container management
# - Color-coded output for better readability
# - Comprehensive error handling and validation
# - Automatic restart capabilities
# - Continuous monitoring mode
# - Detailed logging and status reporting
# - Graceful shutdown handling
#
# Usage: 
#   Interactive mode: sudo bash wait-mounts.sh
#   Command line: sudo bash wait-mounts.sh --mounts "/mnt/nfs,/mnt/cifs" --containers "101,102,103"
#   Config file: sudo bash wait-mounts.sh --config /path/to/config.conf
#
# Requirements: Must be run on Proxmox VE host with root privileges
#===============================================================================

# Script configuration
set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Secure Internal Field Separator

# Color definitions for enhanced output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_LOG_PATH="/var/log/wait-mounts.log"
readonly DEFAULT_CONFIG_PATH="/etc/wait-mounts.conf"
readonly DEFAULT_TIMEOUT=300
readonly DEFAULT_CHECK_INTERVAL=5

# Global variables
MOUNT_POINTS=()
CONTAINERS=()
TIMEOUT="$DEFAULT_TIMEOUT"
CHECK_INTERVAL="$DEFAULT_CHECK_INTERVAL"
LOG_PATH="$DEFAULT_LOG_PATH"
CONFIG_FILE=""
DAEMON_MODE=false
INTERACTIVE_MODE=true

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Print colored messages with different levels
print_info() {
    if [[ "$DAEMON_MODE" == false ]]; then
        echo -e "${BLUE}ℹ️  [INFO]${NC} $1"
    fi
}

print_success() {
    if [[ "$DAEMON_MODE" == false ]]; then
        echo -e "${GREEN}✅ [SUCCESS]${NC} $1"
    fi
}

print_warning() {
    if [[ "$DAEMON_MODE" == false ]]; then
        echo -e "${YELLOW}⚠️  [WARNING]${NC} $1"
    fi
}

print_error() {
    if [[ "$DAEMON_MODE" == false ]]; then
        echo -e "${RED}❌ [ERROR]${NC} $1" >&2
    fi
}

print_step() {
    if [[ "$DAEMON_MODE" == false ]]; then
        echo -e "${MAGENTA}🔧 [STEP]${NC} $1"
    fi
}

print_prompt() {
    if [[ "$DAEMON_MODE" == false ]]; then
        printf "${CYAN}📝 [INPUT]${NC} $1 "
    fi
}

# Display script header
show_header() {
    echo -e "${CYAN}"
    echo "==============================================================================="
    echo "             LXC CONTAINER MOUNT DEPENDENCY MANAGER"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "${WHITE}Proxmox VE Mount-Aware Container Management Tool${NC}"
    echo ""
}

# Get current timestamp in standardized format
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log message to both console and file
log_message() {
    local message="[$(get_timestamp)] $1"
    
    # Always log to file
    echo "$message" >> "$LOG_PATH"
    
    # Only output to console in non-daemon mode
    if [[ "$DAEMON_MODE" == false ]]; then
        echo "$message"
    fi
}

# Cleanup function for graceful shutdown
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Script terminated with exit code $exit_code"
        log_message "ERROR: Script terminated unexpectedly with exit code $exit_code"
    else
        if [[ "$DAEMON_MODE" == false ]]; then
            print_success "Script completed successfully"
        fi
        log_message "INFO: Script completed successfully"
    fi
    exit $exit_code
}

# Set up signal handlers for cleanup
trap cleanup EXIT INT TERM

# Display help information
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

This script monitors mount points and manages LXC container lifecycle based on
mount availability. It ensures containers start only when their dependencies are met.

OPTIONS:
    -m, --mounts PATHS          Comma-separated list of mount points to monitor
                               Example: "/mnt/nfs,/mnt/cifs,/mnt/storage"
    
    -c, --containers IDS        Comma-separated list of container IDs to manage
                               Example: "101,102,103"
    
    -t, --timeout SECONDS       Maximum time to wait for mounts (default: $DEFAULT_TIMEOUT)
    
    -i, --interval SECONDS      Check interval between mount tests (default: $DEFAULT_CHECK_INTERVAL)
    
    -l, --log PATH              Log file path (default: $DEFAULT_LOG_PATH)
    
    -f, --config FILE           Load configuration from file
    
    -d, --daemon                Run in daemon mode (non-interactive)
    
    -h, --help                  Show this help message

EXAMPLES:
    # Interactive mode
    $SCRIPT_NAME
    
    # Command line mode
    $SCRIPT_NAME --mounts "/mnt/nfs,/mnt/cifs" --containers "101,102"
    
    # Daemon mode with custom settings
    $SCRIPT_NAME --daemon --timeout 600 --interval 10
    
    # Using configuration file
    $SCRIPT_NAME --config /etc/wait-mounts.conf

CONFIGURATION FILE FORMAT:
    # Lines starting with # are comments
    MOUNT_POINTS="/mnt/nfs,/mnt/cifs,/mnt/storage"
    CONTAINERS="101,102,103,104"
    TIMEOUT=300
    CHECK_INTERVAL=5
    LOG_PATH="/var/log/wait-mounts.log"

EOF
}

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

# Check if running as root on Proxmox VE
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Usage: sudo $SCRIPT_NAME"
        exit 1
    fi
    
    # Check if running on Proxmox VE
    if ! command -v pct &> /dev/null; then
        print_error "This script must be run on a Proxmox VE host"
        print_info "The 'pct' command is not available"
        exit 1
    fi
    
    # Check required commands
    local deps=("mountpoint" "pct" "tee")
    local missing_deps=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing_deps[*]}"
        print_info "Please install the necessary packages and try again"
        exit 1
    fi
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_PATH")"
    
    print_success "Prerequisites check passed"
}

# Validate container ID
validate_container_id() {
    local id="$1"
    
    # Check if ID is numeric
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        print_error "Container ID must be numeric: $id"
        return 1
    fi
    
    # Check if container exists
    if ! pct status "$id" &> /dev/null; then
        print_error "Container with ID $id does not exist"
        return 1
    fi
    
    return 0
}

# Validate mount point path
validate_mount_point() {
    local mount_path="$1"
    
    # Check if path is absolute
    if [[ ! "$mount_path" =~ ^/ ]]; then
        print_error "Mount point must be an absolute path: $mount_path"
        return 1
    fi
    
    # Check if directory exists
    if [[ ! -d "$mount_path" ]]; then
        print_warning "Mount point directory does not exist: $mount_path"
        print_info "This might be normal if the mount is not yet active"
    fi
    
    return 0
}

#===============================================================================
# CONFIGURATION FUNCTIONS
#===============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mounts)
                IFS=',' read -ra MOUNT_POINTS <<< "$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            -c|--containers)
                IFS=',' read -ra CONTAINERS <<< "$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -i|--interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            -l|--log)
                LOG_PATH="$2"
                shift 2
                ;;
            -f|--config)
                CONFIG_FILE="$2"
                INTERACTIVE_MODE=false
                shift 2
                ;;
            -d|--daemon)
                DAEMON_MODE=true
                INTERACTIVE_MODE=false
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Load configuration from file
load_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    print_step "Loading configuration from: $config_file"
    
    # Source the config file in a safe way
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Clean the key (remove whitespace)
        key=$(echo "$key" | tr -d ' ')
        
        case "$key" in
            MOUNT_POINTS)
                # Handle both array syntax and comma-separated values
                if [[ "$value" =~ ^\(.*\)$ ]]; then
                    # Array syntax: MOUNT_POINTS=("/path1" "/path2")
                    # Remove parentheses and extract quoted values
                    value=${value#(}  # Remove leading (
                    value=${value%)}  # Remove trailing )
                    # Parse quoted strings in the array
                    local temp_array=()
                    while [[ $value =~ \"([^\"]+)\" ]]; do
                        temp_array+=("${BASH_REMATCH[1]}")
                        value=${value#*\"${BASH_REMATCH[1]}\"}
                    done
                    MOUNT_POINTS=("${temp_array[@]}")
                else
                    # Comma-separated syntax: MOUNT_POINTS="/path1,/path2"
                    value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
                    IFS=',' read -ra MOUNT_POINTS <<< "$value"
                fi
                ;;
            CONTAINERS)
                # Clean quotes for containers (comma-separated only)
                value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
                IFS=',' read -ra CONTAINERS <<< "$value"
                ;;
            TIMEOUT)
                value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
                TIMEOUT="$value"
                ;;
            CHECK_INTERVAL)
                value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
                CHECK_INTERVAL="$value"
                ;;
            LOG_PATH)
                value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
                LOG_PATH="$value"
                ;;
        esac
    done < "$config_file"
    
    print_success "Configuration loaded successfully"
}

# Get mount points interactively
get_mount_points() {
    print_info "Mount Point Configuration"
    print_info "Enter mount points that containers depend on (one per line)"
    print_info "Examples: /mnt/nfs, /mnt/cifs, /mnt/storage"
    print_info "Press Enter on empty line to finish"
    echo ""
    
    local mount_point
    while true; do
        print_prompt "Mount point path (or Enter to finish):"
        read -r mount_point
        
        if [[ -z "$mount_point" ]]; then
            if [[ ${#MOUNT_POINTS[@]} -eq 0 ]]; then
                print_warning "At least one mount point is required"
                continue
            else
                break
            fi
        fi
        
        if validate_mount_point "$mount_point"; then
            MOUNT_POINTS+=("$mount_point")
            print_success "Added mount point: $mount_point"
        fi
        echo ""
    done
}

# Get container IDs interactively
get_container_ids() {
    print_info "Container Configuration"
    print_info "Enter LXC container IDs to manage (one per line)"
    print_info "These containers will be restarted when mounts become available"
    print_info "Press Enter on empty line to finish"
    echo ""
    
    local container_id
    while true; do
        print_prompt "Container ID (or Enter to finish):"
        read -r container_id
        
        if [[ -z "$container_id" ]]; then
            if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
                print_warning "At least one container ID is required"
                continue
            else
                break
            fi
        fi
        
        if validate_container_id "$container_id"; then
            CONTAINERS+=("$container_id")
            print_success "Added container: $container_id"
        fi
        echo ""
    done
}

# Get additional settings interactively
get_settings() {
    echo ""
    print_info "Additional Settings"
    
    print_prompt "Timeout in seconds (default: $DEFAULT_TIMEOUT):"
    read -r timeout_input
    if [[ -n "$timeout_input" && "$timeout_input" =~ ^[0-9]+$ ]]; then
        TIMEOUT="$timeout_input"
    fi
    
    print_prompt "Check interval in seconds (default: $DEFAULT_CHECK_INTERVAL):"
    read -r interval_input
    if [[ -n "$interval_input" && "$interval_input" =~ ^[0-9]+$ ]]; then
        CHECK_INTERVAL="$interval_input"
    fi
    
    print_prompt "Log file path (default: $DEFAULT_LOG_PATH):"
    read -r log_input
    if [[ -n "$log_input" ]]; then
        LOG_PATH="$log_input"
    fi
}

#===============================================================================
# MOUNT MONITORING FUNCTIONS
#===============================================================================

# Check if all required mount points are active
check_mounts() {
    local all_mounted=true
    local status=""
    
    for mount_point in "${MOUNT_POINTS[@]}"; do
        if mountpoint -q "$mount_point" 2>/dev/null; then
            status+="Mount $mount_point: ${GREEN}ACTIVE${NC}\n"
        else
            status+="Mount $mount_point: ${RED}NOT MOUNTED${NC}\n"
            all_mounted=false
        fi
    done
    
    # Print status to console if running in terminal
    if [[ -t 1 && "$DAEMON_MODE" == false ]]; then
        echo -e "$status"
    fi
    
    # Return result
    $all_mounted
}

# Display current configuration
show_configuration() {
    echo ""
    print_info "Current Configuration Summary"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Mount Points: ${MOUNT_POINTS[*]}"
    print_info "Containers: ${CONTAINERS[*]}"
    print_info "Timeout: ${TIMEOUT}s"
    print_info "Check Interval: ${CHECK_INTERVAL}s"
    print_info "Log Path: $LOG_PATH"
    print_info "Mode: $([ "$DAEMON_MODE" == true ] && echo "Daemon" || echo "Interactive")"
    echo ""
}

#===============================================================================
# CONTAINER MANAGEMENT FUNCTIONS
#===============================================================================

# Stop container safely
stop_container_safely() {
    local ctid="$1"
    
    print_step "Stopping container $ctid..."
    log_message "INFO: Stopping container $ctid"
    
    if ! pct stop "$ctid" 2>/dev/null; then
        print_warning "Failed to stop container $ctid gracefully, attempting force stop..."
        log_message "WARNING: Failed to stop container $ctid gracefully"
        
        if ! pct stop "$ctid" --force 2>/dev/null; then
            print_error "Failed to force stop container $ctid"
            log_message "ERROR: Failed to force stop container $ctid"
            return 1
        fi
    fi
    
    print_success "Container $ctid stopped successfully"
    log_message "SUCCESS: Container $ctid stopped successfully"
    return 0
}

# Start container
start_container() {
    local ctid="$1"
    
    print_step "Starting container $ctid..."
    log_message "INFO: Starting container $ctid"
    
    if ! pct start "$ctid" 2>/dev/null; then
        print_error "Failed to start container $ctid"
        log_message "ERROR: Failed to start container $ctid"
        return 1
    fi
    
    print_success "Container $ctid started successfully"
    log_message "SUCCESS: Container $ctid started successfully"
    return 0
}

# Restart all configured containers
restart_containers() {
    print_step "Restarting all configured containers..."
    log_message "INFO: Starting container restart process"
    
    local failed_containers=()
    
    for ctid in "${CONTAINERS[@]}"; do
        print_step "Processing container $ctid..."
        
        # Check current status
        local status
        status=$(pct status "$ctid" 2>/dev/null || echo "unknown")
        
        if [[ "$status" =~ running ]]; then
            if ! stop_container_safely "$ctid"; then
                failed_containers+=("$ctid")
                continue
            fi
            # Small delay to ensure proper shutdown
            sleep 2
        fi
        
        if ! start_container "$ctid"; then
            failed_containers+=("$ctid")
            continue
        fi
        
        log_message "SUCCESS: Container $ctid processed successfully"
    done
    
    if [[ ${#failed_containers[@]} -eq 0 ]]; then
        print_success "All containers processed successfully"
        log_message "SUCCESS: All containers processed successfully"
        return 0
    else
        print_warning "Some containers failed to restart: ${failed_containers[*]}"
        log_message "WARNING: Failed containers: ${failed_containers[*]}"
        return 1
    fi
}

#===============================================================================
# MONITORING FUNCTIONS
#===============================================================================

# Main monitoring loop
monitor_mounts() {
    print_step "Starting mount monitoring process..."
    log_message "INFO: Starting mount monitoring for: ${MOUNT_POINTS[*]}"
    log_message "INFO: Managing containers: ${CONTAINERS[*]}"
    log_message "INFO: Timeout set to $TIMEOUT seconds"
    
    local monitoring_active=true
    
    while [[ "$monitoring_active" == true ]]; do
        # Start timer for this cycle
        local cycle_start=$SECONDS
        local cycle_timeout=$((cycle_start + TIMEOUT))
        
        print_step "Waiting for all mounts to become available..."
        
        # Wait for mounts with timeout
        while [[ $SECONDS -lt $cycle_timeout ]]; do
            local elapsed=$((SECONDS - cycle_start))
            local remaining=$((TIMEOUT - elapsed))
            
            if [[ "$DAEMON_MODE" == false && -t 1 ]]; then
                print_info "Time elapsed: ${elapsed}s | Remaining: ${remaining}s"
            fi
            
            # Check if all required mounts are available
            if check_mounts; then
                print_success "All mounts detected! Processing containers..."
                log_message "SUCCESS: All required mounts are now available"
                
                if restart_containers; then
                    print_success "Container restart cycle completed successfully"
                    
                    # Enter continuous monitoring mode
                    print_step "Entering continuous monitoring mode..."
                    log_message "INFO: Entering continuous monitoring mode"
                    
                    continuous_monitor
                    
                    # If we exit continuous monitoring, it means mounts failed
                    # Start a new cycle
                    break
                else
                    print_warning "Some containers failed to restart"
                    log_message "WARNING: Container restart cycle completed with errors"
                fi
                
                # Continue monitoring after successful restart
                break
            else
                if [[ "$DAEMON_MODE" == false ]]; then
                    print_info "Mounts not ready. Retrying in $CHECK_INTERVAL seconds..."
                fi
                sleep "$CHECK_INTERVAL"
            fi
        done
        
        # Check if we timed out
        if [[ $SECONDS -ge $cycle_timeout ]]; then
            print_error "TIMEOUT REACHED after $TIMEOUT seconds"
            log_message "ERROR: Timeout reached - required mounts not available after $TIMEOUT seconds"
            
            if [[ "$DAEMON_MODE" == true ]]; then
                print_warning "Daemon mode: restarting monitoring cycle..."
                log_message "WARNING: Daemon mode - restarting monitoring cycle"
                continue
            else
                print_error "Interactive mode: exiting due to timeout"
                log_message "ERROR: Interactive mode - exiting due to timeout"
                exit 1
            fi
        fi
    done
}

# Continuous monitoring after initial success
continuous_monitor() {
    print_info "Continuous monitoring active - checking every 60 seconds"
    log_message "INFO: Continuous monitoring activated"
    
    local last_log_time=$(date +%s)
    local log_interval=600  # Log every 10 minutes
    
    while true; do
        sleep 60
        
        # Check mount status
        if ! check_mounts; then
            print_warning "One or more mounts have disconnected!"
            log_message "WARNING: Mount disconnection detected"
            print_info "Will attempt to restore containers when mounts are available again"
            log_message "INFO: Returning to main monitoring loop"
            
            # Return to main monitoring loop
            return
        fi
        
        # Periodic status log (every 10 minutes)
        local current_time=$(date +%s)
        if [[ $((current_time - last_log_time)) -ge $log_interval ]]; then
            log_message "INFO: Continuous monitoring - all mounts active"
            last_log_time=$current_time
        fi
    done
}

#===============================================================================
# MAIN EXECUTION FUNCTION
#===============================================================================

# Main function that orchestrates the monitoring process
main() {
    # Parse command line arguments first
    parse_arguments "$@"
    
    # Show header only in interactive mode
    if [[ "$DAEMON_MODE" == false ]]; then
        show_header
    fi
    
    # Load configuration from file if specified
    if [[ -n "$CONFIG_FILE" ]]; then
        load_config_file "$CONFIG_FILE"
    fi
    
    # Prerequisites check
    check_prerequisites
    
    # Get configuration interactively if needed
    if [[ "$INTERACTIVE_MODE" == true ]]; then
        if [[ ${#MOUNT_POINTS[@]} -eq 0 ]]; then
            get_mount_points
        fi
        
        if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
            get_container_ids
        fi
        
        get_settings
    fi
    
    # Validate configuration
    if [[ ${#MOUNT_POINTS[@]} -eq 0 ]]; then
        print_error "No mount points specified"
        show_help
        exit 1
    fi
    
    if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
        print_error "No container IDs specified"
        show_help
        exit 1
    fi
    
    # Validate all mount points
    for mount_point in "${MOUNT_POINTS[@]}"; do
        validate_mount_point "$mount_point"
    done
    
    # Validate all container IDs
    for container_id in "${CONTAINERS[@]}"; do
        if ! validate_container_id "$container_id"; then
            exit 1
        fi
    done
    
    # Show configuration only in interactive mode
    if [[ "$DAEMON_MODE" == false ]]; then
        show_configuration
    fi
    
    # Confirmation prompt for interactive mode only
    if [[ "$INTERACTIVE_MODE" == true && "$DAEMON_MODE" == false ]]; then
        echo ""
        print_warning "⚠️  IMPORTANT NOTICE ⚠️"
        print_warning "This script will monitor mount points and restart containers automatically"
        print_warning "Ensure this is the desired behavior before proceeding"
        echo ""
        
        print_prompt "Proceed with mount monitoring? (y/N):"
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Initialize logging
    log_message "INFO: ===== Mount monitoring session started ====="
    log_message "INFO: Script version 2.0"
    log_message "INFO: Monitoring mounts: ${MOUNT_POINTS[*]}"
    log_message "INFO: Managing containers: ${CONTAINERS[*]}"
    
    # Start monitoring
    print_step "Starting mount dependency monitoring..."
    monitor_mounts
}

#===============================================================================
# SCRIPT ENTRY POINT
#===============================================================================

# Execute main function with all arguments
main "$@"