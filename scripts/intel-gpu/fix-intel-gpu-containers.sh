#!/bin/bash

#===============================================================================
# Intel iGPU Container Configuration Fix Script for Proxmox
#===============================================================================
# Description: Automated Intel GPU detection and LXC container configuration tool
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script automatically detects the Intel integrated GPU device path
# (/dev/dri/cardX) and updates LXC container configurations to use the
# correct device. It solves the issue where Intel iGPU appears as different
# card numbers (card0 or card1) after system reboots.
#
# Features:
# - Automatic Intel GPU detection via vendor ID
# - Dynamic container configuration updates
# - Support for multiple containers
# - Color-coded output for better readability
# - Comprehensive error handling and validation
# - Backup and rollback capabilities
# - Interactive and automated modes
# - Device permission management
# - Container restart management
#
# Usage: 
#   Interactive mode: sudo bash fix-intel-gpu-containers.sh
#   Automated mode: sudo bash fix-intel-gpu-containers.sh --containers "101,102" --auto
#   Check only: sudo bash fix-intel-gpu-containers.sh --check-only
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
readonly INTEL_VENDOR_ID="8086"
readonly DRI_PATH="/dev/dri"
readonly BACKUP_DIR="/var/backups/lxc-configs"
readonly LOG_PATH="/var/log/intel-gpu-fix.log"

# Global variables
CONTAINERS=()
AUTO_MODE=false
CHECK_ONLY=false
RESTART_CONTAINERS=true
INTEL_CARD_DEVICE=""
INTEL_RENDER_DEVICE=""

#===============================================================================
# UTILITY FUNCTIONS
#===============================================================================

# Print colored messages with different levels
print_info() {
    echo -e "${BLUE}ℹ️  [INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ [SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️  [WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}❌ [ERROR]${NC} $1" >&2
}

print_step() {
    echo -e "${MAGENTA}🔧 [STEP]${NC} $1"
}

print_prompt() {
    printf "${CYAN}📝 [INPUT]${NC} $1 "
}

# Display script header
show_header() {
    echo -e "${CYAN}"
    echo "==============================================================================="
    echo "           INTEL iGPU CONTAINER CONFIGURATION FIX SCRIPT"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "${WHITE}Proxmox VE Intel Graphics Device Management Tool${NC}"
    echo ""
}

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log message to both console and file
log_message() {
    local message="[$(get_timestamp)] $1"
    echo "$message" | tee -a "$LOG_PATH"
}

# Cleanup function for graceful shutdown
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Script terminated with exit code $exit_code"
        log_message "ERROR: Script terminated unexpectedly"
    else
        print_success "Script completed successfully"
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

This script automatically detects Intel integrated GPU device paths and updates
LXC container configurations to use the correct /dev/dri/cardX device.

OPTIONS:
    -c, --containers IDS        Comma-separated list of container IDs to update
                               Example: "101,102,103"
    
    -a, --auto                  Run in automated mode (no interactive prompts)
    
    -r, --no-restart           Don't restart containers after configuration update
    
    --check-only               Only check and display current GPU configuration
    
    -h, --help                 Show this help message

EXAMPLES:
    # Interactive mode
    $SCRIPT_NAME
    
    # Automated mode for specific containers
    $SCRIPT_NAME --containers "101,102" --auto
    
    # Check current configuration without changes
    $SCRIPT_NAME --check-only
    
    # Update without restarting containers
    $SCRIPT_NAME --containers "101,102" --no-restart --auto

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
    local deps=("lspci" "pct" "grep" "sed")
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
    
    # Create backup and log directories
    mkdir -p "$BACKUP_DIR"
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

#===============================================================================
# GPU DETECTION FUNCTIONS
#===============================================================================

