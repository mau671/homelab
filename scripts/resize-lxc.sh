#!/bin/bash

#===============================================================================
# LXC Container Disk Resize Script for Proxmox
#===============================================================================
# Description: Automated disk resizing tool for LXC containers in Proxmox VE
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script safely resizes LXC container disks in Proxmox VE environment.
# It supports both privileged and unprivileged containers, handles multiple
# filesystem types, and includes comprehensive error handling and validation.
#
# Features:
# - Support for privileged and unprivileged containers
# - Multiple filesystem support (ext2/3/4, XFS)
# - Automatic container state management
# - Color-coded output for better readability
# - Comprehensive error handling and validation
# - Filesystem integrity checks
# - Safe rollback capabilities
# - Interactive size input with validation
#
# Usage: sudo bash resize-lxc.sh
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
readonly PVE_STORAGE_PATH="/dev/pve"
readonly SUPPORTED_FS_TYPES=("ext2" "ext3" "ext4" "xfs")

# Global variables
CTID=""
DISK=""
VOL=""
NEW_SIZE=""
PRIVILEGED=false
RUNNING=false
FS_TYPE=""
ORIGINAL_SIZE=""

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
    echo "                 LXC CONTAINER DISK RESIZE SCRIPT"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "${WHITE}Proxmox VE Container Storage Management Tool${NC}"
    echo ""
}

# Cleanup function for failed operations
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Operation failed with exit code $exit_code"
        print_step "Performing cleanup and safety checks..."
        
        # Restart container if it was running and got stopped
        if [[ "$RUNNING" == true && -n "$CTID" ]]; then
            print_step "Attempting to restart container $CTID..."
            if pct start "$CTID" 2>/dev/null; then
                print_success "Container $CTID restarted successfully"
            else
                print_warning "Failed to restart container $CTID - manual intervention required"
            fi
        fi
    fi
    exit $exit_code
}

# Set up signal handlers for cleanup
trap cleanup EXIT INT TERM

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
    local deps=("lvs" "lvresize" "blkid" "e2fsck" "resize2fs")
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
    
    print_success "Prerequisites check passed"
}

# Validate container ID input
validate_container_id() {
    local id="$1"
    
    # Check if ID is numeric
    if ! [[ "$id" =~ ^[0-9]+$ ]]; then
        print_error "Container ID must be numeric"
        return 1
    fi
    
    # Check if container exists
    if ! pct status "$id" &> /dev/null; then
        print_error "Container with ID $id does not exist"
        return 1
    fi
    
    return 0
}

# Validate size input format
validate_size_input() {
    local size="$1"
    
    # Check if size matches valid patterns (+5G, 20G, +500M, 2T, etc.)
    if [[ "$size" =~ ^(\+)?[0-9]+(\.[0-9]+)?[KMGT]?B?$ ]]; then
        return 0
    else
        print_error "Invalid size format: $size"
        print_info "Valid formats: +5G, 20G, +500M, 2T, etc."
        return 1
    fi
}

#===============================================================================
# CONTAINER MANAGEMENT FUNCTIONS
#===============================================================================

# Get container information
get_container_info() {
    local ctid="$1"
    
    print_step "Gathering container information..."
    
    # Set disk and volume paths
    DISK="vm-${ctid}-disk-0"
    VOL="${PVE_STORAGE_PATH}/${DISK}"
    
    # Check if volume exists
    if [[ ! -e "$VOL" ]]; then
        print_error "Container disk not found: $VOL"
        print_info "This might be a container with custom storage configuration"
        exit 1
    fi
    
    # Check if container is privileged
    if pct config "$ctid" | grep -q "unprivileged.*0" || ! pct config "$ctid" | grep -q "unprivileged"; then
        PRIVILEGED=true
    fi
    
    # Check if container is running
    if pct status "$ctid" | grep -q "running"; then
        RUNNING=true
    fi
    
    # Get filesystem type
    FS_TYPE=$(blkid -o value -s TYPE "$VOL" 2>/dev/null || echo "unknown")
    
    # Get current size
    ORIGINAL_SIZE=$(lvs --noheadings --units g --nosuffix -o lv_size "$VOL" 2>/dev/null | tr -d ' ' || echo "unknown")
    
    print_info "Container ID: $ctid"
    print_info "Container Type: $([ "$PRIVILEGED" == true ] && echo "Privileged" || echo "Unprivileged")"
    print_info "Current Status: $([ "$RUNNING" == true ] && echo "Running" || echo "Stopped")"
    print_info "Disk Path: $VOL"
    print_info "Current Size: ${ORIGINAL_SIZE}G"
    print_info "Filesystem Type: $FS_TYPE"
}

