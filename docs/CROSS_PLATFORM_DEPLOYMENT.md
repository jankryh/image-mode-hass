# Cross-Platform Deployment Guide

## 🎯 Overview

This project now supports **full cross-platform deployment** for both **ARM64** and **x86_64** architectures, including automated GitHub Actions CI/CD.

## 🏗️ Architecture Support

### **Native Builds** ✅
- **ARM64 (Apple Silicon/M1/M2)**: All formats supported
- **x86_64 (Intel/AMD)**: All formats supported  

### **Cross-Platform Builds** ⚠️
- **Container Images**: Full cross-platform support ✅
- **Disk Images**: Limited by bootc-image-builder constraints

## 🛠️ Local Development

### **Quick Commands**

```bash
# Show current architecture info
make show-arch

# Build for current architecture (auto-detect)
make build
make iso
make qcow2
make raw

# Build specific architecture containers
make build-x86      # x86_64 container image
make build-arm64    # ARM64 container image

# Build specific architecture disk images
make iso-x86        # x86_64 ISO installer  
make iso-arm64      # ARM64 ISO installer
make qcow2-x86      # x86_64 qcow2 for VMs
make qcow2-arm64    # ARM64 qcow2 for VMs
make raw-x86        # x86_64 raw disk for bare metal
make raw-arm64      # ARM64 raw disk for bare metal
```

### **Configuration Variables**

```bash
# config.mk settings
TARGET_ARCH=auto     # auto, arm64, amd64
PLATFORM_SUFFIX      # Automatically set based on target
```

## 🚀 GitHub Actions CI/CD

### **Automated Builds**

Every push to `main`/`develop` automatically builds:

1. **Container Images**:
   - ARM64: `fedora-bootc-hass:latest`
   - x86_64: `fedora-bootc-hass-x86:latest`

2. **Disk Images** (where supported):
   - ARM64: ISO, qcow2, raw
   - x86_64: ISO, qcow2, raw (via BuildJet runners)

### **Artifacts Download**

GitHub releases include:
- `arm64-iso-image` - ARM64 ISO installer
- `arm64-qcow2-image` - ARM64 VM image  
- `x86-iso-image` - x86_64 ISO installer
- `x86-qcow2-image` - x86_64 VM image
- `x86-raw-image` - x86_64 bare metal image

## 📦 Deployment Options

### **1. Bare Metal Deployment**

#### **x86_64 Servers/PCs:**
```bash
# Option A: Use CI-built artifacts (recommended)
curl -L -o install.iso https://github.com/your-repo/releases/latest/download/x86-iso-image.zip
unzip x86-iso-image.zip

# Option B: Build locally on x86_64 machine
make raw-x86
sudo dd if=output/image/disk.raw of=/dev/sdX bs=1M status=progress
```

#### **ARM64 Hardware (Raspberry Pi, etc.):**
```bash
# Use ARM64 ISO (already available)
make iso    # or download from releases
```

### **2. Virtual Machines**

#### **QEMU/KVM:**
```bash
# x86_64 VMs
make qcow2-x86
qemu-system-x86_64 -hda output/qcow2/disk.qcow2 -m 4096 -smp 2

# ARM64 VMs  
make qcow2
qemu-system-aarch64 -hda output/qcow2/disk.qcow2 -m 4096 -smp 2
```

#### **VirtualBox/VMware:**
```bash
# Convert qcow2 to VDI/VMDK
qemu-img convert -f qcow2 -O vdi disk.qcow2 disk.vdi
qemu-img convert -f qcow2 -O vmdk disk.qcow2 disk.vmdk
```

### **3. Container Runtime**

```bash
# Native architecture
podman run -d --name hass quay.io/your-registry/fedora-bootc-hass:latest

# Specific architecture
podman run -d --name hass-x86 quay.io/your-registry/fedora-bootc-hass-x86:latest
```

## 🔧 Technical Details

### **BuildJet Runners**

GitHub Actions uses BuildJet's high-performance runners for x86_64 builds:
- `buildjet-8vcpu-ubuntu-2204` for faster builds
- Native x86_64 execution (no emulation)
- Support for rootful podman and bootc-image-builder

### **Cross-Platform Limitations**

**bootc-image-builder** currently has experimental cross-arch support:
- ✅ **Same-arch builds**: ARM64→ARM64, x86_64→x86_64  
- ⚠️ **Cross-arch builds**: ARM64→x86_64 (limited/experimental)

### **Workarounds**

1. **GitHub Actions**: Use native runners for each architecture
2. **Local Development**: Build on target architecture when possible
3. **Container Images**: Full cross-platform support via `--platform` flag

## 🆘 Troubleshooting

### **Common Issues**

**ISO not bootable:**
- Check architecture match: ARM64 ISO won't boot on x86_64 hardware
- Use `file output/bootiso/install.iso` to verify architecture

**Cross-platform build fails:**
```bash
error: cannot build iso for different target arches yet
```
- **Solution**: Use GitHub Actions or build on target architecture

**TOML configuration errors:**
```bash
toml: line 33: type mismatch for customizations.locale
```
- **Solution**: Use table format instead of string format (already fixed)

### **Getting Help**

1. Check GitHub Actions logs for CI builds
2. Run `make show-arch` to verify configuration
3. Use `make help` to see all available targets
4. Check this documentation for deployment patterns

## 📊 Performance Comparison

| Method | Build Time | Resource Usage | Reliability |
|--------|------------|----------------|-------------|
| Native builds | Fast | Low | ✅ Excellent |
| Cross-platform | Slow | High | ⚠️ Limited |
| GitHub Actions | Medium | None (cloud) | ✅ Excellent |

**Recommendation**: Use GitHub Actions for production builds, native builds for development.