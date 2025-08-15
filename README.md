# Home Assistant bootc Image

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![bootc](https://img.shields.io/badge/bootc-compatible-blue.svg)](https://containers.github.io/bootc/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-supported-green.svg)](https://www.home-assistant.io/)

Solution for deploying Home Assistant using bootc (Image Mode). This project provides an immutable operating system with a pre-configured Home Assistant container and essential management tools.

## 🚀 Quick Start

### Option 1: bootc Image Mode (Recommended for VM/Hardware)
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/home-assistant-bootc.git
cd home-assistant-bootc

# Run setup script
./setup.sh

# Build the image
sudo make build

# Deploy as VM
sudo make qcow2
sudo make deploy-vm

# Or create ISO for hardware installation
sudo make iso
```

### Option 2: Container Mode (Recommended for Development/Testing)
```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/home-assistant-bootc.git
cd home-assistant-bootc

# Setup and deploy container
./podman-deploy.sh setup

# Or manual steps
./podman-deploy.sh build
./podman-deploy.sh start
```

## 📋 Project Structure and Scripts

This project provides multiple deployment options through different scripts:

### 🔧 **setup.sh** - Initial Setup Script
**Purpose**: Prepares environment for bootc image building
```bash
./setup.sh
```
**Functions:**
- ✅ Checks system requirements (podman, make, sudo)
- ✅ Creates `config.mk` from template
- ✅ Sets up basic configuration for bootc build
- ✅ Configures variables for Makefile

### 🔨 **Makefile** - Build System
**Purpose**: Builds bootc image and VM deployment
```bash
make build      # Build container image
make qcow2      # Create VM image
make deploy-vm  # Deploy VM
make iso        # Create ISO installer
```
**Functions:**
- ✅ Builds container image using Containerfile
- ✅ Creates qcow2/ISO using bootc-image-builder
- ✅ Deploys VM using libvirt
- ✅ Pushes to registry

### 🐳 **podman-deploy.sh** - Container Runtime Management
**Purpose**: Manages running container with systemd integration
```bash
./podman-deploy.sh build    # Build image
./podman-deploy.sh start    # Start service
./podman-deploy.sh status   # Check service status
./podman-deploy.sh backup   # Create backup
```
**Functions:**
- ✅ Builds image for runtime
- ✅ Manages systemd service
- ✅ Handles backups and restore
- ✅ Provides health checks and monitoring

### 📊 **Script Relationship Diagram**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│  setup.sh   │───▶│  Makefile   │───▶│ bootc image │
│             │    │             │    │             │
│ • Init env  │    │ • Build     │    │ • VM/ISO    │
│ • Config    │    │ • Deploy    │    │ • Hardware  │
└─────────────┘    └─────────────┘    └─────────────┘
                           │
                           ▼
                   ┌─────────────┐
                   │podman-deploy│
                   │    .sh      │
                   │             │
                   │ • Runtime   │
                   │ • Service   │
                   │ • Container │
                   └─────────────┘
```

## 🎯 Deployment Modes

### Mode 1: bootc Image Mode (Production)
**Best for**: Production deployments, hardware installation, VMs
```bash
# Complete workflow
./setup.sh
make build
make qcow2
make deploy-vm
```
**Advantages:**
- ✅ Immutable OS with atomic updates
- ✅ Full system control
- ✅ Hardware optimization
- ✅ Production-ready security

### Mode 2: Container Mode (Development/Testing)
**Best for**: Development, testing, quick deployment
```bash
# Complete workflow
./podman-deploy.sh setup
./podman-deploy.sh start
```
**Advantages:**
- ✅ Quick deployment
- ✅ Easy updates
- ✅ Development-friendly
- ✅ Systemd integration

## Features

### Core Features
- **Immutable OS**: Uses bootc for secure and consistent updates
- **Containerized Home Assistant**: Automatically started via systemd
- **Basic Management Scripts**: Backup, restore, and health-check tools
- **VPN Connection**: Integrated ZeroTier for remote access
- **UPS Support**: Network UPS Tools for UPS power management
- **Firewall**: Pre-configured for Home Assistant (port 8123)
- **Persistent Storage**: Automatic binding of configuration directories

### Management Features
- **Basic Dependency Management**: Simple dependency tracking
- **Essential Performance Testing**: Core system metrics
- **Streamlined Security**: Basic vulnerability scanning
- **Minimal Configuration**: Easy-to-understand settings

## Requirements

### Hardware
- **Minimum**: 2 GB RAM, 20 GB storage, 1 CPU core
- **Recommended**: 4 GB RAM, 50 GB storage, 2 CPU cores

### Software
- **RHEL 9/Fedora 42+** or other compatible distribution
- **Podman** installed:
  ```bash
  dnf -y install podman
  ```

## Configuration

### Basic Configuration
Copy the configuration:
```bash
cp config-example.mk config.mk
```

Edit `config.mk` with your settings:
```makefile
# Basic settings
REGISTRY = quay.io/yourusername
IMAGE_NAME = fedora-bootc-hass
IMAGE_TAG = latest

# VM settings
VM_MEMORY = 4096
VM_VCPUS = 2
```

## Building and Deployment

### Build Container Image
```bash
# Build image
sudo make build

# Build with custom config
sudo make build CONFIG_MK=my-config.mk
```

### Create VM Image
```bash
# Create qcow2 image
sudo make qcow2

# Deploy VM
sudo make deploy-vm
```

### Create ISO Installer
```bash
# Create ISO
sudo make iso

# ISO will be created in output/iso/
```

## System Management

### Available Scripts
After installation, these scripts are available at `/opt/hass-scripts/`:

- `setup-hass.sh` - First-time setup
- `backup-hass.sh` - Create system backups
- `restore-hass.sh` - Restore from backup
- `health-check.sh` - Check system health
- `update-system.sh` - Update system packages

### Basic Usage
```bash
# First-time setup
sudo /opt/hass-scripts/setup-hass.sh

# Create backup
sudo /opt/hass-scripts/backup-hass.sh

# Check system health
sudo /opt/hass-scripts/health-check.sh

# Update system
sudo /opt/hass-scripts/update-system.sh
```

## Home Assistant Configuration

### Access Home Assistant
- **Web Interface**: http://your-server-ip:8123
- **SSH Access**: ssh ansible@your-server-ip

### Configuration Directory
Home Assistant configuration is stored in `/var/lib/hass/` and automatically persisted.

### USB Device Access
USB devices are automatically accessible:
- `/dev/ttyACM0` - Common for Zigbee sticks
- `/dev/ttyUSB0` - Alternative USB serial devices

## Security

### Basic Security Configuration

#### SSH Configuration
Recommended configuration in `/etc/ssh/sshd_config`:
```bash
# Disable root login
PermitRootLogin no

# Use key-based authentication only
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey

# Restrict users
AllowUsers hass-admin
```

#### Firewall Configuration
```bash
# Basic setup
sudo firewall-cmd --set-default-zone=public

# Allowed services
sudo firewall-cmd --add-service=ssh --permanent
sudo firewall-cmd --add-port=8123/tcp --permanent

# Apply changes
sudo firewall-cmd --reload
```

#### Fail2ban Configuration
Basic fail2ban configuration is included. For enhanced security:
```bash
# Install fail2ban
sudo dnf install fail2ban

# Enable and start
sudo systemctl enable --now fail2ban
```

### Rootless Podman (Optional)
For enhanced security, you can use rootless Podman:

```bash
# Check if supported
podman --version
sysctl user.max_user_namespaces

# Configure user namespaces
sudo sysctl -w user.max_user_namespaces=28633
echo "user.max_user_namespaces=28633" | sudo tee /etc/sysctl.d/99-userns.conf

# Build with rootless Podman
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
podman build -t localhost/fedora-bootc-hass:latest .
```

## Troubleshooting

### Common Issues

**Build fails:**
```bash
# Check podman status
sudo systemctl status podman.socket

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

# Check logs
sudo journalctl -u home-assistant -f
```

### Logs and Debugging
```bash
# Home Assistant logs
sudo journalctl -u home-assistant -f

# System logs
sudo journalctl -f
```

## Backup and Recovery

### Creating Backups
```bash
# Manual backup
sudo /opt/hass-scripts/backup-hass.sh
```

### Restoring from Backup
```bash
# Restore from backup
sudo /opt/hass-scripts/restore-hass.sh /path/to/backup.tar.gz
```

## Advanced Features

The project includes several advanced features:
- Dependency management
- Performance testing
- Security scanning
- Cross-platform builds
- Advanced configuration options

For more information, see the individual script documentation in the `scripts/` directory.

## Changelog

### Version 2.1.0 (Current)
- Added Podman container deployment mode
- Enhanced security with non-root user
- Improved systemd integration
- Added comprehensive health checks
- Better documentation and script organization

### Version 2.0.0
- Simplified configuration system
- Streamlined build process
- Enhanced security features
- Improved documentation
- Better user experience

### Version 1.0.0
- Initial release
- Basic Home Assistant container setup
- Firewall configuration
- SSH access setup

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
