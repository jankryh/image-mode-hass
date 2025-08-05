#!/bin/bash
# Home Assistant backup script
# Usage: ./backup-hass.sh [backup_location]

set -euo pipefail

# Source configuration
source "$(dirname "$0")/config.sh"

BACKUP_DIR="${1:-$HASS_BACKUP_DIR}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${BACKUP_PREFIX}-${DATE}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root"
   exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

# Create backup subdirectory
mkdir -p "${BACKUP_PATH}"

log "Starting Home Assistant backup to ${BACKUP_PATH}"

# Stop Home Assistant for consistent backup
log "Stopping Home Assistant..."
systemctl stop home-assistant || warn "Failed to stop Home Assistant service"
sleep 5

# Backup Home Assistant configuration
log "Backing up Home Assistant configuration..."
if [ -d "$HASS_CONFIG_DIR" ]; then
    tar -czf "${BACKUP_PATH}/hass-config.tar.gz" -C "$HASS_CONFIG_DIR" .
    log "Configuration backup completed"
else
    warn "Home Assistant config directory not found"
fi

# Backup database (if exists)
log "Backing up Home Assistant database..."
if [ -f "$HASS_CONFIG_DIR/home-assistant_v2.db" ]; then
    cp "$HASS_CONFIG_DIR/home-assistant_v2.db" "${BACKUP_PATH}/"
    log "Database backup completed"
else
    warn "Home Assistant database not found"
fi

# Backup ZeroTier configuration
log "Backing up ZeroTier configuration..."
if [ -d "/var/lib/zerotier-one" ]; then
    tar -czf "${BACKUP_PATH}/zerotier-config.tar.gz" -C /var/lib/zerotier-one .
    log "ZeroTier backup completed"
else
    warn "ZeroTier directory not found"
fi

# Backup system information
log "Backing up system information..."
{
    echo "=== System Information ==="
    hostnamectl
    echo ""
    echo "=== bootc Status ==="
    bootc status
    echo ""
    echo "=== Container Images ==="
    podman images
    echo ""
    echo "=== Running Containers ==="
    podman ps -a
    echo ""
    echo "=== systemd Services ==="
    systemctl list-units --type=service --state=running
} > "${BACKUP_PATH}/system-info.txt"

# Create backup manifest
log "Creating backup manifest..."
{
    echo "Backup created: $(date)"
    echo "Hostname: $(hostname)"
    echo "bootc version: $(bootc --version 2>/dev/null || echo 'unknown')"
    echo "Contents:"
    find "${BACKUP_PATH}" -type f -exec ls -lh {} \;
} > "${BACKUP_PATH}/manifest.txt"

# Restart Home Assistant
log "Starting Home Assistant..."
systemctl start home-assistant || warn "Failed to start Home Assistant service"

# Cleanup old backups (keep last 7 days)
log "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "hass-backup-*" -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

# Calculate backup size
BACKUP_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)

log "Backup completed successfully!"
log "Backup location: ${BACKUP_PATH}"
log "Backup size: ${BACKUP_SIZE}"
log "Home Assistant should be starting up now..."

exit 0