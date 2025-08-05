#!/bin/bash
# Home Assistant restore script
# Usage: ./restore-hass.sh <backup_directory>

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if backup directory is provided
if [ $# -eq 0 ]; then
    error "Usage: $0 <backup_directory>"
    echo "Available backups:"
    if compgen -G "/var/home-assistant/backups/hass-backup-*" > /dev/null 2>&1; then
        ls -la /var/home-assistant/backups/hass-backup-* 2>/dev/null
    else
        echo "No backups found"
    fi
    exit 1
fi

BACKUP_PATH="$1"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Verify backup directory exists
if [ ! -d "${BACKUP_PATH}" ]; then
    error "Backup directory does not exist: ${BACKUP_PATH}"
    exit 1
fi

# Verify backup manifest
if [ ! -f "${BACKUP_PATH}/manifest.txt" ]; then
    error "Backup manifest not found. This may not be a valid backup."
    exit 1
fi

log "Starting restoration from ${BACKUP_PATH}"
log "Backup information:"
cat "${BACKUP_PATH}/manifest.txt"

# Confirmation prompt
echo ""
read -p "Are you sure you want to restore from this backup? This will overwrite current configuration. (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Restoration cancelled by user"
    exit 0
fi

# Stop Home Assistant
log "Stopping Home Assistant..."
systemctl stop home-assistant || warn "Failed to stop Home Assistant service"
sleep 5

# Backup current configuration (just in case)
if [ -d "/var/home-assistant/config" ]; then
    log "Creating safety backup of current configuration..."
    mv /var/home-assistant/config "/var/home-assistant/config.backup.$(date +%Y%m%d_%H%M%S)" || warn "Failed to backup current config"
fi

# Restore Home Assistant configuration
if [ -f "${BACKUP_PATH}/hass-config.tar.gz" ]; then
    log "Restoring Home Assistant configuration..."
    mkdir -p /var/home-assistant/config
    tar -xzf "${BACKUP_PATH}/hass-config.tar.gz" -C /var/home-assistant/config
    log "Configuration restored"
else
    warn "Home Assistant configuration backup not found"
fi

# Restore database
if [ -f "${BACKUP_PATH}/home-assistant_v2.db" ]; then
    log "Restoring Home Assistant database..."
    cp "${BACKUP_PATH}/home-assistant_v2.db" /var/home-assistant/config/
    log "Database restored"
else
    warn "Home Assistant database backup not found"
fi

# Restore ZeroTier configuration
if [ -f "${BACKUP_PATH}/zerotier-config.tar.gz" ]; then
    log "Restoring ZeroTier configuration..."
    systemctl stop zerotier-one || warn "Failed to stop ZeroTier"
    rm -rf /var/lib/zerotier-one/* 2>/dev/null || true
    tar -xzf "${BACKUP_PATH}/zerotier-config.tar.gz" -C /var/lib/zerotier-one
    systemctl start zerotier-one || warn "Failed to start ZeroTier"
    log "ZeroTier configuration restored"
else
    warn "ZeroTier configuration backup not found"
fi

# Set proper permissions
log "Setting proper permissions..."
chown -R root:root /var/home-assistant/config
chmod -R 755 /var/home-assistant/config

# Start Home Assistant
log "Starting Home Assistant..."
systemctl start home-assistant || warn "Failed to start Home Assistant service"

log "Restoration completed successfully!"
log "Home Assistant should be starting up with the restored configuration..."
log "Check the logs with: journalctl -u home-assistant -f"

exit 0