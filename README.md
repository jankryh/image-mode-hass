# Home Assistant bootc Image

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![bootc](https://img.shields.io/badge/bootc-compatible-blue.svg)](https://containers.github.io/bootc/)
[![Home Assistant](https://img.shields.io/badge/Home%20Assistant-supported-green.svg)](https://www.home-assistant.io/)
[![Fedora](https://img.shields.io/badge/Fedora-42+-blue.svg)](https://fedoraproject.org/)

Complete solution for deploying and managing a Home Assistant server using bootc (Image Mode). This project provides an immutable operating system with a pre-configured Home Assistant container, automated backups, security hardening, and comprehensive management tools.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/home-assistant-bootc.git
cd home-assistant-bootc

# Configure your settings
cp config-example.json config.toml
# Edit config.toml with your SSH key and preferences

# Build the image
sudo make build

# Deploy as VM
sudo make qcow2
sudo make deploy-vm

# Or create ISO for hardware installation
sudo make iso
```

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Preparation and Build](#-preparation-and-build)
- [Deployment](#-deployment)
- [System Management and Updates](#-system-management-and-updates)
- [Home Assistant Configuration](#%EF%B8%8F-home-assistant-configuration)
- [Troubleshooting](#-troubleshooting)
- [Backup and Recovery](#-backup-and-recovery)
- [Security Recommendations](#-security-recommendations)
- [References and Resources](#-references-and-resources)

## 🎯 Features

- **Immutable OS**: Uses bootc for secure and consistent updates
- **Containerized Home Assistant**: Automatically started via systemd
- **VPN Connection**: Integrated ZeroTier for remote access
- **UPS Support**: Network UPS Tools for UPS power management
- **Firewall**: Pre-configured for Home Assistant (port 8123)
- **Persistent Storage**: Automatic binding of configuration directories

## 📋 Requirements

### Hardware
- **Minimum**: 2 GB RAM, 20 GB storage, 1 CPU core
- **Recommended**: 4 GB RAM, 50 GB storage, 2 CPU cores
- **USB/Zigbee devices**: Automatic access support to /dev/ttyACM0

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

## 🔨 Preparation and Build

### 1. Clone Repository
```bash
git clone <repository-url>
cd HASS_image_mode/image-mode-hass
```

### 2. Configuration
Copy and modify the configuration file:
```bash
cp config-example.json config.toml
```

**Important config.toml modifications:**
- Change the `ansible` user password
- Add your SSH public key
- Adjust filesystem sizes as needed

### 3. Build bootc image
```bash
# Build image (run as root)
sudo podman build -t quay.io/rh-ee-jkryhut/fedora-bootc-hass .

# Or with your own registry
sudo podman build -t <your-registry>/fedora-bootc-hass .
```

## 🚀 Deployment

### Option A: Virtual Machine (Libvirt/KVM)

#### 1. Export qcow2 format:
```bash
# Pull required images
podman pull quay.io/fedora/fedora-bootc:latest
podman pull quay.io/centos-bootc/bootc-image-builder:latest

# Create qcow2 disk image
sudo podman run \
    --rm -it --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v ./config.toml:/config.toml \
    -v .:/output \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type qcow2 \
    --config /config.toml \
    quay.io/jwerak/fedora-bootc-hass
```

#### 2. Create and start VM:
```bash
# Move disk image
sudo mv ./qcow2/disk.qcow2 /var/lib/libvirt/images/fedora-bootc-home-assistant.qcow2

# Create VM
sudo virt-install \
    --name fedora-bootc-home-assistant \
    --memory 4096 \
    --cpu host-model \
    --vcpus 2 \
    --import --disk /var/lib/libvirt/images/fedora-bootc-home-assistant.qcow2 \
    --network network=default \
    --graphics spice \
    --os-variant rhel10.0

# For headless server add:
# --noautoconsole --console pty,target_type=serial
```

### Option B: Physical Hardware (ISO)

#### 1. Create bootable ISO:
```bash
sudo podman run \
    --rm -it --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v ./config.toml:/config.toml \
    -v .:/output \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type iso \
    --config /config.toml \
    quay.io/jwerak/fedora-bootc-hass
```

#### 2. Hardware installation:
1. Burn ISO to USB/DVD
2. Boot from media
3. Follow installation wizard
4. System will be automatically configured after installation

### Option C: Cloud Deployment
For AWS, Azure, GCP you can create a raw disk image:
```bash
sudo podman run \
    --rm -it --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v ./config.toml:/config.toml \
    -v .:/output \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type raw \
    --config /config.toml \
    quay.io/jwerak/fedora-bootc-hass
```

## 🔄 System Management and Updates

### OS Updates
bootc enables atomic updates with rollback capability:

#### Option 1: Local build and update
```bash
# Build new image locally
sudo podman build --no-cache -t quay.io/jwerak/fedora-bootc-hass .

# Switch to local image as update source
sudo bootc switch --transport containers-storage quay.io/jwerak/fedora-bootc-hass

# Check status
sudo bootc status

# Perform update
sudo bootc upgrade

# Restart to activate new version
sudo reboot
```

#### Option 2: Update from registry
```bash
# If you have image in registry
sudo bootc upgrade
sudo reboot
```

#### Rollback when problems occur
```bash
# Show available versions
sudo bootc status

# Rollback to previous version
sudo bootc rollback
sudo reboot
```

### System status monitoring
```bash
# Check services
sudo systemctl status home-assistant
sudo systemctl status zerotier-one

# Home Assistant logs
sudo podman logs home-assistant

# Check firewall
sudo firewall-cmd --list-all
```

## ⚙️ Home Assistant Configuration

### Basic setup
After first startup, Home Assistant will be available at:
- **Locally**: http://localhost:8123
- **In VM**: http://VM_IP:8123

### Adding custom components
Example custom component installation:
```bash
REPO_NAME=volkswagen_we_connect_id
REPO_URL=https://github.com/mitch-dc/volkswagen_we_connect_id.git

# Create directory for custom components
sudo mkdir -p /var/home-assistant/config/custom_components/${REPO_NAME}
cd /var/home-assistant/config/custom_components/${REPO_NAME}

# Clone only needed part using sparse checkout
sudo git init
sudo git remote add -f origin ${REPO_URL}
sudo git config core.sparseCheckout true
echo "custom_components/${REPO_NAME}/" | sudo tee .git/info/sparse-checkout
sudo git pull origin main

# Restart Home Assistant to load new component
sudo systemctl restart home-assistant
```

### ZeroTier VPN configuration
```bash
# Join ZeroTier network
sudo zerotier-cli join YOUR_NETWORK_ID

# Verify connection
sudo zerotier-cli listnetworks

# Authorization in ZeroTier Central dashboard is required
```

### UPS configuration (Network UPS Tools)
```bash
# Edit NUT configuration
sudo vi /etc/nut/nut.conf
sudo vi /etc/nut/ups.conf

# Restart NUT services
sudo systemctl restart nut-server
sudo systemctl restart nut-monitor
```

## 🔧 Troubleshooting

### Common problems and solutions

#### Home Assistant won't start
```bash
# Check container status
sudo systemctl status home-assistant

# Check logs
sudo podman logs home-assistant

# Restart service
sudo systemctl restart home-assistant

# Check device permissions
ls -la /dev/ttyACM*
```

#### Network problems
```bash
# Check firewall rules
sudo firewall-cmd --list-all

# Add ports if needed
sudo firewall-cmd --add-port=8123/tcp --permanent
sudo firewall-cmd --reload

# Check network connection
ss -tlnp | grep 8123
```

#### Bootc update fails
```bash
# Check disk space
df -h

# Clean old images
sudo podman system prune -af

# Reset bootc state
sudo bootc status
sudo ostree admin cleanup
```

#### ZeroTier won't connect
```bash
# Check service status
sudo systemctl status zerotier-one

# Restart ZeroTier
sudo systemctl restart zerotier-one

# Check network interface
ip addr show zt0
```

### Logs and diagnostics
```bash
# All systemd logs
sudo journalctl -f

# Specific services
sudo journalctl -u home-assistant -f
sudo journalctl -u zerotier-one -f

# Bootc logs
sudo journalctl -u bootc-fetch-apply-updates
```

## 💾 Backup and Recovery

### Configuration backup
```bash
# Backup Home Assistant configuration
sudo tar -czf hass-config-backup-$(date +%Y%m%d).tar.gz -C /var/home-assistant/config .

# Backup ZeroTier configuration
sudo cp -r /var/lib/zerotier-one /backup/zerotier-$(date +%Y%m%d)
```

### Automatic backups (cron)
```bash
# Add to root crontab
sudo crontab -e

# Example: daily backup at 2:00 AM
0 2 * * * tar -czf /backup/hass-config-$(date +\%Y\%m\%d).tar.gz -C /var/home-assistant/config .
```

## 🔐 Security Recommendations

### SSL/TLS configuration
- Use Let's Encrypt for SSL certificates
- Configure reverse proxy (nginx/caddy)
- Change default port if possible

### Network security
- Limit access to port 8123 using firewall
- Use ZeroTier for remote access instead of opening ports
- Regularly update the system

### Access credentials
- Change default passwords
- Use strong passwords
- Enable two-factor authentication in Home Assistant

## 📚 References and Resources

### Official Documentation
- [bootc Project](https://containers.github.io/bootc/)
- [Home Assistant Documentation](https://www.home-assistant.io/docs/)
- [Red Hat Image Mode](https://developers.redhat.com/products/rhel-image-mode/overview)

### Useful Links
- [Getting Started with Image Mode](https://www.redhat.com/en/blog/image-mode-red-hat-enterprise-linux-quick-start-guide)
- [Building and Deploying Image Mode RHEL](https://developers.redhat.com/articles/2025/03/12/how-build-deploy-and-manage-image-mode-rhel#image_mode_for_rhel)
- [Fedora bootc Getting Started](https://docs.fedoraproject.org/en-US/bootc/getting-started/)
- [ZeroTier Documentation](https://docs.zerotier.com/)
- [Network UPS Tools](https://networkupstools.org/docs/)