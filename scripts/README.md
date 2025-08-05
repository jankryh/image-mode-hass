# Home Assistant Management Scripts

This directory contains useful scripts for managing the Home Assistant system on bootc.

## 📋 Available Scripts

### 🚀 setup-hass.sh
**Purpose**: Initial system setup after first boot
```bash
sudo /opt/hass-scripts/setup-hass.sh
```

**What it does:**
- Checks and configures system services
- Sets up firewall rules
- Creates necessary directories
- Starts Home Assistant
- Adds useful aliases

### 💾 backup-hass.sh
**Purpose**: Creating backups of configuration and data
```bash
sudo /opt/hass-scripts/backup-hass.sh [backup_location]
```

**Parameters:**
- `backup_location` (optional): Path to store backup (default: `/var/home-assistant/backups`)

**What it backs up:**
- Home Assistant configuration
- Home Assistant database
- ZeroTier configuration
- System information

### 🔄 restore-hass.sh
**Purpose**: Restore from backup
```bash
sudo /opt/hass-scripts/restore-hass.sh <backup_directory>
```

**Parameters:**
- `backup_directory` (required): Path to backup directory

**Safety features:**
- Creates safety backup of current configuration
- Requires confirmation before restoration
- Automatically restarts services

### 🔍 health-check.sh
**Purpose**: System health check
```bash
sudo /opt/hass-scripts/health-check.sh [--verbose]
```

**Parameters:**
- `--verbose` (optional): Detailed output

**What it checks:**
- System resources (RAM, disk, CPU)
- Service status
- Containers
- Network connectivity
- bootc status
- System logs

### 🔄 update-system.sh
**Purpose**: System update using bootc
```bash
sudo /opt/hass-scripts/update-system.sh [--auto] [--no-reboot]
```

**Parameters:**
- `--auto`: Automatic mode without confirmation
- `--no-reboot`: Don't reboot automatically

**Update process:**
1. Pre-update health check
2. Create backup
3. bootc upgrade
4. Restart (if needed)

## 🔧 Systemd Services

### Automatic Backups
```bash
# Enable daily backups at 2:00 AM
sudo systemctl enable --now hass-backup.timer

# Check status
sudo systemctl status hass-backup.timer
sudo systemctl list-timers hass-backup.timer
```

### Automatic Updates
```bash
# Enable weekly updates
sudo systemctl enable --now hass-auto-update.timer

# Check status
sudo systemctl status hass-auto-update.timer
```

## 🚨 Troubleshooting

### Scripts won't run
```bash
# Check permissions
ls -la /opt/hass-scripts/
sudo chmod +x /opt/hass-scripts/*.sh
```

### Backup fails
```bash
# Check disk space
df -h /var/home-assistant/backups/

# Check logs
sudo journalctl -u hass-backup.service -f
```

### Health check reports issues
```bash
# Run with verbose output
sudo /opt/hass-scripts/health-check.sh --verbose

# Check specific services
sudo systemctl status home-assistant zerotier-one
```

## 📚 Useful Aliases

After running `setup-hass.sh`, these aliases are available:

```bash
# Home Assistant logs
hass-logs

# Home Assistant status
hass-status

# Restart Home Assistant
hass-restart

# Create backup
hass-backup

# Health check
hass-health

# System update
hass-update
```

## 🔐 Security Notes

- All scripts require root privileges
- Backups contain sensitive data - protect them
- Updates automatically create backups before upgrade
- Health check doesn't contain sensitive information

## 📁 File Locations

```
/opt/hass-scripts/           # Scripts
/var/home-assistant/config/  # Home Assistant configuration
/var/home-assistant/backups/ # Backups
/var/log/home-assistant/     # Logs
```