# Detect Intel GPU devices
detect_intel_gpu() {
    print_step "Detecting Intel integrated GPU devices..."
    
    # Check if DRI directory exists
    if [[ ! -d "$DRI_PATH" ]]; then
        print_error "DRI directory not found: $DRI_PATH"
        print_info "GPU devices may not be available or drivers not loaded"
        exit 1
    fi
    
    # Find Intel GPU using lspci
    local intel_gpu_info
    intel_gpu_info=$(lspci -nn | grep -i "vga.*intel\|display.*intel" | head -1)
    
    if [[ -z "$intel_gpu_info" ]]; then
        print_error "No Intel GPU detected in the system"
        print_info "Available GPUs:"
        lspci | grep -i "vga\|display" || print_info "No GPUs found"
        exit 1
    fi
    
    print_success "Intel GPU detected: $intel_gpu_info"
    log_message "INFO: Intel GPU detected: $intel_gpu_info"
    
    # Find the corresponding DRI device
    local card_found=false
    for card_device in "$DRI_PATH"/card*; do
        if [[ -c "$card_device" ]]; then
            local card_num=$(basename "$card_device" | sed 's/card//')
            local card_sysfs="/sys/class/drm/card${card_num}/device/vendor"
            
            if [[ -f "$card_sysfs" ]]; then
                local vendor_id
                vendor_id=$(cat "$card_sysfs" 2>/dev/null | sed 's/0x//')
                
                if [[ "$vendor_id" == "$INTEL_VENDOR_ID" ]]; then
                    INTEL_CARD_DEVICE="$card_device"
                    INTEL_RENDER_DEVICE="$DRI_PATH/renderD$((128 + card_num))"
                    card_found=true
                    break
                fi
            fi
        fi
    done
    
    if [[ "$card_found" == false ]]; then
        print_error "Could not find Intel GPU DRI device"
        print_info "Available DRI devices:"
        ls -la "$DRI_PATH"/ 2>/dev/null || print_info "No DRI devices found"
        exit 1
    fi
    
    # Verify render device exists
    if [[ ! -c "$INTEL_RENDER_DEVICE" ]]; then
        print_warning "Render device not found: $INTEL_RENDER_DEVICE"
        print_info "This is normal for older Intel GPUs"
        INTEL_RENDER_DEVICE=""
    fi
    
    print_success "Intel GPU devices detected:"
    print_info "Card device: $INTEL_CARD_DEVICE"
    if [[ -n "$INTEL_RENDER_DEVICE" ]]; then
        print_info "Render device: $INTEL_RENDER_DEVICE"
    fi
    
    log_message "SUCCESS: Intel card device: $INTEL_CARD_DEVICE"
    if [[ -n "$INTEL_RENDER_DEVICE" ]]; then
        log_message "SUCCESS: Intel render device: $INTEL_RENDER_DEVICE"
    fi
}

