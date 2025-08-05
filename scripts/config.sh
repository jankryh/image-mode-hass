#!/bin/bash
# Central configuration file for Home Assistant bootc scripts
# This file defines all configurable paths and values

# System paths
export HASS_CONFIG_DIR="${HASS_CONFIG_DIR:-/var/home-assistant/config}"
export HASS_BACKUP_DIR="${HASS_BACKUP_DIR:-/var/home-assistant/backups}"
export HASS_SECRETS_DIR="${HASS_SECRETS_DIR:-/var/home-assistant/secrets}"
export HASS_LOG_DIR="${HASS_LOG_DIR:-/var/log/home-assistant}"
export HASS_SCRIPTS_DIR="${HASS_SCRIPTS_DIR:-/opt/hass-scripts}"
export HASS_SYSTEM_CONFIG_DIR="${HASS_SYSTEM_CONFIG_DIR:-/opt/hass-config}"

# Container settings
export CONTAINER_REGISTRY="${CONTAINER_REGISTRY:-quay.io/rh-ee-jkryhut}"
export CONTAINER_IMAGE_NAME="${CONTAINER_IMAGE_NAME:-fedora-bootc-hass}"
export CONTAINER_NAME="${CONTAINER_NAME:-home-assistant}"

# System settings
export SYSTEM_TIMEZONE="${SYSTEM_TIMEZONE:-Europe/Prague}"
export SYSTEM_LOCALE="${SYSTEM_LOCALE:-en_US.UTF-8}"
export SYSTEM_HOSTNAME="${SYSTEM_HOSTNAME:-home-assistant-server}"

# VM settings (for deployment)
export VM_NAME="${VM_NAME:-home-assistant-bootc}"
export VM_MEMORY="${VM_MEMORY:-4096}"
export VM_VCPUS="${VM_VCPUS:-2}"

# Backup settings
export BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
export BACKUP_PREFIX="${BACKUP_PREFIX:-hass-backup}"

# Service ports
export HASS_PORT="${HASS_PORT:-8123}"
export SSH_PORT="${SSH_PORT:-22}"

# User settings
export HASS_ADMIN_USER="${HASS_ADMIN_USER:-hass-admin}"
export HASS_ADMIN_GROUP="${HASS_ADMIN_GROUP:-wheel}"

# Enable/disable features
export ENABLE_ZEROTIER="${ENABLE_ZEROTIER:-true}"
export ENABLE_FAIL2BAN="${ENABLE_FAIL2BAN:-true}"
export ENABLE_AUTO_BACKUP="${ENABLE_AUTO_BACKUP:-true}"
export ENABLE_AUTO_UPDATE="${ENABLE_AUTO_UPDATE:-false}"

# Performance settings
export BUILD_MEMORY="${BUILD_MEMORY:-4g}"
export BUILD_CPUS="${BUILD_CPUS:-$(nproc)}"

# Function to load custom configuration
load_custom_config() {
    local custom_config="${1:-/etc/hass-scripts.conf}"
    if [[ -f "$custom_config" ]]; then
        # shellcheck source=/dev/null
        source "$custom_config"
    fi
}

# Function to validate configuration
validate_config() {
    local errors=0
    
    # Check required directories exist or can be created
    for dir in "$HASS_CONFIG_DIR" "$HASS_BACKUP_DIR" "$HASS_LOG_DIR"; do
        if [[ ! -d "$dir" ]] && ! mkdir -p "$dir" 2>/dev/null; then
            echo "ERROR: Cannot create directory: $dir"
            ((errors++))
        fi
    done
    
    # Check port numbers are valid
    if ! [[ "$HASS_PORT" =~ ^[0-9]+$ ]] || ((HASS_PORT < 1 || HASS_PORT > 65535)); then
        echo "ERROR: Invalid HASS_PORT: $HASS_PORT"
        ((errors++))
    fi
    
    if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || ((SSH_PORT < 1 || SSH_PORT > 65535)); then
        echo "ERROR: Invalid SSH_PORT: $SSH_PORT"
        ((errors++))
    fi
    
    return $errors
}

# Load custom configuration if it exists
load_custom_config

# Export all variables for use in other scripts
set -a