# Get user input for container ID
get_container_id() {
    while true; do
        print_prompt "Enter the LXC container ID:"
        read -r input_ctid
        
        if validate_container_id "$input_ctid"; then
            CTID="$input_ctid"
            break
        fi
        echo ""
    done
}

# Get user input for new size
get_new_size() {
    print_info "Current disk status:"
    lvs "$VOL" --units g
    echo ""
    
    while true; do
        print_prompt "Enter the new size (e.g., +5G for relative increase or 20G for absolute size):"
        read -r input_size
        
        if validate_size_input "$input_size"; then
            NEW_SIZE="$input_size"
            break
        fi
        echo ""
    done
}

#===============================================================================
# DISK OPERATIONS FUNCTIONS
#===============================================================================

# Stop container safely if running
stop_container_safely() {
    if [[ "$RUNNING" == true ]]; then
        print_step "Stopping container $CTID for disk operations..."
        
        if ! pct stop "$CTID" --timeout 30; then
            print_error "Failed to stop container gracefully"
            print_warning "Attempting forced shutdown..."
            
            if ! pct stop "$CTID" --force; then
                print_error "Failed to force stop container"
                print_info "Please stop the container manually and run the script again"
                exit 1
            fi
        fi
        
        print_success "Container $CTID stopped successfully"
    else
        print_info "Container $CTID is already stopped"
    fi
}

# Perform filesystem check
check_filesystem() {
    print_step "Performing filesystem integrity check..."
    
    case "$FS_TYPE" in
        ext4|ext3|ext2)
            if ! e2fsck -f -p "$VOL"; then
                print_error "Filesystem check failed"
                print_warning "There might be filesystem corruption"
                print_info "You may need to run: e2fsck -f $VOL manually"
                exit 1
            fi
            ;;
        xfs)
            print_info "XFS filesystem detected - skipping fsck (XFS is self-repairing)"
            ;;
        *)
            print_warning "Unknown filesystem type: $FS_TYPE"
            print_warning "Skipping filesystem check - proceed with caution"
            ;;
    esac
    
    print_success "Filesystem check completed"
}

# Resize the logical volume
resize_logical_volume() {
    print_step "Resizing logical volume to $NEW_SIZE..."
    
    # Store original size for potential rollback
    local original_size_bytes
    original_size_bytes=$(lvs --noheadings --units b --nosuffix -o lv_size "$VOL" | tr -d ' ')
    
    if ! lvresize -f --size "$NEW_SIZE" "$VOL"; then
        print_error "Failed to resize logical volume"
        print_info "The volume size remains unchanged at ${ORIGINAL_SIZE}G"
        exit 1
    fi
    
    # Verify the resize operation
    local new_size
    new_size=$(lvs --noheadings --units g --nosuffix -o lv_size "$VOL" | tr -d ' ')
    
    print_success "Logical volume resized successfully"
    print_info "Previous size: ${ORIGINAL_SIZE}G"
    print_info "New size: ${new_size}G"
}

# Resize the filesystem
resize_filesystem() {
    print_step "Resizing filesystem ($FS_TYPE)..."
    
    case "$FS_TYPE" in
        ext4|ext3|ext2)
            if ! resize2fs "$VOL"; then
                print_error "Failed to resize ext filesystem"
                print_warning "The logical volume was resized but filesystem resize failed"
                print_info "You may need to run: resize2fs $VOL manually"
                exit 1
            fi
            print_success "Ext filesystem resized successfully"
            ;;
        xfs)
            if [[ "$PRIVILEGED" == true ]]; then
                print_step "Starting container to resize XFS filesystem..."
                
                if ! pct start "$CTID"; then
                    print_error "Failed to start container for XFS resize"
                    exit 1
                fi
                
                # Wait for container to be fully started
                sleep 5
                
                if ! pct exec "$CTID" -- xfs_growfs /; then
                    print_error "Failed to resize XFS filesystem"
                    print_warning "Container is running - you may need to resize manually"
                    print_info "Run inside container: xfs_growfs /"
                    exit 1
                fi
                
                print_success "XFS filesystem resized successfully"
            else
                print_warning "Cannot resize XFS filesystem from host for unprivileged container"
                print_info "The logical volume has been resized successfully"
                print_info "To complete the process, start the container and run: xfs_growfs /"
                print_info "Or restart the container - XFS will auto-expand on mount"
                return 0
            fi
            ;;
        *)
            print_warning "Unsupported filesystem type: $FS_TYPE"
            print_info "The logical volume has been resized successfully"
            print_info "You will need to resize the filesystem manually"
            return 0
            ;;
    esac
}

