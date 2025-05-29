#!/bin/bash

#===============================================================================
# WireGuard LXC Client Installation Script
#===============================================================================
# Description: Automated installer for WireGuard VPN client in LXC containers
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script automatically installs and configures WireGuard VPN client
# specifically optimized for LXC containers. It handles package installation,
# configuration management, and service setup with proper error handling.
#
# Features:
# - Automatic package installation and updates
# - Interactive configuration input with validation
# - Color-coded output for better readability
# - Comprehensive error handling and validation
# - LXC-optimized configuration
# - Automatic service management
# - Connection status verification
# - Configuration backup and recovery
#
# Usage: sudo bash install-wireguard-lxc.sh
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
readonly WG_CONF_PATH="/etc/wireguard/wg0.conf"
readonly WG_CONF_BACKUP="/etc/wireguard/wg0.conf.backup"
readonly WG_INTERFACE="wg0"
readonly WG_CONFIG_DIR="/etc/wireguard"

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
    echo -e "${CYAN}📝 [INPUT]${NC} $1"
}

# Display script header
show_header() {
    echo -e "${CYAN}"
    echo "==============================================================================="
    echo "              WIREGUARD LXC CLIENT INSTALLATION SCRIPT"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "${WHITE}VPN Client Setup - LXC Container Optimized${NC}"
    echo ""
}

# Cleanup function for temporary files and failed installations
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Installation failed with exit code $exit_code"
        print_step "Performing cleanup..."
        
        # Stop WireGuard if it was started
        systemctl stop wg-quick@"$WG_INTERFACE" 2>/dev/null || true
        systemctl disable wg-quick@"$WG_INTERFACE" 2>/dev/null || true
        
        # Restore backup if it exists
        if [[ -f "$WG_CONF_BACKUP" ]]; then
            mv "$WG_CONF_BACKUP" "$WG_CONF_PATH"
            print_info "Configuration restored from backup"
        fi
    else
        print_success "Installation completed successfully!"
        echo -e "${GREEN}WireGuard VPN client is now active and configured.${NC}"
    fi
    exit $exit_code
}

# Set up signal handlers for cleanup
trap cleanup EXIT INT TERM

#===============================================================================
# VALIDATION FUNCTIONS
#===============================================================================

# Check if running as root
check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        print_info "Usage: sudo $SCRIPT_NAME"
        exit 1
    fi
}

# Check if we're running in an LXC container
check_lxc_environment() {
    if [[ -f /proc/1/environ ]] && grep -q container=lxc /proc/1/environ; then
        print_success "LXC container environment detected"
        return 0
    elif [[ -f /.dockerenv ]]; then
        print_warning "Docker container detected - some features may not work"
        return 1
    else
        print_info "Not running in a container (bare metal/VM)"
        return 0
    fi
}

# Check if required commands are available
check_dependencies() {
    local deps=("apt" "systemctl" "grep" "cat")
    local missing_deps=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required commands: ${missing_deps[*]}"
        print_info "This script requires a Debian/Ubuntu-based system"
        exit 1
    fi
}

# Validate WireGuard configuration format
validate_wireguard_config() {
    local config_file="$1"
    local errors=()
    
    # Check if file exists and is readable
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    # Check for required sections
    if ! grep -q "^\[Interface\]" "$config_file"; then
        errors+=("Missing [Interface] section")
    fi
    
    if ! grep -q "^\[Peer\]" "$config_file"; then
        errors+=("Missing [Peer] section")
    fi
    
    # Check for required Interface fields
    if ! grep -q "^PrivateKey\s*=" "$config_file"; then
        errors+=("Missing PrivateKey in [Interface] section")
    fi
    
    if ! grep -q "^Address\s*=" "$config_file"; then
        errors+=("Missing Address in [Interface] section")
    fi
    
    # Check for required Peer fields
    if ! grep -q "^PublicKey\s*=" "$config_file"; then
        errors+=("Missing PublicKey in [Peer] section")
    fi
    
    if ! grep -q "^Endpoint\s*=" "$config_file"; then
        errors+=("Missing Endpoint in [Peer] section")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        print_error "Configuration validation failed:"
        for error in "${errors[@]}"; do
            echo -e "  ${RED}•${NC} $error"
        done
        return 1
    fi
    
    print_success "Configuration validation passed"
    return 0
}

