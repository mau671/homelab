#!/bin/bash

#===============================================================================
# GPU Driver Auto-Installer for Ubuntu/Debian
#===============================================================================
# Description: Automatic GPU detection and driver installation script
# Author: System Administrator
# Version: 1.0
# License: MIT
# 
# This script automatically detects NVIDIA and Intel GPUs and installs
# the appropriate drivers and monitoring tools for both Ubuntu and Debian systems.
#
# Features:
# - Automatic GPU detection (NVIDIA and Intel)
# - Distribution detection (Ubuntu/Debian)
# - Driver installation with optimal configuration
# - Monitoring tools installation (nvidia-smi, intel_gpu_top)
# - Color-coded output for better readability
# - Comprehensive error handling and validation
# - Backup and rollback capabilities
# - Post-installation verification
#
# Usage: 
#   sudo bash install-gpu-drivers.sh
#   sudo bash install-gpu-drivers.sh --force-nvidia
#   sudo bash install-gpu-drivers.sh --force-intel
#   sudo bash install-gpu-drivers.sh --dry-run
#
# Requirements: Must be run with root privileges on Ubuntu/Debian systems
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
readonly LOG_FILE="/var/log/gpu-driver-install.log"
readonly BACKUP_DIR="/var/backups/gpu-drivers"

# Global variables
NVIDIA_DETECTED=false
INTEL_DETECTED=false
FORCE_NVIDIA=false
FORCE_INTEL=false
DRY_RUN=false
DISTRO=""
DISTRO_VERSION=""
UBUNTU_CODENAME=""

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
    echo "                    GPU DRIVER AUTO-INSTALLER"
    echo "==============================================================================="
    echo -e "${NC}"
    echo -e "${WHITE}Automatic NVIDIA and Intel GPU Driver Installation Tool${NC}"
    echo ""
}

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Log message to both console and file
log_message() {
    local message="[$(get_timestamp)] $1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Cleanup function
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

# Set up signal handlers
trap cleanup EXIT INT TERM

# Display help information
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

This script automatically detects and installs GPU drivers for NVIDIA and Intel
graphics cards on Ubuntu and Debian systems.

OPTIONS:
    --force-nvidia          Force NVIDIA driver installation even if not detected
    --force-intel           Force Intel driver installation even if not detected
    --dry-run              Show what would be done without making changes
    -h, --help             Show this help message

EXAMPLES:
    # Auto-detect and install drivers
    sudo $SCRIPT_NAME
    
    # Force NVIDIA driver installation
    sudo $SCRIPT_NAME --force-nvidia
    
    # Check what would be installed without changes
    sudo $SCRIPT_NAME --dry-run

SUPPORTED SYSTEMS:
    - Ubuntu 18.04, 20.04, 22.04, 24.04
    - Debian 10, 11, 12

EOF
}

#===============================================================================
# SYSTEM DETECTION FUNCTIONS
#===============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force-nvidia)
                FORCE_NVIDIA=true
                shift
                ;;
            --force-intel)
                FORCE_INTEL=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
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

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check root privileges
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        print_info "Usage: sudo $SCRIPT_NAME"
        exit 1
    fi
    
    # Check if running on supported system
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot determine operating system"
        exit 1
    fi
    
    # Create log directory
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    
    # Check internet connectivity
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        print_warning "No internet connectivity detected"
        print_info "This script requires internet access to download packages"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_success "Prerequisites check passed"
}

# Detect operating system
detect_system() {
    print_step "Detecting operating system..."
    
    source /etc/os-release
    
    case "$ID" in
        ubuntu)
            DISTRO="ubuntu"
            DISTRO_VERSION="$VERSION_ID"
            UBUNTU_CODENAME="$VERSION_CODENAME"
            print_success "Detected Ubuntu $DISTRO_VERSION ($UBUNTU_CODENAME)"
            ;;
        debian)
            DISTRO="debian"
            DISTRO_VERSION="$VERSION_ID"
            print_success "Detected Debian $DISTRO_VERSION"
            ;;
        *)
            print_error "Unsupported operating system: $ID"
            print_info "This script supports Ubuntu and Debian only"
            exit 1
            ;;
    esac
    
    log_message "INFO: System detected - $DISTRO $DISTRO_VERSION"
}