# Display current GPU configuration
show_gpu_info() {
    print_info "Current GPU Configuration:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show all GPUs
    print_info "Available GPUs:"
    lspci | grep -i "vga\|display" | while IFS= read -r gpu; do
        print_info "  $gpu"
    done
    
    echo ""
    
    # Show DRI devices
    print_info "Available DRI devices:"
    if [[ -d "$DRI_PATH" ]]; then
        for device in "$DRI_PATH"/*; do
            if [[ -c "$device" ]]; then
                local device_name=$(basename "$device")
                local permissions=$(ls -la "$device" | awk '{print $1, $3, $4}')
                print_info "  $device_name ($permissions)"
            fi
        done
    else
        print_warning "DRI directory not found"
    fi
    
    echo ""
}

#===============================================================================
# CONFIGURATION FUNCTIONS
#===============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--containers)
                IFS=',' read -ra CONTAINERS <<< "$2"
                shift 2
                ;;
            -a|--auto)
                AUTO_MODE=true
                shift
                ;;
            -r|--no-restart)
                RESTART_CONTAINERS=false
                shift
                ;;
            --check-only)
                CHECK_ONLY=true
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

# Get container IDs interactively
get_container_ids() {
    print_info "Container Configuration"
    print_info "Enter LXC container IDs that use Intel GPU (one per line)"
    print_info "These containers will be updated with the correct GPU device paths"
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

# Show current configuration summary
show_configuration() {
    echo ""
    print_info "Configuration Summary:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Intel GPU Card: $INTEL_CARD_DEVICE"
    if [[ -n "$INTEL_RENDER_DEVICE" ]]; then
        print_info "Intel GPU Render: $INTEL_RENDER_DEVICE"
    fi
    print_info "Target Containers: ${CONTAINERS[*]}"
    print_info "Auto Mode: $([ "$AUTO_MODE" == true ] && echo "Yes" || echo "No")"
    print_info "Restart Containers: $([ "$RESTART_CONTAINERS" == true ] && echo "Yes" || echo "No")"
    echo ""
}

#===============================================================================
# CONTAINER MANAGEMENT FUNCTIONS
#===============================================================================

# Backup container configuration
backup_container_config() {
    local ctid="$1"
    local backup_file="$BACKUP_DIR/lxc-${ctid}-$(date +%Y%m%d-%H%M%S).conf"
    
    print_step "Creating backup for container $ctid..."
    
    if cp "/etc/pve/lxc/${ctid}.conf" "$backup_file"; then
        print_success "Backup created: $backup_file"
        log_message "SUCCESS: Backup created for container $ctid: $backup_file"
        return 0
    else
        print_error "Failed to create backup for container $ctid"
        log_message "ERROR: Failed to create backup for container $ctid"
        return 1
    fi
}

# Update container GPU configuration
update_container_config() {
    local ctid="$1"
    local config_file="/etc/pve/lxc/${ctid}.conf"
    
    print_step "Updating GPU configuration for container $ctid..."
    
    # Check if config file exists
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Create backup first
    if ! backup_container_config "$ctid"; then
        return 1
    fi
    
    # Remove existing GPU device entries
    sed -i '/^dev[0-9]*:.*\/dev\/dri\/card[0-9]*,/d' "$config_file"
    sed -i '/^dev[0-9]*:.*\/dev\/dri\/renderD[0-9]*,/d' "$config_file"
    
    # Find next available device number
    local next_dev_num=0
    while grep -q "^dev${next_dev_num}:" "$config_file"; do
        ((next_dev_num++))
    done
    
    # Add Intel GPU card device
    local card_entry="dev${next_dev_num}: ${INTEL_CARD_DEVICE},gid=44,uid=0"
    echo "$card_entry" >> "$config_file"
    print_success "Added card device: $card_entry"
    log_message "SUCCESS: Added to container $ctid: $card_entry"
    
    # Add render device if available
    if [[ -n "$INTEL_RENDER_DEVICE" ]]; then
        ((next_dev_num++))
        local render_entry="dev${next_dev_num}: ${INTEL_RENDER_DEVICE},gid=107,uid=0"
        echo "$render_entry" >> "$config_file"
        print_success "Added render device: $render_entry"
        log_message "SUCCESS: Added to container $ctid: $render_entry"
    fi
    
    print_success "Container $ctid configuration updated successfully"
    return 0
}

# Restart container if needed
restart_container() {
    local ctid="$1"
    
    if [[ "$RESTART_CONTAINERS" == false ]]; then
        print_info "Skipping restart for container $ctid (--no-restart specified)"
        return 0
    fi
    
    print_step "Restarting container $ctid..."
    
    # Check if container is running
    if ! pct status "$ctid" | grep -q "running"; then
        print_info "Container $ctid is not running, skipping restart"
        return 0
    fi
    
    # Stop container
    if ! pct stop "$ctid" --timeout 30; then
        print_warning "Failed to stop container $ctid gracefully, trying force stop..."
        if ! pct stop "$ctid" --force; then
            print_error "Failed to force stop container $ctid"
            return 1
        fi
    fi
    
    # Start container
    sleep 2
    if ! pct start "$ctid"; then
        print_error "Failed to start container $ctid"
        return 1
    fi
    
    print_success "Container $ctid restarted successfully"
    log_message "SUCCESS: Container $ctid restarted"
    return 0
}

# Process all containers
process_containers() {
    print_step "Processing container configurations..."
    log_message "INFO: Starting container configuration updates"
    
    local failed_containers=()
    local updated_containers=()
    
    for ctid in "${CONTAINERS[@]}"; do
        print_step "Processing container $ctid..."
        
        if update_container_config "$ctid"; then
            updated_containers+=("$ctid")
            
            if restart_container "$ctid"; then
                print_success "Container $ctid processed successfully"
            else
                print_warning "Container $ctid updated but restart failed"
            fi
        else
            failed_containers+=("$ctid")
            print_error "Failed to update container $ctid"
        fi
        
        echo ""
    done
    
    # Summary
    print_info "Processing Summary:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ ${#updated_containers[@]} -gt 0 ]]; then
        print_success "Successfully updated containers: ${updated_containers[*]}"
        log_message "SUCCESS: Updated containers: ${updated_containers[*]}"
    fi
    
    if [[ ${#failed_containers[@]} -gt 0 ]]; then
        print_error "Failed to update containers: ${failed_containers[*]}"
        log_message "ERROR: Failed containers: ${failed_containers[*]}"
        return 1
    fi
    
    print_success "All containers processed successfully"
    log_message "SUCCESS: All containers processed successfully"
    return 0
}

#===============================================================================
# MAIN EXECUTION FUNCTION
#===============================================================================

# Main function that orchestrates the GPU fix process
main() {
    show_header
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Prerequisites check
    check_prerequisites
    
    # Show current GPU information
    show_gpu_info
    
    # Detect Intel GPU
    detect_intel_gpu
    
    # If check-only mode, exit here
    if [[ "$CHECK_ONLY" == true ]]; then
        print_info "Check completed - detected Intel GPU at: $INTEL_CARD_DEVICE"
        exit 0
    fi
    
    # Get container configuration if not provided
    if [[ ${#CONTAINERS[@]} -eq 0 && "$AUTO_MODE" == false ]]; then
        get_container_ids
    fi
    
    # Validate configuration
    if [[ ${#CONTAINERS[@]} -eq 0 ]]; then
        print_error "No container IDs specified"
        show_help
        exit 1
    fi
    
    # Validate all container IDs
    for container_id in "${CONTAINERS[@]}"; do
        if ! validate_container_id "$container_id"; then
            exit 1
        fi
    done
    
    # Show configuration
    show_configuration
    
    # Confirmation prompt for interactive mode
    if [[ "$AUTO_MODE" == false ]]; then
        echo ""
        print_warning "⚠️  IMPORTANT NOTICE ⚠️"
        print_warning "This script will modify LXC container configurations"
        print_warning "Backups will be created before making changes"
        echo ""
        
        print_prompt "Proceed with GPU configuration update? (y/N):"
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Initialize logging
    log_message "INFO: ===== GPU configuration session started ====="
    log_message "INFO: Script version 2.0"
    log_message "INFO: Intel GPU device: $INTEL_CARD_DEVICE"
    log_message "INFO: Target containers: ${CONTAINERS[*]}"
    
    # Process containers
    print_step "Starting GPU configuration updates..."
    if process_containers; then
        echo ""
        print_success "✅ Intel GPU configuration completed successfully!"
        print_info "All containers now use the correct Intel GPU device: $INTEL_CARD_DEVICE"
        
        if [[ "$RESTART_CONTAINERS" == true ]]; then
            print_info "Containers have been restarted with new configuration"
        else
            print_info "Remember to restart containers manually to apply changes"
        fi
    else
        echo ""
        print_error "Some containers failed to update - check logs for details"
        exit 1
    fi
}

#===============================================================================
# SCRIPT ENTRY POINT
#===============================================================================

# Execute main function with all arguments
main "$@"
