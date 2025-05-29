#!/bin/bash

#===============================================================================
# Intel iGPU Auto-Fix Service Script for Proxmox
#===============================================================================
# Description: Automated startup service for Intel GPU container configuration
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script is designed to run automatically at system startup to detect
# Intel GPU device changes and update LXC container configurations accordingly.
# It works in conjunction with fix-intel-gpu-containers.sh but runs silently
# in the background without user interaction.
#
# Features:
# - Silent automatic execution
# - Configuration file support
# - Systemd service integration
# - Error logging and recovery
# - Container dependency management
#
# Usage: 
#   As systemd service: systemctl start intel-gpu-autofix
#   Manual execution: sudo bash intel-gpu-autofix.sh
#   With config file: sudo bash intel-gpu-autofix.sh /etc/intel-gpu-containers.conf
#
# Requirements: Must be run on Proxmox VE host with root privileges
#===============================================================================

# Script configuration
set -euo pipefail
IFS=$'\n\t'

# Constants
readonly SCRIPT_NAME="$(basename "$0")"
readonly DEFAULT_CONFIG="/etc/intel-gpu-containers.conf"
readonly LOG_PATH="/var/log/intel-gpu-autofix.log"
readonly MAIN_SCRIPT_PATH="/usr/local/bin/fix-intel-gpu-containers.sh"

# Configuration variables
CONTAINERS=""
CONFIG_FILE="$DEFAULT_CONFIG"

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log message to file
log_message() {
    echo "[$(get_timestamp)] $1" >> "$LOG_PATH"
}

# Load configuration from file
load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_message "WARNING: Configuration file not found: $config_file"
        return 1
    fi
    
    log_message "INFO: Loading configuration from: $config_file"
    
    # Source the config file safely
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        
        # Remove quotes and whitespace
        key=$(echo "$key" | tr -d ' ')
        value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//')
        
        case "$key" in
            CONTAINERS)
                CONTAINERS="$value"
                ;;
        esac
    done < "$config_file"
    
    log_message "INFO: Configuration loaded - containers: $CONTAINERS"
}

# Main execution
main() {
    # Create log directory
    mkdir -p "$(dirname "$LOG_PATH")"
    
    log_message "INFO: ===== Intel GPU Auto-Fix Service Started ====="
    
    # Parse config file argument
    if [[ $# -gt 0 ]]; then
        CONFIG_FILE="$1"
    fi
    
    # Load configuration
    if ! load_config "$CONFIG_FILE"; then
        log_message "ERROR: Failed to load configuration, exiting"
        exit 1
    fi
    
    # Check if containers are specified
    if [[ -z "$CONTAINERS" ]]; then
        log_message "ERROR: No containers specified in configuration"
        exit 1
    fi
    
    # Check if main script exists
    if [[ ! -x "$MAIN_SCRIPT_PATH" ]]; then
        log_message "ERROR: Main script not found or not executable: $MAIN_SCRIPT_PATH"
        exit 1
    fi
    
    # Wait a bit for system to stabilize after boot
    sleep 10
    
    # Execute the main GPU fix script
    log_message "INFO: Executing GPU fix for containers: $CONTAINERS"
    
    if "$MAIN_SCRIPT_PATH" --containers "$CONTAINERS" --auto --no-restart >> "$LOG_PATH" 2>&1; then
        log_message "SUCCESS: GPU configuration completed successfully"
        
        # Now restart containers one by one with delays
        IFS=',' read -ra container_array <<< "$CONTAINERS"
        for ctid in "${container_array[@]}"; do
            log_message "INFO: Restarting container $ctid"
            if pct start "$ctid" >> "$LOG_PATH" 2>&1; then
                log_message "SUCCESS: Container $ctid started successfully"
            else
                log_message "ERROR: Failed to start container $ctid"
            fi
            sleep 5  # Wait between container starts
        done
        
        log_message "SUCCESS: All containers processed"
    else
        log_message "ERROR: GPU configuration failed"
        exit 1
    fi
    
    log_message "INFO: ===== Intel GPU Auto-Fix Service Completed ====="
}

# Execute main function
main "$@"