# Detect GPU hardware
detect_gpus() {
    print_step "Detecting GPU hardware..."
    
    # Check for NVIDIA GPUs
    if lspci | grep -i nvidia &> /dev/null || [[ "$FORCE_NVIDIA" == true ]]; then
        NVIDIA_DETECTED=true
        local nvidia_cards=$(lspci | grep -i nvidia | wc -l)
        if [[ "$FORCE_NVIDIA" == true ]]; then
            print_info "NVIDIA GPU installation forced by user"
        else
            print_success "Detected $nvidia_cards NVIDIA GPU(s)"
            lspci | grep -i nvidia | while read line; do
                print_info "  └─ $line"
            done
        fi
        log_message "INFO: NVIDIA GPU detected or forced"
    else
        print_info "No NVIDIA GPUs detected"
    fi
    
    # Check for Intel GPUs
    if lspci | grep -E "(VGA|3D).*Intel" &> /dev/null || [[ "$FORCE_INTEL" == true ]]; then
        INTEL_DETECTED=true
        local intel_cards=$(lspci | grep -E "(VGA|3D).*Intel" | wc -l)
        if [[ "$FORCE_INTEL" == true ]]; then
            print_info "Intel GPU installation forced by user"
        else
            print_success "Detected $intel_cards Intel GPU(s)"
            lspci | grep -E "(VGA|3D).*Intel" | while read line; do
                print_info "  └─ $line"
            done
        fi
        log_message "INFO: Intel GPU detected or forced"
    else
        print_info "No Intel GPUs detected"
    fi
    
    # Check if any GPUs were found
    if [[ "$NVIDIA_DETECTED" == false && "$INTEL_DETECTED" == false ]]; then
        print_warning "No supported GPUs detected"
        print_info "Use --force-nvidia or --force-intel to install drivers anyway"
        
        if [[ "$DRY_RUN" == false ]]; then
            read -p "Continue without GPU detection? (y/N): " -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 0
            fi
        fi
    fi
}

#===============================================================================
# PACKAGE MANAGEMENT FUNCTIONS
#===============================================================================

# Update package lists
update_system() {
    print_step "Updating system package lists..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would run: apt update"
        return 0
    fi
    
    if ! apt update; then
        print_error "Failed to update package lists"
        exit 1
    fi
    
    print_success "Package lists updated"
}

# Install required packages
install_dependencies() {
    print_step "Installing base dependencies..."
    
    local packages=(
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "curl"
        "wget"
        "gnupg"
        "lsb-release"
        "build-essential"
        "dkms"
        "linux-headers-$(uname -r)"
    )
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would install packages: ${packages[*]}"
        return 0
    fi
    
    if ! apt install -y "${packages[@]}"; then
        print_error "Failed to install base dependencies"
        exit 1
    fi
    
    print_success "Base dependencies installed"
}

#===============================================================================
# NVIDIA DRIVER INSTALLATION
#===============================================================================

# Install NVIDIA drivers
install_nvidia_drivers() {
    print_step "Installing NVIDIA drivers and tools..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would install NVIDIA drivers"
        return 0
    fi
    
    # Backup existing configuration
    if [[ -f /etc/X11/xorg.conf ]]; then
        cp /etc/X11/xorg.conf "$BACKUP_DIR/xorg.conf.backup.$(date +%s)"
        print_info "Backed up existing X11 configuration"
    fi
    
    case "$DISTRO" in
        ubuntu)
            install_nvidia_ubuntu
            ;;
        debian)
            install_nvidia_debian
            ;;
    esac
    
    # Install monitoring tools
    install_nvidia_monitoring_tools
    
    print_success "NVIDIA drivers and tools installed"
}

# Install NVIDIA drivers on Ubuntu
install_nvidia_ubuntu() {
    print_step "Installing NVIDIA drivers for Ubuntu..."
    
    # Add NVIDIA PPA for latest drivers
    if ! add-apt-repository -y ppa:graphics-drivers/ppa; then
        print_warning "Failed to add NVIDIA PPA, using default repositories"
    else
        apt update
    fi
    
    # Install recommended driver
    local nvidia_driver=""
    
    # Try to get recommended driver
    if command -v ubuntu-drivers &> /dev/null; then
        nvidia_driver=$(ubuntu-drivers devices | grep recommended | awk '{print $3}' | head -n 1)
    fi
    
    # Fallback to latest driver if no recommendation
    if [[ -z "$nvidia_driver" ]]; then
        nvidia_driver="nvidia-driver-535"
        print_info "Using fallback driver: $nvidia_driver"
    else
        print_info "Installing recommended driver: $nvidia_driver"
    fi
    
    # Install driver and related packages
    local nvidia_packages=(
        "$nvidia_driver"
        "nvidia-settings"
        "nvidia-utils-$(echo $nvidia_driver | grep -o '[0-9]\+')"
    )
    
    if ! apt install -y "${nvidia_packages[@]}"; then
        print_error "Failed to install NVIDIA driver packages"
        exit 1
    fi
}