#===============================================================================
# INSTALLATION FUNCTIONS
#===============================================================================

# Update system and install required packages
install_packages() {
    print_step "Updating system packages..."
    
    # Update package lists
    if ! apt update -qq; then
        print_error "Failed to update package lists"
        exit 1
    fi
    
    print_step "Installing WireGuard and dependencies..."
    
    # Install required packages
    local packages=("wireguard" "openresolv" "resolvconf" "iptables")
    
    if ! apt install -y "${packages[@]}"; then
        print_error "Failed to install required packages"
        exit 1
    fi
    
    print_success "Packages installed successfully"
}

# Create configuration directory and set permissions
setup_configuration_directory() {
    print_step "Setting up WireGuard configuration directory..."
    
    # Create directory with proper permissions
    mkdir -p "$WG_CONFIG_DIR"
    chmod 700 "$WG_CONFIG_DIR"
    
    print_success "Configuration directory created: $WG_CONFIG_DIR"
}

# Handle existing configuration
handle_existing_config() {
    if [[ -f "$WG_CONF_PATH" ]]; then
        print_warning "Existing WireGuard configuration found: $WG_CONF_PATH"
        
        echo -e "${YELLOW}Options:${NC}"
        echo "  1) Use existing configuration"
        echo "  2) Backup existing and create new configuration"
        echo "  3) Exit and handle manually"
        
        while true; do
            read -p "$(echo -e "${CYAN}Choose an option [1-3]:${NC} ")" choice
            case $choice in
                1)
                    print_info "Using existing configuration"
                    return 0
                    ;;
                2)
                    print_step "Backing up existing configuration..."
                    cp "$WG_CONF_PATH" "$WG_CONF_BACKUP"
                    print_success "Backup created: $WG_CONF_BACKUP"
                    rm -f "$WG_CONF_PATH"
                    return 1
                    ;;
                3)
                    print_info "Exiting to allow manual configuration handling"
                    exit 0
                    ;;
                *)
                    print_error "Invalid option. Please choose 1, 2, or 3."
                    ;;
            esac
        done
    fi
    return 1
}

# Get WireGuard configuration from user input
get_wireguard_configuration() {
    print_step "WireGuard configuration setup"
    echo ""
    
    print_prompt "Please paste your WireGuard client configuration below."
    print_info "You can paste the entire .conf file content"
    print_info "Press Ctrl+D when finished, or Ctrl+C to cancel"
    echo ""
    echo -e "${YELLOW}Expected format:${NC}"
    echo "[Interface]"
    echo "PrivateKey = <your-private-key>"
    echo "Address = <your-vpn-ip>/24"
    echo "DNS = <dns-server>"
    echo ""
    echo "[Peer]"
    echo "PublicKey = <server-public-key>"
    echo "Endpoint = <server-ip>:<port>"
    echo "AllowedIPs = 0.0.0.0/0"
    echo ""
    
    print_prompt "Paste configuration now:"
    
    # Read configuration from stdin
    if ! cat > "$WG_CONF_PATH"; then
        print_error "Failed to save configuration"
        exit 1
    fi
    
    echo ""
    print_success "Configuration saved to $WG_CONF_PATH"
    
    # Set proper permissions
    chmod 600 "$WG_CONF_PATH"
}

