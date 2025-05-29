#!/bin/bash

#===============================================================================
# BTOP++ Installation Script
#===============================================================================
# Description: Automated installer for btop++ system monitor
# Author: System Administrator
# Version: 2.0
# License: MIT
# 
# This script automatically downloads and installs the latest version of btop++
# from the official GitHub repository. It supports multiple architectures and
# includes proper error handling and cleanup.
#
# Features:
# - Automatic architecture detection
# - Latest version fetching from GitHub API
# - Color-coded output for better readability
# - Comprehensive error handling
# - Automatic cleanup of temporary files
# - Root privilege verification
# - GPU support configuration
#
# Usage: sudo bash install-btop.sh
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
readonly TEMP_DIR=$(mktemp -d)
readonly BTOP_REPO="aristocratos/btop"
readonly INSTALL_PREFIX="/usr/local"

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

# Display script header
show_header() {
    echo -e "${CYAN}"
    echo "==============================================================================="
    echo "                        BTOP++ INSTALLATION SCRIPT"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "${WHITE}System Monitor Tool - Latest Version Installer${NC}"
    echo ""
}

# Cleanup function for temporary files
cleanup() {
    local exit_code=$?
    print_step "Cleaning up temporary files..."
    cd /
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    if [[ $exit_code -eq 0 ]]; then
        print_success "Installation completed successfully!"
        echo -e "${GREEN}Run '${WHITE}btop${GREEN}' to start the system monitor.${NC}"
    else
        print_error "Installation failed with exit code $exit_code"
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

# Check if required commands are available
check_dependencies() {
    local deps=("curl" "tar" "make" "uname")
    local missing_deps=()
    
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_warning "Missing dependencies will be installed: ${missing_deps[*]}"
        return 1
    fi
    return 0
}

#===============================================================================
# INSTALLATION FUNCTIONS
#===============================================================================

# Install required system dependencies
install_dependencies() {
    print_step "Installing required system dependencies..."
    
    # Update package lists
    if command -v apt &> /dev/null; then
        apt update -qq
        apt install -y curl tar make libcap2-bin bzip2 build-essential
    elif command -v yum &> /dev/null; then
        yum install -y curl tar make libcap-devel bzip2 gcc-c++
    elif command -v dnf &> /dev/null; then
        dnf install -y curl tar make libcap-devel bzip2 gcc-c++
    elif command -v pacman &> /dev/null; then
        pacman -Sy --noconfirm curl tar make libcap bzip2 base-devel
    else
        print_error "Unsupported package manager. Please install dependencies manually:"
        print_info "Required: curl, tar, make, libcap-dev, bzip2, build tools"
        exit 1
    fi
    
    print_success "Dependencies installed successfully"
}

# Detect system architecture and map to btop release naming
detect_architecture() {
    print_step "Detecting system architecture..."
    
    local arch_raw
    arch_raw=$(uname -m)
    
    case "$arch_raw" in
        x86_64)
            ARCH="x86_64-linux-musl"
            ;;
        i686)
            ARCH="i686-linux-musl"
            ;;
        i386)
            ARCH="i486-linux-musl"
            ;;
        aarch64)
            ARCH="aarch64-linux-musl"
            ;;
        armv7l)
            ARCH="armv7l-linux-musleabihf"
            ;;
        armv6l)
            ARCH="arm-linux-musleabi"
            ;;
        armv5l)
            ARCH="armv5l-linux-musleabi"
            ;;
        mips64)
            ARCH="mips64-linux-musl"
            ;;
        ppc64|ppc64le)
            ARCH="powerpc64-linux-musl"
            ;;
        *)
            print_error "Unsupported architecture: $arch_raw"
            print_info "Supported architectures: x86_64, i686, i386, aarch64, armv7l, armv6l, armv5l, mips64, ppc64"
            exit 1
            ;;
    esac
    
    print_success "Architecture detected: ${WHITE}$ARCH${NC} (${arch_raw})"
}