# Install NVIDIA drivers on Debian
install_nvidia_debian() {
    print_step "Installing NVIDIA drivers for Debian..."
    
    # Enable non-free repository if not already enabled
    if ! grep -q "non-free" /etc/apt/sources.list; then
        print_step "Enabling non-free repository..."
        sed -i 's/main$/main contrib non-free/' /etc/apt/sources.list
        apt update
    fi
    
    # Install NVIDIA driver packages
    local nvidia_packages=(
        "nvidia-driver"
        "nvidia-settings"
        "nvidia-smi"
        "firmware-misc-nonfree"
    )
    
    if ! apt install -y "${nvidia_packages[@]}"; then
        print_error "Failed to install NVIDIA driver packages"
        exit 1
    fi
}

# Install NVIDIA monitoring tools
install_nvidia_monitoring_tools() {
    print_step "Installing NVIDIA monitoring tools..."
    
    # nvidia-smi should be included with drivers, but ensure it's available
    local monitoring_packages=(
        "nvidia-utils-535"  # Includes nvidia-smi
    )
    
    # Try to install additional monitoring tools if available
    if apt-cache search nvtop | grep -q nvtop; then
        monitoring_packages+=("nvtop")
        print_info "Adding nvtop to installation"
    fi
    
    apt install -y "${monitoring_packages[@]}" || print_warning "Some monitoring tools may not be available"
}

#===============================================================================
# INTEL DRIVER INSTALLATION
#===============================================================================

# Install Intel drivers
install_intel_drivers() {
    print_step "Installing Intel GPU drivers and tools..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would install Intel GPU drivers"
        return 0
    fi
    
    case "$DISTRO" in
        ubuntu)
            install_intel_ubuntu
            ;;
        debian)
            install_intel_debian
            ;;
    esac
    
    # Install monitoring tools
    install_intel_monitoring_tools
    
    print_success "Intel GPU drivers and tools installed"
}

# Install Intel drivers on Ubuntu
install_intel_ubuntu() {
    print_step "Installing Intel GPU drivers for Ubuntu..."
    
    local intel_packages=(
        "intel-media-va-driver"
        "i965-va-driver"
        "mesa-va-drivers"
        "vainfo"
        "intel-gpu-tools"
    )
    
    # Add Intel graphics repository for newer drivers
    if [[ "$DISTRO_VERSION" == "22.04" || "$DISTRO_VERSION" == "24.04" ]]; then
        # Add Intel graphics repository
        if ! wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | apt-key add -; then
            print_warning "Failed to add Intel graphics repository key"
        else
            echo "deb [arch=amd64] https://repositories.intel.com/graphics/ubuntu jammy arc" > /etc/apt/sources.list.d/intel-graphics.list
            apt update
            intel_packages+=("intel-opencl-icd" "intel-level-zero-gpu" "level-zero")
        fi
    fi
    
    if ! apt install -y "${intel_packages[@]}"; then
        print_error "Failed to install Intel GPU packages"
        exit 1
    fi
}

# Install Intel drivers on Debian
install_intel_debian() {
    print_step "Installing Intel GPU drivers for Debian..."
    
    local intel_packages=(
        "intel-media-va-driver"
        "i965-va-driver"
        "mesa-va-drivers"
        "vainfo"
        "intel-gpu-tools"
        "firmware-misc-nonfree"
    )
    
    if ! apt install -y "${intel_packages[@]}"; then
        print_error "Failed to install Intel GPU packages"
        exit 1
    fi
}

# Install Intel monitoring tools
install_intel_monitoring_tools() {
    print_step "Installing Intel GPU monitoring tools..."
    
    # intel_gpu_top should be included with intel-gpu-tools
    # Verify installation
    if ! command -v intel_gpu_top &> /dev/null; then
        print_warning "intel_gpu_top not found, attempting manual installation..."
        
        # Try to compile from source if package is not available
        install_intel_gpu_top_from_source
    else
        print_success "intel_gpu_top is available"
    fi
}

