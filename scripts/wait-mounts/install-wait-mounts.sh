#!/bin/bash

#===============================================================================
# Wait-Mounts Auto-Start System Installer
#===============================================================================
# Description: Installer script for wait-mounts system management
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script installs and configures the wait-mounts system for
# Proxmox VE. It sets up the scripts, configuration files, and systemd
# service to automatically wait for mount points before starting containers.
#
# Usage: sudo bash install-wait-mounts.sh
# Requirements: Must be run on Proxmox VE host with root privileges
#===============================================================================

# Script configuration
set -euo pipefail
IFS=$'\n\t'

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="/usr/local/bin"
readonly CONFIG_DIR="/etc"
readonly SYSTEMD_DIR="/etc/systemd/system"

# Print functions
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
    echo -e "${CYAN}🔧 [STEP]${NC} $1"
}

# Display header
show_header() {
    echo -e "${CYAN}"
    echo "==============================================================================="
    echo "              WAIT-MOUNTS AUTO-START SYSTEM INSTALLER"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "This installer will set up automatic mount waiting for LXC containers"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        print_error "This installer must be run as root"
        print_info "Usage: sudo $0"
        exit 1
    fi
    
    # Check if running on Proxmox VE
    if ! command -v pct &> /dev/null; then
        print_error "This installer must be run on a Proxmox VE host"
        exit 1
    fi
    
    # Check required files exist
    local required_files=(
        "wait-mounts.sh"
        "wait-mounts.conf.example"
        "wait-mounts.service"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
            print_error "Required file not found: $SCRIPT_DIR/$file"
            exit 1
        fi
    done
    
    print_success "Prerequisites check passed"
}

# Install scripts
install_scripts() {
    print_step "Installing scripts to $INSTALL_DIR..."
    
    # Copy main script
    cp "$SCRIPT_DIR/wait-mounts.sh" "$INSTALL_DIR/"
    
    # Set permissions
    chmod 755 "$INSTALL_DIR/wait-mounts.sh"
    
    print_success "Scripts installed successfully"
}

# Install configuration
install_config() {
    print_step "Installing configuration files..."
    
    # Copy example config if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/wait-mounts.conf" ]]; then
        cp "$SCRIPT_DIR/wait-mounts.conf.example" "$CONFIG_DIR/wait-mounts.conf"
        print_success "Configuration file created: $CONFIG_DIR/wait-mounts.conf"
        print_warning "Please edit this file to specify your mount points and containers"
    else
        print_info "Configuration file already exists, skipping"
    fi
}

# Install systemd service
install_service() {
    print_step "Installing systemd service..."
    
    # Copy service file
    cp "$SCRIPT_DIR/wait-mounts.service" "$SYSTEMD_DIR/"
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Systemd service installed"
    print_info "Service file: $SYSTEMD_DIR/wait-mounts.service"
}

# Configure mount points and containers interactively
configure_mounts() {
    print_step "Configuring mount points and containers..."
    
    echo ""
    print_info "Please configure the mount points and containers"
    print_info "that should be managed by the wait-mounts service"
    echo ""
    
    # Configure mount points
    print_info "Enter mount points to monitor (one per line, empty line to finish):"
    local mount_points=()
    while true; do
        printf "${CYAN}📁 Mount point: ${NC}"
        read -r mount_point
        
        if [[ -z "$mount_point" ]]; then
            if [[ ${#mount_points[@]} -eq 0 ]]; then
                print_warning "At least one mount point is required"
                continue
            else
                break
            fi
        fi
        
        # Validate mount point format
        if [[ "$mount_point" =~ ^/[a-zA-Z0-9/_-]+$ ]]; then
            mount_points+=("$mount_point")
            print_success "Added mount point: $mount_point"
        else
            print_warning "Invalid mount point format: $mount_point"
        fi
    done
    
    echo ""
    
    # Configure containers
    print_info "Enter container IDs to start after mounts are ready (comma-separated):"
    printf "${CYAN}📦 Container IDs: ${NC}"
    read -r container_ids
    
    local valid_containers=()
    if [[ -n "$container_ids" ]]; then
        # Validate container IDs
        IFS=',' read -ra container_array <<< "$container_ids"
        
        for ctid in "${container_array[@]}"; do
            # Remove whitespace
            ctid=$(echo "$ctid" | tr -d ' ')
            
            # Check if numeric
            if [[ "$ctid" =~ ^[0-9]+$ ]]; then
                # Check if container exists
                if pct status "$ctid" &> /dev/null; then
                    valid_containers+=("$ctid")
                    print_success "Container $ctid validated"
                else
                    print_warning "Container $ctid does not exist, skipping"
                fi
            else
                print_warning "Invalid container ID: $ctid, skipping"
            fi
        done
    fi
    
    # Update configuration file
    if [[ ${#mount_points[@]} -gt 0 || ${#valid_containers[@]} -gt 0 ]]; then
        local mount_string=$(printf '"%s" ' "${mount_points[@]}")
        local container_string=""
        if [[ ${#valid_containers[@]} -gt 0 ]]; then
            container_string=$(IFS=','; echo "${valid_containers[*]}")
        fi
        
        # Update config file
        {
            echo "# Wait-Mounts Configuration File"
            echo "# Generated by installer on $(date)"
            echo ""
            echo "# Mount points to monitor (space-separated, quoted)"
            echo "MOUNT_POINTS=($mount_string)"
            echo ""
            echo "# Container IDs to start after mounts are ready (comma-separated)"
            echo "CONTAINERS=\"$container_string\""
            echo ""
            echo "# Timeout in seconds"
            echo "TIMEOUT=300"
            echo ""
            echo "# Check interval in seconds" 
            echo "CHECK_INTERVAL=5"
        } > "$CONFIG_DIR/wait-mounts.conf"
        
        print_success "Configuration updated successfully"
    else
        print_warning "No valid configuration specified, using example configuration"
    fi
}

# Enable and start service
enable_service() {
    print_step "Configuring systemd service..."
    
    printf "${CYAN}📝 Enable service to start automatically at boot? (y/N): ${NC}"
    read -r enable_choice
    
    if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
        systemctl enable wait-mounts.service
        print_success "Service enabled for automatic startup"
    else
        print_info "Service not enabled for automatic startup"
        print_info "You can enable it later with: systemctl enable wait-mounts.service"
    fi
    
    echo ""
    printf "${CYAN}📝 Run service now to test configuration? (y/N): ${NC}"
    read -r run_choice
    
    if [[ "$run_choice" =~ ^[Yy]$ ]]; then
        print_step "Running service test..."
        if systemctl start wait-mounts.service; then
            print_success "Service test completed successfully"
            print_info "Check logs with: journalctl -u wait-mounts.service"
        else
            print_warning "Service test failed"
            print_info "Check logs with: journalctl -u wait-mounts.service"
        fi
    fi
}

# Show final instructions
show_final_instructions() {
    echo ""
    print_success "✅ Wait-Mounts Auto-Start System installation completed!"
    echo ""
    print_info "Installation Summary:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Scripts installed in: $INSTALL_DIR"
    print_info "Configuration file: $CONFIG_DIR/wait-mounts.conf"
    print_info "Service file: $SYSTEMD_DIR/wait-mounts.service"
    echo ""
    print_info "Manual Usage:"
    print_info "  Interactive mode: sudo wait-mounts.sh"
    print_info "  With config file: sudo wait-mounts.sh --config /etc/wait-mounts.conf"
    print_info "  Daemon mode:      sudo wait-mounts.sh --daemon"
    print_info "  Specific mounts:  sudo wait-mounts.sh --mounts \"/mnt/data /mnt/backup\""
    print_info "  With containers:  sudo wait-mounts.sh --containers \"101,102\""
    echo ""
    print_info "Service Management:"
    print_info "  Enable service:   sudo systemctl enable wait-mounts.service"
    print_info "  Start service:    sudo systemctl start wait-mounts.service"
    print_info "  Check status:     sudo systemctl status wait-mounts.service"
    print_info "  View logs:        sudo journalctl -u wait-mounts.service"
    echo ""
    print_info "Configuration:"
    print_info "  Edit config:      sudo nano $CONFIG_DIR/wait-mounts.conf"
    echo ""
    print_warning "Remember to configure your mount points and container IDs!"
}

# Main installation function
main() {
    show_header
    check_prerequisites
    install_scripts
    install_config
    install_service
    configure_mounts
    enable_service
    show_final_instructions
}

# Execute main function
main "$@"
