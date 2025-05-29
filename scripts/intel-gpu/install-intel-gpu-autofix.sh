#!/bin/bash

#===============================================================================
# Intel GPU Auto-Fix System Installer
#===============================================================================
# Description: Installer script for Intel GPU container management system
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script installs and configures the Intel GPU auto-fix system for
# Proxmox VE. It sets up the scripts, configuration files, and systemd
# service to automatically handle Intel GPU device path changes.
#
# Usage: sudo bash install-intel-gpu-autofix.sh
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
    echo "              INTEL GPU AUTO-FIX SYSTEM INSTALLER"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "This installer will set up automatic Intel GPU management for LXC containers"
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
        "fix-intel-gpu-containers.sh"
        "intel-gpu-autofix.sh" 
        "intel-gpu-containers.conf.example"
        "intel-gpu-autofix.service"
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
    
    # Copy main scripts
    cp "$SCRIPT_DIR/fix-intel-gpu-containers.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/intel-gpu-autofix.sh" "$INSTALL_DIR/"
    
    # Set permissions
    chmod 755 "$INSTALL_DIR/fix-intel-gpu-containers.sh"
    chmod 755 "$INSTALL_DIR/intel-gpu-autofix.sh"
    
    print_success "Scripts installed successfully"
}

# Install configuration
install_config() {
    print_step "Installing configuration files..."
    
    # Copy example config if it doesn't exist
    if [[ ! -f "$CONFIG_DIR/intel-gpu-containers.conf" ]]; then
        cp "$SCRIPT_DIR/intel-gpu-containers.conf.example" "$CONFIG_DIR/intel-gpu-containers.conf"
        print_success "Configuration file created: $CONFIG_DIR/intel-gpu-containers.conf"
        print_warning "Please edit this file to specify your container IDs"
    else
        print_info "Configuration file already exists, skipping"
    fi
}

# Install systemd service
install_service() {
    print_step "Installing systemd service..."
    
    # Copy service file
    cp "$SCRIPT_DIR/intel-gpu-autofix.service" "$SYSTEMD_DIR/"
    
    # Reload systemd
    systemctl daemon-reload
    
    print_success "Systemd service installed"
    print_info "Service file: $SYSTEMD_DIR/intel-gpu-autofix.service"
}

# Configure container IDs interactively
configure_containers() {
    print_step "Configuring container IDs..."
    
    echo ""
    print_info "Please enter the LXC container IDs that use Intel GPU"
    print_info "These containers will be automatically managed by the service"
    print_info "Enter container IDs separated by commas (e.g., 101,102,104)"
    echo ""
    
    printf "${CYAN}📝 Container IDs: ${NC}"
    read -r container_ids
    
    if [[ -n "$container_ids" ]]; then
        # Validate container IDs
        IFS=',' read -ra container_array <<< "$container_ids"
        local valid_containers=()
        
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
        
        if [[ ${#valid_containers[@]} -gt 0 ]]; then
            # Update configuration file
            local valid_ids_string=$(IFS=','; echo "${valid_containers[*]}")
            sed -i "s/^CONTAINERS=.*/CONTAINERS=\"$valid_ids_string\"/" "$CONFIG_DIR/intel-gpu-containers.conf"
            print_success "Configuration updated with containers: $valid_ids_string"
        else
            print_warning "No valid containers specified"
        fi
    else
        print_warning "No containers specified, using example configuration"
    fi
}

# Enable and start service
enable_service() {
    print_step "Configuring systemd service..."
    
    printf "${CYAN}📝 Enable service to start automatically at boot? (y/N): ${NC}"
    read -r enable_choice
    
    if [[ "$enable_choice" =~ ^[Yy]$ ]]; then
        systemctl enable intel-gpu-autofix.service
        print_success "Service enabled for automatic startup"
    else
        print_info "Service not enabled for automatic startup"
        print_info "You can enable it later with: systemctl enable intel-gpu-autofix.service"
    fi
    
    echo ""
    printf "${CYAN}📝 Run service now to test configuration? (y/N): ${NC}"
    read -r run_choice
    
    if [[ "$run_choice" =~ ^[Yy]$ ]]; then
        print_step "Running service test..."
        if systemctl start intel-gpu-autofix.service; then
            print_success "Service test completed successfully"
            print_info "Check logs with: journalctl -u intel-gpu-autofix.service"
        else
            print_warning "Service test failed"
            print_info "Check logs with: journalctl -u intel-gpu-autofix.service"
        fi
    fi
}

# Show final instructions
show_final_instructions() {
    echo ""
    print_success "✅ Intel GPU Auto-Fix System installation completed!"
    echo ""
    print_info "Installation Summary:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Scripts installed in: $INSTALL_DIR"
    print_info "Configuration file: $CONFIG_DIR/intel-gpu-containers.conf"
    print_info "Service file: $SYSTEMD_DIR/intel-gpu-autofix.service"
    echo ""
    print_info "Manual Usage:"
    print_info "  Interactive mode: sudo fix-intel-gpu-containers.sh"
    print_info "  Automated mode:   sudo fix-intel-gpu-containers.sh --containers \"101,102\" --auto"
    print_info "  Check GPU only:   sudo fix-intel-gpu-containers.sh --check-only"
    echo ""
    print_info "Service Management:"
    print_info "  Enable service:   sudo systemctl enable intel-gpu-autofix.service"
    print_info "  Start service:    sudo systemctl start intel-gpu-autofix.service"
    print_info "  Check status:     sudo systemctl status intel-gpu-autofix.service"
    print_info "  View logs:        sudo journalctl -u intel-gpu-autofix.service"
    echo ""
    print_info "Configuration:"
    print_info "  Edit container IDs: sudo nano $CONFIG_DIR/intel-gpu-containers.conf"
    echo ""
    print_warning "Remember to update the container IDs in the configuration file!"
}

# Main installation function
main() {
    show_header
    check_prerequisites
    install_scripts
    install_config
    install_service
    configure_containers
    enable_service
    show_final_instructions
}

# Execute main function
main "$@"
