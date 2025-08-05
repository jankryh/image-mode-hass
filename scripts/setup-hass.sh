#!/bin/bash
# Home Assistant initial setup script
# Usage: ./setup-hass.sh

set -euo pipefail

# Source configuration
source "$(dirname "$0")/config.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

echo "========================================"
echo "   Home Assistant Initial Setup"
echo "========================================"
echo ""

# System information
info "System Information:"
echo "Hostname: $(hostname)"
echo "OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""

# Check prerequisites
log "Checking prerequisites..."

if ! command -v podman &> /dev/null; then
    error "Podman is not installed"
    exit 1
fi

if ! command -v bootc &> /dev/null; then
    warn "bootc is not available (this is normal on some systems)"
fi

if ! systemctl is-enabled --quiet podman.socket; then
    log "Enabling podman socket..."
    systemctl enable --now podman.socket
fi

log "Prerequisites check completed"
echo ""

# Network configuration
info "Network Configuration:"
ip_address=$(ip route get 8.8.8.8 | head -1 | awk '{print $7}')
echo "Primary IP: $ip_address"

# Configure firewall
log "Configuring firewall..."
if systemctl is-active --quiet firewalld; then
    # Add Home Assistant port
    if ! firewall-cmd --list-ports | grep -q "8123/tcp"; then
        firewall-cmd --add-port=8123/tcp --permanent
        log "Added Home Assistant port 8123/tcp"
    fi
    
    # Add SSH port
    if ! firewall-cmd --list-services | grep -q "ssh"; then
        firewall-cmd --add-service=ssh --permanent
        log "Added SSH service"
    fi
    
    firewall-cmd --reload
    log "Firewall configuration updated"
else
    warn "Firewalld is not running"
fi
echo ""

# Setup Home Assistant directories
log "Setting up Home Assistant directories..."
mkdir -p "$HASS_CONFIG_DIR"
mkdir -p "$HASS_BACKUP_DIR"
mkdir -p "$HASS_LOG_DIR"

# Set proper permissions
chown -R root:root "$(dirname "$HASS_CONFIG_DIR")"
chmod -R 755 "$(dirname "$HASS_CONFIG_DIR")"

log "Home Assistant directories created"
echo ""

# Start Home Assistant service
log "Starting Home Assistant service..."
if systemctl enable --now home-assistant; then
    log "Home Assistant service started successfully"
else
    error "Failed to start Home Assistant service"
    warn "You may need to check the systemd service configuration"
fi

# Wait for Home Assistant to start
log "Waiting for Home Assistant to initialize..."
sleep 30

# Check if Home Assistant is running
if systemctl is-active --quiet home-assistant; then
    log "Home Assistant is running"
    
    # Check if port is listening
    if ss -tlnp | grep -q ":8123"; then
        log "Home Assistant is listening on port 8123"
        echo ""
        info "Home Assistant should be accessible at:"
        echo "  http://$ip_address:8123"
        echo "  http://localhost:8123"
    else
        warn "Home Assistant port 8123 is not listening yet"
        warn "This is normal during first startup - it may take a few more minutes"
    fi
else
    error "Home Assistant service is not running"
    warn "Check logs with: journalctl -u home-assistant -f"
fi
echo ""

# ZeroTier setup
info "ZeroTier VPN Setup:"
if systemctl is-active --quiet zerotier-one; then
    log "ZeroTier service is running"
    echo "To join a ZeroTier network, run:"
    echo "  zerotier-cli join <NETWORK_ID>"
    echo "Then authorize the device in ZeroTier Central"
else
    warn "ZeroTier service is not running"
    warn "Start it with: systemctl enable --now zerotier-one"
fi
echo ""

# SSH setup
info "SSH Configuration:"
if systemctl is-active --quiet sshd; then
    log "SSH service is running"
    echo "SSH is available on port 22"
    
    # Show SSH configuration
    if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
        log "Password authentication is disabled (key-based auth only)"
    else
        warn "Password authentication is enabled"
        warn "Consider disabling it for better security"
    fi
    
    if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config; then
        log "Root login is disabled"
    else
        warn "Root login is enabled"
        warn "Consider disabling it for better security"
    fi
else
    warn "SSH service is not running"
    warn "Start it with: systemctl enable --now sshd"
fi
echo ""

# Create useful aliases and scripts
log "Setting up user convenience..."

# Add aliases to bashrc
if ! grep -q "# Home Assistant aliases" /root/.bashrc; then
    cat >> /root/.bashrc << 'EOF'

# Home Assistant aliases
alias hass-logs='journalctl -u home-assistant -f'
alias hass-status='systemctl status home-assistant'
alias hass-restart='systemctl restart home-assistant'
alias hass-backup='$HASS_SCRIPTS_DIR/backup-hass.sh'
alias hass-health='$HASS_SCRIPTS_DIR/health-check.sh'
alias hass-update='$HASS_SCRIPTS_DIR/update-system.sh'
EOF
    log "Added useful aliases to /root/.bashrc"
fi

# Make scripts executable (just in case)
chmod +x "$HASS_SCRIPTS_DIR"/*.sh

echo ""
log "Setup completed successfully!"
echo ""

info "Next Steps:"
echo "1. Access Home Assistant at http://$ip_address:8123"
echo "2. Complete the Home Assistant onboarding process"
echo "3. Configure ZeroTier if needed: zerotier-cli join <NETWORK_ID>"
echo "4. Set up regular backups: crontab -e"
echo "5. Consider setting up SSL/TLS with a reverse proxy"
echo ""

info "Useful Commands:"
echo "- Check system health: $HASS_SCRIPTS_DIR/health-check.sh"
echo "- Create backup: $HASS_SCRIPTS_DIR/backup-hass.sh"
echo "- Update system: $HASS_SCRIPTS_DIR/update-system.sh"
echo "- View Home Assistant logs: journalctl -u home-assistant -f"
echo ""

info "System is ready for use!"