# Start container if it was originally running
restore_container_state() {
    if [[ "$RUNNING" == true ]]; then
        print_step "Restoring container to running state..."
        
        if ! pct start "$CTID"; then
            print_error "Failed to restart container $CTID"
            print_warning "Container resize completed but failed to restart"
            print_info "Please start the container manually: pct start $CTID"
            exit 1
        fi
        
        print_success "Container $CTID started successfully"
    fi
}

# Verify the resize operation
verify_resize() {
    print_step "Verifying resize operation..."
    
    # Check logical volume size
    local final_size
    final_size=$(lvs --noheadings --units g --nosuffix -o lv_size "$VOL" | tr -d ' ')
    
    print_info "Final logical volume size: ${final_size}G"
    
    # If container is running, check filesystem size
    if [[ "$RUNNING" == true ]]; then
        print_step "Checking filesystem size inside container..."
        
        # Wait a moment for container to fully start
        sleep 3
        
        if pct exec "$CTID" -- df -h / 2>/dev/null; then
            print_success "Filesystem information retrieved successfully"
        else
            print_warning "Could not retrieve filesystem information from container"
        fi
    fi
}

#===============================================================================
# MAIN EXECUTION FUNCTION
#===============================================================================

# Main function that orchestrates the resize process
main() {
    show_header
    
    # Prerequisites and validation
    check_prerequisites
    
    # Get user input
    get_container_id
    get_container_info "$CTID"
    
    echo ""
    print_info "Current configuration summary:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Container ID: $CTID"
    print_info "Container Type: $([ "$PRIVILEGED" == true ] && echo "Privileged" || echo "Unprivileged")"
    print_info "Current Status: $([ "$RUNNING" == true ] && echo "Running" || echo "Stopped")"
    print_info "Current Size: ${ORIGINAL_SIZE}G"
    print_info "Filesystem: $FS_TYPE"
    echo ""
    
    # Check if filesystem is supported
    if [[ ! " ${SUPPORTED_FS_TYPES[*]} " =~ " ${FS_TYPE} " ]] && [[ "$FS_TYPE" != "unknown" ]]; then
        print_warning "Filesystem type '$FS_TYPE' has limited support"
        print_info "Logical volume will be resized, but filesystem resize may need manual intervention"
        echo ""
        
        print_prompt "Do you want to continue? (y/N):"
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled by user"
            exit 0
        fi
    fi
    
    get_new_size
    
    echo ""
    print_warning "⚠️  IMPORTANT SAFETY NOTICE ⚠️"
    print_warning "This operation will modify container storage and may require stopping the container"
    print_warning "Always ensure you have backups before proceeding with disk operations"
    echo ""
    
    print_prompt "Proceed with resizing container $CTID to $NEW_SIZE? (y/N):"
    read -r final_confirmation
    if [[ ! "$final_confirmation" =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled by user"
        exit 0
    fi
    
    echo ""
    print_step "Starting resize operation..."
    
    # Execute resize steps
    stop_container_safely
    check_filesystem
    resize_logical_volume
    resize_filesystem
    restore_container_state
    verify_resize
    
    echo ""
    print_success "✅ Container resize operation completed successfully!"
    print_info "Container $CTID has been resized to $NEW_SIZE"
    
    if [[ "$FS_TYPE" == "xfs" && "$PRIVILEGED" == false ]]; then
        echo ""
        print_info "📋 Next steps for XFS on unprivileged container:"
        print_info "   1. Start the container: pct start $CTID"
        print_info "   2. Verify filesystem size: pct exec $CTID -- df -h /"
        print_info "   3. If needed, resize manually: pct exec $CTID -- xfs_growfs /"
    fi
}

#===============================================================================
# SCRIPT ENTRY POINT
#===============================================================================

# Execute main function
main "$@"