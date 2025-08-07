#!/bin/bash
# Simplified Dependency Management
# Basic dependency tracking and updates for Home Assistant bootc

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPS_FILE="$PROJECT_ROOT/dependencies.txt"
UPDATE_LOG="$PROJECT_ROOT/deps-update.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }
error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }

# Initialize dependencies file
init_deps() {
    log "Initializing dependency management..."
    
    if [[ ! -f "$DEPS_FILE" ]]; then
        cat > "$DEPS_FILE" << 'EOF'
# Home Assistant bootc Dependencies
# Format: package_name:current_version:min_version:update_policy

# Base images
fedora-bootc:42:42:manual
bootc-image-builder:latest:latest:auto

# System packages
openssh-server:8.9:8.0:security
fail2ban:0.11:0.11:security
chrony:4.4:4.0:auto
zerotier-one:1.12:1.10:auto
nut:2.8:2.7:auto

# Utilities
git:2.43:2.39:auto
htop:3.2:3.0:auto
jq:1.7:1.6:auto
vim-enhanced:9.0:8.2:auto

# Python packages
urllib3:2.5.0:2.5.0:security
requests:2.31:2.28:security
cryptography:41.0:39.0:security
EOF
        log "Created dependencies.txt"
    fi
}

# Check for updates
check_updates() {
    log "Checking for dependency updates..."
    
    local updates_found=0
    
    while IFS=: read -r package current_version min_version policy; do
        # Skip comments and empty lines
        [[ "$package" =~ ^#.*$ ]] && continue
        [[ -z "$package" ]] && continue
        
        case "$policy" in
            "security")
                log "Checking security updates for $package..."
                # Add security update logic here
                ;;
            "auto")
                log "Checking auto updates for $package..."
                # Add auto update logic here
                ;;
            "manual")
                log "Manual update policy for $package - skipping"
                ;;
        esac
    done < "$DEPS_FILE"
    
    if [[ $updates_found -eq 0 ]]; then
        log "No updates found"
    fi
}

# Update dependencies
update_deps() {
    log "Updating dependencies..."
    
    # Update system packages
    if command -v dnf >/dev/null 2>&1; then
        log "Updating system packages via dnf..."
        sudo dnf update -y --security
    elif command -v apt >/dev/null 2>&1; then
        log "Updating system packages via apt..."
        sudo apt update && sudo apt upgrade -y
    else
        warn "No supported package manager found"
    fi
    
    # Update Python packages
    log "Updating Python packages..."
    pip3 install --upgrade urllib3 requests cryptography
    
    log "Dependency update completed"
}

# Main function
main() {
    case "${1:-check}" in
        "init")
            init_deps
            ;;
        "check")
            init_deps
            check_updates
            ;;
        "update")
            init_deps
            update_deps
            ;;
        *)
            echo "Usage: $0 {init|check|update}"
            echo "  init   - Initialize dependency file"
            echo "  check  - Check for updates (default)"
            echo "  update - Update dependencies"
            exit 1
            ;;
    esac
}

main "$@"