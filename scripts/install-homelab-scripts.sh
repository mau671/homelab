#!/bin/bash

#===============================================================================
# Homelab Scripts Master Installer
#===============================================================================
# Description: Master installer for all homelab automation scripts
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script provides a unified interface to install all homelab management
# systems including Intel GPU management, wait-mounts, and utilities.
#
# Usage: sudo bash install-homelab-scripts.sh
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
readonly MAGENTA='\033[0;35m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

print_header() {
    echo -e "${MAGENTA}🚀 [SYSTEM]${NC} $1"
}

# Display main header
show_main_header() {
    clear
    echo -e "${CYAN}"
    echo "==============================================================================="
    echo "                    HOMELAB SCRIPTS MASTER INSTALLER"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "${WHITE}Professional automation scripts for Proxmox VE homelab management${NC}"
    echo ""
    echo -e "${BLUE}Available Systems:${NC}"
    echo -e "  ${GREEN}1.${NC} Intel GPU Auto-Fix System"
    echo -e "  ${GREEN}2.${NC} Wait-Mounts Management System"
    echo -e "  ${GREEN}3.${NC} Container Management Tools"
    echo -e "  ${GREEN}4.${NC} Utility Scripts Collection"
    echo -e "  ${GREEN}5.${NC} Install All Systems"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking system prerequisites..."
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        print_error "This installer must be run as root"
        print_info "Usage: sudo $0"
        exit 1
    fi
    
    # Check if running on Proxmox VE
    if ! command -v pct &> /dev/null; then
        print_error "This installer must be run on a Proxmox VE host"
        print_info "The 'pct' command is not available"
        exit 1
    fi
    
    # Check script directories exist
    local required_dirs=(
        "intel-gpu"
        "wait-mounts"
        "container-management"
        "utilities"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$SCRIPT_DIR/$dir" ]]; then
            print_error "Required directory not found: $SCRIPT_DIR/$dir"
            exit 1
        fi
    done
    
    print_success "Prerequisites check passed"
    echo ""
}

# Install Intel GPU system
install_intel_gpu() {
    print_header "Installing Intel GPU Auto-Fix System"
    echo ""
    
    if [[ -x "$SCRIPT_DIR/intel-gpu/install-intel-gpu-autofix.sh" ]]; then
        cd "$SCRIPT_DIR/intel-gpu"
        if ./install-intel-gpu-autofix.sh; then
            print_success "Intel GPU system installed successfully"
        else
            print_error "Intel GPU system installation failed"
            return 1
        fi
    else
        print_error "Intel GPU installer not found or not executable"
        return 1
    fi
    
    echo ""
}

# Install wait-mounts system
install_wait_mounts() {
    print_header "Installing Wait-Mounts Management System"
    echo ""
    
    if [[ -x "$SCRIPT_DIR/wait-mounts/install-wait-mounts.sh" ]]; then
        cd "$SCRIPT_DIR/wait-mounts"
        if ./install-wait-mounts.sh; then
            print_success "Wait-mounts system installed successfully"
        else
            print_error "Wait-mounts system installation failed"
            return 1
        fi
    else
        print_error "Wait-mounts installer not found or not executable"
        return 1
    fi
    
    echo ""
}

# Install container management tools
install_container_management() {
    print_header "Installing Container Management Tools"
    echo ""
    
    # Copy resize script
    if [[ -x "$SCRIPT_DIR/container-management/resize-lxc.sh" ]]; then
        cp "$SCRIPT_DIR/container-management/resize-lxc.sh" "/usr/local/bin/"
        chmod 755 "/usr/local/bin/resize-lxc.sh"
        print_success "resize-lxc.sh installed to /usr/local/bin/"
    else
        print_error "resize-lxc.sh not found or not executable"
        return 1
    fi
    
    print_success "Container management tools installed successfully"
    echo ""
}

# Install utility scripts
install_utilities() {
    print_header "Installing Utility Scripts Collection"
    echo ""
    
    local utilities_dir="$SCRIPT_DIR/utilities"
    local installed_count=0
    
    # Install btop
    if [[ -x "$utilities_dir/install-btop.sh" ]]; then
        print_step "Installing btop monitoring tool..."
        if "$utilities_dir/install-btop.sh"; then
            print_success "btop installed successfully"
            ((installed_count++))
        else
            print_warning "btop installation failed"
        fi
    fi
    
    # Install WireGuard LXC tools
    if [[ -x "$utilities_dir/install-wireguard-lxc.sh" ]]; then
        print_step "Installing WireGuard LXC tools..."
        cp "$utilities_dir/install-wireguard-lxc.sh" "/usr/local/bin/"
        chmod 755 "/usr/local/bin/install-wireguard-lxc.sh"
        print_success "WireGuard LXC installer available at /usr/local/bin/"
        ((installed_count++))
    fi
    
    # Install GPU drivers script
    if [[ -x "$utilities_dir/install-gpu-drivers.sh" ]]; then
        print_step "Installing GPU drivers installer..."
        cp "$utilities_dir/install-gpu-drivers.sh" "/usr/local/bin/"
        chmod 755 "/usr/local/bin/install-gpu-drivers.sh"
        print_success "GPU drivers installer available at /usr/local/bin/"
        ((installed_count++))
    fi
    
    if [[ $installed_count -gt 0 ]]; then
        print_success "Utility scripts collection installed successfully"
    else
        print_warning "No utility scripts were installed"
    fi
    
    echo ""
}

# Show installation menu
show_menu() {
    echo -e "${CYAN}Please select an installation option:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} Intel GPU Auto-Fix System"
    echo -e "  ${GREEN}2)${NC} Wait-Mounts Management System"
    echo -e "  ${GREEN}3)${NC} Container Management Tools"
    echo -e "  ${GREEN}4)${NC} Utility Scripts Collection"
    echo -e "  ${GREEN}5)${NC} Install All Systems"
    echo -e "  ${RED}q)${NC} Quit"
    echo ""
    printf "${CYAN}Enter your choice [1-5,q]: ${NC}"
}

# Process user selection
process_selection() {
    local choice="$1"
    
    case "$choice" in
        1)
            install_intel_gpu
            ;;
        2)
            install_wait_mounts
            ;;
        3)
            install_container_management
            ;;
        4)
            install_utilities
            ;;
        5)
            print_header "Installing All Systems"
            echo ""
            install_intel_gpu
            install_wait_mounts
            install_container_management
            install_utilities
            ;;
        q|Q)
            print_info "Installation cancelled by user"
            exit 0
            ;;
        *)
            print_error "Invalid choice: $choice"
            return 1
            ;;
    esac
}

