# Home Assistant bootc Image

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![bootc](https://img.shields.io/badge/bootc-compatible-blue.svg)](https://containers.github.io/bootc/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-supported-green.svg)](https://www.home-assistant.io/)
[![Fedora](https://img.shields.io/badge/Fedora-42+-blue.svg)](https://fedoraproject.org/)

Complete solution for deploying and managing a Home Assistant server using bootc (Image Mode). This project provides an immutable operating system with a pre-configured Home Assistant container, automated dependency management, security hardening, and comprehensive management tools.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/home-assistant-bootc.git
cd home-assistant-bootc

# Configure your settings
cp config-example.toml config.toml
# Edit config.toml with your SSH key and preferences

# Build the image
sudo make build

# Deploy as VM
sudo make qcow2
sudo make deploy-vm

# Or create ISO for hardware installation
sudo make iso

# Cross-platform builds
make show-arch          # Show architecture info
make build-x86          # Build x86_64 container
make build-arm64        # Build ARM64 container

# After deployment/installation, run first-time setup
sudo /opt/hass-scripts/setup-hass.sh
```

## Features

### Core Features
- **Immutable OS**: Uses bootc for secure and consistent updates
- **Containerized Home Assistant**: Automatically started via systemd
- **Integrated Management Scripts**: Pre-installed backup, restore, health-check, and update tools
- **Automated Maintenance**: Scheduled backups and system updates via systemd timers
- **VPN Connection**: Integrated ZeroTier for remote access
- **UPS Support**: Network UPS Tools for UPS power management
- **Firewall**: Pre-configured for Home Assistant (port 8123)
- **Persistent Storage**: Automatic binding of configuration directories

### Advanced Features
- **Cross-Platform Support**: ARM64 (Apple Silicon) + x86_64 (Intel/AMD)
- **Dependency Management**: Automated version tracking and compatibility checking
- **Security Enhancements**: Automated vulnerability scanning and dependency auditing
- **Build Optimizations**: Registry caching and resource management
- **Security Monitoring**: Comprehensive security scanning with Trivy and Grype

## Requirements

### Hardware
- **Minimum**: 2 GB RAM, 20 GB storage, 1 CPU core
- **Recommended**: 4 GB RAM, 50 GB storage, 2 CPU cores
- **USB/Zigbee devices**: Automatic access support to /dev/ttyACM0, /dev/ttyUSB0

### Software
- **RHEL 9/Fedora 42+** or other compatible distribution
- **Podman** installed:
  ```bash
  dnf -y install podman
  ```
- **Registry authentication** (for RHEL):
  ```bash
  podman login registry.redhat.io
  sudo podman login registry.redhat.io
  ```

### Distribution Information
This project uses **Fedora 42** as the base operating system:
- **Base image**: `quay.io/fedora/fedora-bootc:42`
- **Build tool**: `quay.io/centos-bootc/bootc-image-builder:latest`

## Preparation and Build

### 1. Clone Repository
```bash
git clone <repository-url>
cd HASS_image_mode/image-mode-hass
```

### 2. Configuration
Copy and modify the configuration file:
```bash
cp config-example.toml config.toml
```

**Important config.toml modifications:**
- Change the `ansible` user password (or `hass-admin` for production)
- Add your SSH public key
- Adjust filesystem sizes as needed
- Set timezone and locale preferences

### 3. Build Configuration (Optional)
Use the flexible Makefile configuration system:
```bash
# Use defaults
make build

# Create custom configuration
cp config.mk my-config.mk
# Edit my-config.mk with your settings

# Use custom configuration
make build CONFIG_MK=my-config.mk
```

**Filesystem types available:**
- **ext4** (default): Most stable and compatible, recommended for most users
- **xfs**: RHEL/CentOS default, excellent performance for large files
- **btrfs**: Modern filesystem with snapshots support, good for advanced users

### 4. Build bootc image
```bash
# Using Make (recommended)
sudo make build

# Direct podman build
sudo podman build -t quay.io/rh-ee-jkryhut/fedora-bootc-hass .
```

## Publishing to Registry (Optional)

### 1. Login to Registry
```bash
# For Quay.io
podman login quay.io

# For Docker Hub
podman login docker.io

# For GitHub Container Registry
podman login ghcr.io
```

### 2. Push Image
```bash
# Build and push
sudo make push

# Or push manually
sudo podman push quay.io/rh-ee-jkryhut/fedora-bootc-hass:latest
```

## Deployment

### VM Deployment (Recommended)
```bash
# Build qcow2 image
sudo make qcow2

# Deploy VM
sudo make deploy-vm

# Check VM status
sudo virsh list --all
```

### ISO Installation
```bash
# Build ISO installer
sudo make iso

# The ISO will be created in output/iso/
# Burn to USB or mount in VM for installation
```

### Bare Metal Installation
```bash
# Build raw disk image
sudo make raw

# Write to USB/SSD
sudo dd if=output/raw/disk.raw of=/dev/sdX bs=1M status=progress
```

## System Management and Updates

### Available Management Scripts
After installation, the following scripts are available at `/opt/hass-scripts/`:

- `setup-hass.sh` - First-time setup and configuration
- `backup-hass.sh` - Create system backups
- `restore-hass.sh` - Restore from backup
- `update-system.sh` - Update system packages
- `health-check.sh` - Check system health
- `deps-update.sh` - Update dependencies
- `deps-check.sh` - Check dependency versions

### Automated Maintenance
The system includes automated maintenance via systemd timers:
- **Backup timer**: Daily backups at 2 AM
- **Update timer**: Weekly system updates
- **Health check timer**: Daily health monitoring

### Manual Updates
```bash
# Update system packages
sudo /opt/hass-scripts/update-system.sh

# Update dependencies
sudo /opt/hass-scripts/deps-update.sh

# Create backup
sudo /opt/hass-scripts/backup-hass.sh

# Check system health
sudo /opt/hass-scripts/health-check.sh
```

## Home Assistant Configuration

### Access Home Assistant
- **Web Interface**: http://your-server-ip:8123
- **SSH Access**: ssh ansible@your-server-ip (or hass-admin for production)

### Configuration Directory
Home Assistant configuration is stored in `/var/lib/hass/` and automatically persisted across reboots.

### Adding Integrations
1. Access Home Assistant web interface
2. Go to Settings → Devices & Services
3. Click "Add Integration"
4. Follow the setup wizard

### USB Device Access
USB devices (Zigbee sticks, etc.) are automatically accessible to Home Assistant:
- `/dev/ttyACM0` - Common for Zigbee sticks
- `/dev/ttyUSB0` - Alternative USB serial devices

## Troubleshooting

### Common Issues

**Build fails with permission errors:**
```bash
# Ensure podman is in rootful mode
sudo systemctl enable --now podman.socket
```

**VM deployment fails:**
```bash
# Check libvirt status
sudo systemctl status libvirtd

# Ensure user is in libvirt group
sudo usermod -a -G libvirt $USER
```

**Home Assistant not accessible:**
```bash
# Check service status
sudo systemctl status home-assistant

# Check firewall
sudo firewall-cmd --list-all

# Check logs
sudo journalctl -u home-assistant -f
```

### Logs and Debugging
```bash
# Home Assistant logs
sudo journalctl -u home-assistant -f

# System logs
sudo journalctl -f

# Container logs
sudo podman logs home-assistant
```

## Backup and Recovery

### Creating Backups
```bash
# Manual backup
sudo /opt/hass-scripts/backup-hass.sh

# Backup includes:
# - Home Assistant configuration
# - System configuration
# - User data
# - Database
```

### Restoring from Backup
```bash
# Restore from backup
sudo /opt/hass-scripts/restore-hass.sh /path/to/backup.tar.gz
```

### Backup Location
Backups are stored in `/var/backups/hass/` by default.

## Security Recommendations

### Network Security
- Change default passwords
- Use SSH keys instead of passwords
- Configure firewall rules
- Enable fail2ban protection

### System Security
- Keep system updated
- Use strong passwords
- Monitor system logs
- Regular security scans

### Security Scanning
The project includes automated security scanning:
- **Trivy**: Container vulnerability scanning
- **Grype**: Package vulnerability scanning
- **GitHub Actions**: Automated security monitoring
- **Local Testing**: Use `./scripts/test-security-scan.sh` for local testing

For troubleshooting security scan issues, see [Security Scan Fixes](docs/security-scan-fixes.md).

### Code Quality
The project maintains high code quality standards:
- **ShellCheck**: Static analysis for shell scripts
- **Automated Linting**: GitHub Actions static code analysis
- **Best Practices**: Consistent shell scripting patterns
- **Documentation**: Comprehensive code documentation

For details on static analysis fixes, see [Static Code Analysis Fixes](docs/static-code-analysis-fixes.md).

### Home Assistant Security
- Use strong passwords for Home Assistant
- Enable 2FA for admin accounts
- Use HTTPS with valid certificates
- Regular backups

## References and Resources

### Documentation
- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [bootc Documentation](https://containers.github.io/bootc/)
- [Fedora Documentation](https://docs.fedoraproject.org/)

### Community
- [Home Assistant Community](https://community.home-assistant.io/)
- [Fedora Community](https://fedoraproject.org/wiki/Communicate)

### Support
- [GitHub Issues](https://github.com/YOUR_USERNAME/home-assistant-bootc/issues)
- [Discussions](https://github.com/YOUR_USERNAME/home-assistant-bootc/discussions)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.