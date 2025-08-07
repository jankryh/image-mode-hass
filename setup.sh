#!/bin/bash
# Home Assistant bootc Setup Script
# Simple setup for Home Assistant bootc deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Show welcome message
show_welcome() {
    echo "=============================================="
    echo "   Home Assistant bootc Setup"
    echo "=============================================="
    echo ""
    echo "This script will help you set up your Home Assistant bootc environment."
    echo ""
    echo "The project uses a simplified configuration system for easy setup."
    echo ""
}

# Setup configuration
setup_config() {
    log "Setting up configuration..."
    
    # Check if config.mk already exists
    if [[ -f "config.mk" ]]; then
        warn "⚠️ config.mk already exists"
        read -p "Do you want to overwrite it? (y/N): " overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            log "Keeping existing config.mk"
            return 0
        fi
    fi
    
    # Copy configuration template
    if [[ -f "config-example.mk" ]]; then
        cp config-example.mk config.mk
        log "✅ Copied config-example.mk to config.mk"
    else
        # Create basic config.mk if no template exists
        cat > config.mk << 'EOF'
# Home Assistant bootc Configuration
# Essential settings for building and deploying Home Assistant bootc images

#==========================================
# Basic Configuration
#==========================================

# Container image name
IMAGE_NAME ?= fedora-bootc-hass

# Container registry
REGISTRY ?= quay.io/yourusername

# Image tag
IMAGE_TAG ?= latest

# Configuration file for bootc image builder
CONFIG_FILE ?= config-production.toml

# Output directory
OUTPUT_DIR ?= ./output

# Container runtime
CONTAINER_RUNTIME ?= podman

# Sudo command
SUDO_CMD ?= sudo

#==========================================
# Build Configuration
#==========================================

# Root filesystem type
ROOTFS_TYPE ?= ext4

# Timezone
TIMEZONE ?= Europe/Prague

# Build optimization
USE_CACHE ?= true
VERBOSE ?= false

# Build resources
BUILD_MEMORY ?= 4g
BUILD_CPUS ?= $(shell nproc)

#==========================================
# VM Configuration
#==========================================

# VM settings
VM_NAME ?= home-assistant-bootc
VM_MEMORY ?= 4096
VM_VCPUS ?= 2
VM_NETWORK ?= default
VM_GRAPHICS ?= spice
VM_OS_VARIANT ?= rhel9.0
EOF
        log "✅ Created basic config.mk"
    fi
    
    log "Configuration setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Edit config.mk with your settings (especially REGISTRY)"
    echo "2. Run: sudo make build"
    echo "3. Run: sudo make qcow2"
    echo "4. Run: sudo make deploy-vm"
    echo ""
    echo "For help, see README.md"
}

# Check requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check for podman
    if ! command -v podman >/dev/null 2>&1; then
        error "❌ Podman is not installed"
        echo "Install podman with: sudo dnf install podman"
        return 1
    else
        log "✅ Podman is installed"
    fi
    
    # Check for make
    if ! command -v make >/dev/null 2>&1; then
        error "❌ Make is not installed"
        echo "Install make with: sudo dnf install make"
        return 1
    else
        log "✅ Make is installed"
    fi
    
    # Check for sudo
    if ! command -v sudo >/dev/null 2>&1; then
        warn "⚠️ Sudo is not available"
    else
        log "✅ Sudo is available"
    fi
    
    log "System requirements check complete!"
}

# Main function
main() {
    show_welcome
    
    # Check requirements
    check_requirements || exit 1
    
    # Setup configuration
    setup_config
    
    echo ""
    log "Setup complete! You can now build your Home Assistant bootc image."
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