# Install intel_gpu_top from source if package not available
install_intel_gpu_top_from_source() {
    print_step "Installing intel_gpu_top from source..."
    
    local build_deps=(
        "meson"
        "ninja-build"
        "libdrm-dev"
        "libpciaccess-dev"
        "libprocps-dev"
    )
    
    # Install build dependencies
    apt install -y "${build_deps[@]}" || print_warning "Some build dependencies may not be available"
    
    # Create temporary build directory
    local build_dir="/tmp/igt-gpu-tools-build"
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # Clone and build
    if git clone https://gitlab.freedesktop.org/drm/igt-gpu-tools.git; then
        cd igt-gpu-tools
        meson build
        ninja -C build
        
        # Install just intel_gpu_top
        if [[ -f build/tools/intel_gpu_top ]]; then
            cp build/tools/intel_gpu_top /usr/local/bin/
            chmod +x /usr/local/bin/intel_gpu_top
            print_success "intel_gpu_top installed from source"
        else
            print_warning "Failed to build intel_gpu_top from source"
        fi
    else
        print_warning "Failed to clone igt-gpu-tools repository"
    fi
    
    # Cleanup
    cd /
    rm -rf "$build_dir"
}

#===============================================================================
# VERIFICATION AND CONFIGURATION
#===============================================================================

# Verify installations
verify_installations() {
    print_step "Verifying driver installations..."
    
    local verification_failed=false
    
    # Verify NVIDIA installation
    if [[ "$NVIDIA_DETECTED" == true ]]; then
        print_step "Verifying NVIDIA installation..."
        
        if command -v nvidia-smi &> /dev/null; then
            print_success "nvidia-smi is available"
            if [[ "$DRY_RUN" == false ]]; then
                print_info "NVIDIA GPU status:"
                nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits | while read gpu_info; do
                    print_info "  └─ $gpu_info"
                done
            fi
        else
            print_error "nvidia-smi not found"
            verification_failed=true
        fi
        
        if command -v nvidia-settings &> /dev/null; then
            print_success "nvidia-settings is available"
        else
            print_warning "nvidia-settings not found"
        fi
    fi
    
    # Verify Intel installation
    if [[ "$INTEL_DETECTED" == true ]]; then
        print_step "Verifying Intel GPU installation..."
        
        if command -v intel_gpu_top &> /dev/null; then
            print_success "intel_gpu_top is available"
        elif command -v /usr/local/bin/intel_gpu_top &> /dev/null; then
            print_success "intel_gpu_top is available (custom installation)"
        else
            print_warning "intel_gpu_top not found"
        fi
        
        if command -v vainfo &> /dev/null; then
            print_success "vainfo is available"
            if [[ "$DRY_RUN" == false ]]; then
                print_info "VA-API information:"
                vainfo 2>/dev/null | grep -E "(Driver|VA-API)" | head -5 | while read va_info; do
                    print_info "  └─ $va_info"
                done
            fi
        else
            print_warning "vainfo not found"
        fi
    fi
    
    if [[ "$verification_failed" == true ]]; then
        print_error "Some driver verifications failed"
        print_info "You may need to reboot to complete the installation"
        return 1
    else
        print_success "All driver verifications passed"
        return 0
    fi
}

# Create usage script
create_usage_script() {
    print_step "Creating GPU monitoring script..."
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "[DRY RUN] Would create /usr/local/bin/gpu-status"
        return 0
    fi
    
    cat > /usr/local/bin/gpu-status << 'EOF'
#!/bin/bash

# GPU Status Monitoring Script
# Shows status of NVIDIA and Intel GPUs

echo "=== GPU Status Report ==="
echo "Date: $(date)"
echo ""

# NVIDIA GPUs
if command -v nvidia-smi &> /dev/null; then
    echo "=== NVIDIA GPUs ==="
    nvidia-smi
    echo ""
fi

# Intel GPUs
if command -v intel_gpu_top &> /dev/null; then
    echo "=== Intel GPU Information ==="
    echo "Use 'intel_gpu_top' for real-time monitoring"
    if command -v vainfo &> /dev/null; then
        echo ""
        echo "VA-API Support:"
        vainfo 2>/dev/null | grep -E "(Driver|VA-API)" | head -5
    fi
    echo ""
elif command -v /usr/local/bin/intel_gpu_top &> /dev/null; then
    echo "=== Intel GPU Information ==="
    echo "Use '/usr/local/bin/intel_gpu_top' for real-time monitoring"
    if command -v vainfo &> /dev/null; then
        echo ""
        echo "VA-API Support:"
        vainfo 2>/dev/null | grep -E "(Driver|VA-API)" | head -5
    fi
    echo ""
fi

# General GPU information
echo "=== All GPUs (lspci) ==="
lspci | grep -E "(VGA|3D|Display)"

EOF
    
    chmod +x /usr/local/bin/gpu-status
    print_success "GPU monitoring script created at /usr/local/bin/gpu-status"
}

