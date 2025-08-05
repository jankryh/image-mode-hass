#!/bin/bash
# Check and configure Podman mode (rootless vs rootful)
# This script helps identify the best Podman configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "==================================="
echo "   Podman Mode Detection"
echo "==================================="
echo ""

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    error "Podman is not installed"
    echo "Install Podman first: sudo dnf install podman"
    exit 1
fi

info "Podman version: $(podman --version)"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    warn "Running as root - rootful mode will be used"
    PODMAN_MODE="rootful"
else
    info "Running as user: $USER"
    PODMAN_MODE="rootless"
fi

# Check rootless prerequisites
echo "Checking rootless prerequisites..."

# User namespaces
if [[ -f /proc/sys/user/max_user_namespaces ]]; then
    max_userns=$(cat /proc/sys/user/max_user_namespaces)
    if [[ $max_userns -gt 0 ]]; then
        success "User namespaces enabled (max: $max_userns)"
    else
        error "User namespaces disabled"
        echo "Enable with: sudo sysctl -w user.max_user_namespaces=28633"
    fi
else
    warn "Cannot check user namespace status"
fi

# Subuid/subgid
if [[ $EUID -ne 0 ]]; then
    if grep -q "^$USER:" /etc/subuid 2>/dev/null; then
        subuid_range=$(grep "^$USER:" /etc/subuid | cut -d: -f2-3)
        success "Subuid configured: $subuid_range"
    else
        error "No subuid entry for $USER"
        echo "Add with: sudo usermod --add-subuids 100000-165536 $USER"
    fi
    
    if grep -q "^$USER:" /etc/subgid 2>/dev/null; then
        subgid_range=$(grep "^$USER:" /etc/subgid | cut -d: -f2-3)
        success "Subgid configured: $subgid_range"
    else
        error "No subgid entry for $USER"
        echo "Add with: sudo usermod --add-subgids 100000-165536 $USER"
    fi
fi

# Check Podman socket
echo ""
echo "Checking Podman socket..."
if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && [[ -S "$XDG_RUNTIME_DIR/podman/podman.sock" ]]; then
    success "Rootless Podman socket found: $XDG_RUNTIME_DIR/podman/podman.sock"
    SOCKET_MODE="rootless"
elif [[ -S "/run/podman/podman.sock" ]]; then
    info "Rootful Podman socket found: /run/podman/podman.sock"
    SOCKET_MODE="rootful"
else
    warn "No Podman socket found"
    echo "Start with: systemctl --user start podman.socket (rootless)"
    echo "Or: sudo systemctl start podman.socket (rootful)"
    SOCKET_MODE="none"
fi

# Check storage configuration
echo ""
echo "Checking storage configuration..."
if [[ $PODMAN_MODE == "rootless" ]]; then
    storage_conf="$HOME/.config/containers/storage.conf"
    if [[ -f "$storage_conf" ]]; then
        success "User storage configuration found"
        storage_driver=$(grep -E "^\s*driver\s*=" "$storage_conf" | cut -d'"' -f2)
        info "Storage driver: ${storage_driver:-default}"
    else
        warn "No user storage configuration"
        echo "Podman will use defaults"
    fi
fi

# Check for required tools
echo ""
echo "Checking required tools..."
tools=("fuse-overlayfs" "slirp4netns" "pasta")
for tool in "${tools[@]}"; do
    if command -v "$tool" &> /dev/null; then
        success "$tool installed"
    else
        warn "$tool not found (optional but recommended)"
    fi
done

# Generate recommendations
echo ""
echo "==================================="
echo "   Recommendations"
echo "==================================="

if [[ $PODMAN_MODE == "rootless" ]]; then
    echo "✓ Rootless mode is recommended for better security"
    echo ""
    echo "Configuration for your environment:"
    echo "export CONTAINER_RUNTIME=podman"
    echo "export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock"
    echo ""
    echo "For Makefile:"
    echo "make build SUDO_CMD="
else
    echo "⚠ Rootful mode detected"
    echo "Consider switching to rootless for better security"
    echo ""
    echo "Configuration for your environment:"
    echo "export CONTAINER_RUNTIME=podman"
    echo "export SUDO_CMD=sudo"
fi

# Test Podman functionality
echo ""
echo "Testing Podman functionality..."
if podman info &> /dev/null; then
    success "Podman is working correctly"
    
    # Show key info
    echo ""
    echo "Podman Info:"
    podman info --format "{{.Host.RuntimeInfo.Name}}: {{.Version.Version}}"
    podman info --format "Storage: {{.Store.GraphDriverName}} ({{.Store.GraphRoot}})"
    podman info --format "Network: {{.Host.NetworkBackend}}"
else
    error "Podman test failed"
    echo "Check: podman info"
fi

echo ""
echo "==================================="
echo "   Summary"
echo "==================================="
echo "Mode: $PODMAN_MODE"
echo "Socket: $SOCKET_MODE"
if [[ $PODMAN_MODE == "rootless" ]]; then
    echo "Status: Ready for rootless operation"
else
    echo "Status: Running in rootful mode"
fi