# Configure WireGuard service
configure_wireguard_service() {
    print_step "Configuring WireGuard service..."
    
    # Validate configuration before proceeding
    if ! validate_wireguard_config "$WG_CONF_PATH"; then
        print_error "Configuration validation failed"
        print_info "Please check your configuration and try again"
        exit 1
    fi
    
    # Enable IP forwarding if needed (for some LXC setups)
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        sysctl -p > /dev/null
        print_info "IP forwarding enabled"
    fi
    
    print_success "WireGuard service configured"
}

# Start and enable WireGuard
start_wireguard() {
    print_step "Starting WireGuard VPN connection..."
    
    # Start WireGuard interface
    if ! wg-quick up "$WG_INTERFACE"; then
        print_error "Failed to start WireGuard interface"
        print_info "Check your configuration and network connectivity"
        exit 1
    fi
    
    print_success "WireGuard interface started successfully"
    
    # Enable auto-start on boot
    print_step "Enabling WireGuard auto-start on boot..."
    if ! systemctl enable "wg-quick@$WG_INTERFACE"; then
        print_warning "Failed to enable auto-start (service will need manual start)"
    else
        print_success "Auto-start enabled for wg-quick@$WG_INTERFACE"
    fi
}

# Verify WireGuard connection
verify_connection() {
    print_step "Verifying WireGuard connection..."
    
    # Check if interface is up
    if ! ip link show "$WG_INTERFACE" &> /dev/null; then
        print_error "WireGuard interface not found"
        return 1
    fi
    
    # Show WireGuard status
    print_info "WireGuard interface status:"
    if wg_output=$(wg show 2>/dev/null); then
        echo "$wg_output" | while IFS= read -r line; do
            echo -e "  ${GREEN}${line}${NC}"
        done
    else
        print_warning "Could not retrieve WireGuard status"
    fi
    
    # Test connectivity (optional)
    print_step "Testing VPN connectivity..."
    if timeout 10 ping -c 2 8.8.8.8 &> /dev/null; then
        print_success "Internet connectivity through VPN confirmed"
    else
        print_warning "Could not confirm internet connectivity (this may be normal)"
    fi
    
    print_success "WireGuard connection verification completed"
}

# Display usage information
show_usage_info() {
    echo ""
    echo -e "${GREEN}🎉 WireGuard VPN Client Setup Complete!${NC}"
    echo ""
    echo -e "${WHITE}Useful Commands:${NC}"
    echo -e "  ${CYAN}wg show${NC}                          - Show current WireGuard status"
    echo -e "  ${CYAN}wg-quick down $WG_INTERFACE${NC}                - Stop VPN connection"
    echo -e "  ${CYAN}wg-quick up $WG_INTERFACE${NC}                  - Start VPN connection"
    echo -e "  ${CYAN}systemctl status wg-quick@$WG_INTERFACE${NC}    - Check service status"
    echo -e "  ${CYAN}systemctl restart wg-quick@$WG_INTERFACE${NC}   - Restart VPN service"
    echo ""
    echo -e "${WHITE}Configuration Files:${NC}"
    echo -e "  ${CYAN}Main config:${NC}     $WG_CONF_PATH"
    if [[ -f "$WG_CONF_BACKUP" ]]; then
        echo -e "  ${CYAN}Backup config:${NC}   $WG_CONF_BACKUP"
    fi
    echo ""
    echo -e "${WHITE}Log Files:${NC}"
    echo -e "  ${CYAN}System logs:${NC}     journalctl -u wg-quick@$WG_INTERFACE"
    echo ""
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    # Show welcome header
    show_header
    
    # Perform pre-installation checks
    check_root_privileges
    check_dependencies
    check_lxc_environment
    
    # Install packages and setup
    install_packages
    setup_configuration_directory
    
    # Handle configuration
    if ! handle_existing_config; then
        get_wireguard_configuration
    fi
    
    # Configure and start service
    configure_wireguard_service
    start_wireguard
    verify_connection
    
    # Show usage information
    show_usage_info
}

# Execute main function
main "$@"