# Show final summary
show_summary() {
    echo ""
    print_success "🎉 Homelab Scripts Installation Summary"
    echo ""
    print_info "Installed Components:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check what's installed
    if [[ -f "/usr/local/bin/fix-intel-gpu-containers.sh" ]]; then
        print_info "✅ Intel GPU Auto-Fix System"
        print_info "   • Service: systemctl status intel-gpu-autofix.service"
        print_info "   • Manual: sudo fix-intel-gpu-containers.sh"
    fi
    
    if [[ -f "/usr/local/bin/wait-mounts.sh" ]]; then
        print_info "✅ Wait-Mounts Management System"
        print_info "   • Service: systemctl status wait-mounts.service"
        print_info "   • Manual: sudo wait-mounts.sh"
    fi
    
    if [[ -f "/usr/local/bin/resize-lxc.sh" ]]; then
        print_info "✅ Container Management Tools"
        print_info "   • Manual: sudo resize-lxc.sh"
    fi
    
    if [[ -f "/usr/local/bin/btop" || -f "/usr/local/bin/install-wireguard-lxc.sh" || -f "/usr/local/bin/install-gpu-drivers.sh" ]]; then
        print_info "✅ Utility Scripts Collection"
        if [[ -f "/usr/local/bin/btop" ]]; then
            print_info "   • Monitor: btop"
        fi
        if [[ -f "/usr/local/bin/install-wireguard-lxc.sh" ]]; then
            print_info "   • WireGuard: sudo install-wireguard-lxc.sh"
        fi
        if [[ -f "/usr/local/bin/install-gpu-drivers.sh" ]]; then
            print_info "   • GPU Drivers: sudo install-gpu-drivers.sh"
        fi
    fi
    
    echo ""
    print_info "Configuration Files:"
    print_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -f "/etc/intel-gpu-containers.conf" ]]; then
        print_info "• Intel GPU: /etc/intel-gpu-containers.conf"
    fi
    
    if [[ -f "/etc/wait-mounts.conf" ]]; then
        print_info "• Wait-Mounts: /etc/wait-mounts.conf"
    fi
    
    echo ""
    print_warning "📝 Next Steps:"
    print_info "1. Review and edit configuration files as needed"
    print_info "2. Enable services: systemctl enable <service-name>"
    print_info "3. Start services: systemctl start <service-name>"
    print_info "4. Monitor logs: journalctl -u <service-name>"
    echo ""
}

# Main installation function
main() {
    show_main_header
    check_prerequisites
    
    while true; do
        show_menu
        read -r choice
        echo ""
        
        if process_selection "$choice"; then
            if [[ "$choice" != "q" && "$choice" != "Q" ]]; then
                echo ""
                printf "${CYAN}Install another system? (y/N): ${NC}"
                read -r continue_choice
                if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                    break
                fi
                echo ""
            fi
        else
            echo ""
            printf "${YELLOW}Try again? (y/N): ${NC}"
            read -r retry_choice
            if [[ ! "$retry_choice" =~ ^[Yy]$ ]]; then
                break
            fi
        fi
        echo ""
    done
    
    show_summary
    print_success "Homelab scripts installation completed!"
}

# Execute main function
main "$@"
