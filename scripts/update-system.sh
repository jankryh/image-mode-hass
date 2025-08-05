#!/bin/bash
# Home Assistant system update script
# Usage: ./update-system.sh [--auto] [--no-reboot]

set -euo pipefail

AUTO_MODE=false
NO_REBOOT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            AUTO_MODE=true
            shift
            ;;
        --no-reboot)
            NO_REBOOT=true
            shift
            ;;
        *)
            echo "Usage: $0 [--auto] [--no-reboot]"
            echo "  --auto      Don't ask for confirmation"
            echo "  --no-reboot Don't reboot after update"
            exit 1
            ;;
    esac
done

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

# Check if bootc is available
if ! command -v bootc &> /dev/null; then
    error "bootc command not found. This script requires bootc."
    exit 1
fi

log "Starting Home Assistant system update process..."

# Get current bootc status
log "Checking current system status..."
echo "Current bootc status:"
bootc status

echo ""

# Check for available updates
log "Checking for available updates..."
if bootc upgrade --check 2>/dev/null; then
    log "Updates are available"
else
    update_exit_code=$?
    if [[ $update_exit_code -eq 0 ]]; then
        log "System is already up to date"
        exit 0
    else
        warn "Unable to check for updates (exit code: $update_exit_code)"
    fi
fi

# Pre-update health check
log "Running pre-update health check..."
if /opt/hass-scripts/health-check.sh > /tmp/pre-update-health.log 2>&1; then
    log "Pre-update health check passed"
else
    warn "Pre-update health check found issues. Check /tmp/pre-update-health.log"
    if [[ "$AUTO_MODE" != true ]]; then
        read -p "Continue with update despite health check warnings? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Update cancelled by user"
            exit 0
        fi
    fi
fi

# Create backup before update
log "Creating backup before update..."
if /opt/hass-scripts/backup-hass.sh /var/home-assistant/backups > /tmp/pre-update-backup.log 2>&1; then
    log "Pre-update backup completed successfully"
else
    error "Pre-update backup failed. Check /tmp/pre-update-backup.log"
    if [[ "$AUTO_MODE" != true ]]; then
        read -p "Continue without backup? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Update cancelled by user"
            exit 1
        fi
    else
        log "Continuing update in auto mode despite backup failure..."
    fi
fi

# Confirmation prompt (unless in auto mode)
if [[ "$AUTO_MODE" != true ]]; then
    echo ""
    warn "This will update the system and may require a reboot."
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Update cancelled by user"
        exit 0
    fi
fi

# Record current deployment for potential rollback
current_deployment=$(bootc status --json | jq -r '.status.booted.image.image.image')
log "Current deployment: $current_deployment"

# Perform the update
log "Starting bootc upgrade..."
if bootc upgrade; then
    log "bootc upgrade completed successfully"
else
    error "bootc upgrade failed"
    exit 1
fi

# Check if reboot is needed
log "Checking if reboot is required..."
bootc status

if bootc status | grep -q "Staged"; then
    log "Update staged successfully. Reboot is required to apply changes."
    
    if [[ "$NO_REBOOT" == true ]]; then
        log "Reboot skipped due to --no-reboot flag"
        log "Remember to reboot manually to apply the update"
        exit 0
    fi
    
    if [[ "$AUTO_MODE" != true ]]; then
        read -p "Reboot now to apply the update? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log "Reboot postponed. Remember to reboot manually to apply the update"
            exit 0
        fi
    fi
    
    log "Rebooting system to apply update..."
    sync
    sleep 2
    reboot
else
    log "No reboot required or update already applied"
fi

log "System update process completed"