# Download and parse latest release information from GitHub API
get_latest_release() {
    print_step "Fetching latest btop++ release information..."
    
    local api_url="https://api.github.com/repos/$BTOP_REPO/releases/latest"
    
    if ! RELEASE_JSON=$(curl -sf "$api_url"); then
        print_error "Failed to fetch release information from GitHub API"
        print_info "Please check your internet connection and try again"
        exit 1
    fi
    
    # Extract download URL for our architecture
    ASSET_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url":[^,]*' | grep "$ARCH" | grep '\.tbz"' | cut -d'"' -f4)
    
    if [[ -z "$ASSET_URL" ]]; then
        print_error "No binary found for architecture: $ARCH"
        print_info "Available releases:"
        echo "$RELEASE_JSON" | grep -o '"browser_download_url":[^,]*' | cut -d'"' -f4 | sed 's/^/  - /'
        exit 1
    fi
    
    # Extract version number
    VERSION=$(echo "$RELEASE_JSON" | grep -o '"tag_name":[^,]*' | cut -d'"' -f4)
    
    print_success "Latest version found: ${WHITE}$VERSION${NC}"
    print_info "Download URL: $ASSET_URL"
}

# Download and extract btop++ binary
download_and_extract() {
    local file
    local folder
    
    file=$(basename "$ASSET_URL")
    folder="${file%.tbz}"
    
    print_step "Downloading btop++ $VERSION..."
    print_info "File: $file"
    
    cd "$TEMP_DIR"
    
    if ! curl -L --progress-bar -o "$file" "$ASSET_URL"; then
        print_error "Failed to download btop++ archive"
        exit 1
    fi
    
    print_success "Download completed"
    
    print_step "Extracting archive..."
    
    if ! mkdir -p "$folder" || ! tar -xjf "$file" -C "$folder"; then
        print_error "Failed to extract archive"
        exit 1
    fi
    
    print_success "Archive extracted successfully"
    
    # Navigate to the btop directory inside the extracted folder
    if [[ ! -d "$folder/btop" ]]; then
        print_error "Expected btop directory not found in archive"
        exit 1
    fi
    
    cd "$folder/btop"
}

# Install btop++ to the system
install_btop() {
    print_step "Installing btop++ to $INSTALL_PREFIX..."
    
    if ! make install PREFIX="$INSTALL_PREFIX"; then
        print_error "Installation failed during 'make install'"
        exit 1
    fi
    
    print_success "btop++ installed successfully"
}

# Configure GPU support capabilities
configure_gpu_support() {
    print_step "Configuring GPU support and capabilities..."
    
    if make setcap PREFIX="$INSTALL_PREFIX" 2>/dev/null; then
        print_success "GPU support configured successfully"
    else
        print_warning "GPU support configuration failed (this is optional)"
        print_info "btop++ will still work without GPU monitoring capabilities"
    fi
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."
    
    if command -v btop &> /dev/null; then
        local installed_version
        installed_version=$(btop --version 2>/dev/null | head -n1 || echo "unknown")
        print_success "btop++ is installed and accessible"
        print_info "Installed version: $installed_version"
    else
        print_warning "btop++ command not found in PATH"
        print_info "You may need to add $INSTALL_PREFIX/bin to your PATH"
    fi
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    # Show welcome header
    show_header
    
    # Perform pre-installation checks
    check_root_privileges
    
    # Install dependencies if needed
    if ! check_dependencies; then
        install_dependencies
    else
        print_success "All dependencies are already installed"
    fi
    
    # Main installation process
    detect_architecture
    get_latest_release
    download_and_extract
    install_btop
    configure_gpu_support
    verify_installation
    
    # Final success message
    echo ""
    echo -e "${GREEN}🎉 Installation completed successfully!${NC}"
    echo -e "${WHITE}Usage:${NC}"
    echo -e "  ${CYAN}btop${NC}           - Start btop++ with default settings"
    echo -e "  ${CYAN}btop --help${NC}    - Show help and available options"
    echo ""
}

# Execute main function
main "$@"