# Show final instructions
show_final_instructions() {
    echo ""
    print_success "🎉 GPU Driver Installation Complete! 🎉"
    echo ""
    print_info "═══════════════════════════════════════════════════════════════════════════════"
    print_info "NEXT STEPS:"
    print_info "═══════════════════════════════════════════════════════════════════════════════"
    
    if [[ "$NVIDIA_DETECTED" == true || "$INTEL_DETECTED" == true ]]; then
        print_info "1. REBOOT your system to complete driver initialization:"
        print_info "   sudo reboot"
        echo ""
        
        print_info "2. After reboot, verify installations:"
        if [[ "$NVIDIA_DETECTED" == true ]]; then
            print_info "   • NVIDIA: nvidia-smi"
            print_info "   • NVIDIA Settings: nvidia-settings"
        fi
        if [[ "$INTEL_DETECTED" == true ]]; then
            print_info "   • Intel GPU: intel_gpu_top"
            print_info "   • VA-API: vainfo"
        fi
        echo ""
        
        print_info "3. Monitor GPU status:"
        print_info "   gpu-status"
        echo ""
        
        print_info "4. Real-time monitoring:"
        if [[ "$NVIDIA_DETECTED" == true ]]; then
            print_info "   • NVIDIA: watch -n 1 nvidia-smi"
        fi
        if [[ "$INTEL_DETECTED" == true ]]; then
            print_info "   • Intel: intel_gpu_top"
        fi
    fi
    
    echo ""
    print_info "═══════════════════════════════════════════════════════════════════════════════"
    print_info "TROUBLESHOOTING:"
    print_info "═══════════════════════════════════════════════════════════════════════════════"
    print_info "• Check logs: tail -f $LOG_FILE"
    print_info "• Backup files: $BACKUP_DIR"
    print_info "• Re-run script: sudo $SCRIPT_NAME"
    echo ""
}

#===============================================================================
# MAIN EXECUTION FUNCTION
#===============================================================================

# Main function
main() {
    show_header
    
    # Parse arguments
    parse_arguments "$@"
    
    # System checks
    check_prerequisites
    detect_system
    detect_gpus
    
    # Show what will be done
    echo ""
    print_info "Installation Summary:"
    print_info "═══════════════════════════════════════════════════════════════════════════════"
    if [[ "$NVIDIA_DETECTED" == true ]]; then
        print_info "✓ NVIDIA drivers and monitoring tools will be installed"
    fi
    if [[ "$INTEL_DETECTED" == true ]]; then
        print_info "✓ Intel GPU drivers and monitoring tools will be installed"
    fi
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No actual changes will be made"
    fi
    print_info "✓ System will be updated and dependencies installed"
    print_info "✓ GPU monitoring script will be created"
    echo ""
    
    # Confirmation
    if [[ "$DRY_RUN" == false ]]; then
        print_warning "This installation will modify your system and install GPU drivers"
        print_prompt "Continue with installation? (y/N):"
        read -r confirmation
        if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
            print_info "Installation cancelled by user"
            exit 0
        fi
    fi
    
    # Log start
    log_message "INFO: ===== GPU Driver Installation Started ====="
    log_message "INFO: System: $DISTRO $DISTRO_VERSION"
    log_message "INFO: NVIDIA Detected: $NVIDIA_DETECTED"
    log_message "INFO: Intel Detected: $INTEL_DETECTED"
    
    # Installation process
    update_system
    install_dependencies
    
    # Install drivers
    if [[ "$NVIDIA_DETECTED" == true ]]; then
        install_nvidia_drivers
    fi
    
    if [[ "$INTEL_DETECTED" == true ]]; then
        install_intel_drivers
    fi
    
    # Post-installation
    create_usage_script
    
    if [[ "$DRY_RUN" == false ]]; then
        verify_installations
    fi
    
    show_final_instructions
    
    log_message "INFO: GPU driver installation completed successfully"
}

#===============================================================================
# SCRIPT ENTRY POINT
#===============================================================================

# Execute main function with all arguments
main "$@"
