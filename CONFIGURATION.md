# Configuration Guide for Home Assistant bootc

This document explains how to configure the build and deployment process using the flexible configuration system.

## Configuration Files

### Default Configuration
The default configuration is defined in `config.mk` and includes sensible defaults for most use cases.

### Custom Configuration
You can create custom configuration files to override defaults for different environments.

## Quick Start

### Using Default Configuration
```bash
# Build with default settings
make build

# Show current configuration
make config-show
```

### Creating Custom Configuration
```bash
# Copy and customize
cp config.mk my-config.mk
# Edit my-config.mk with your settings

# Use example
cp config-custom.mk.example my-config.mk
# Edit my-config.mk
```

### Using Custom Configuration
```bash
# Build with custom config
make build CONFIG_MK=my-config.mk

# Deploy VM with custom config
make deploy-vm CONFIG_MK=my-config.mk

# Show configuration values
make config-show CONFIG_MK=my-config.mk
```

## Configuration Variables

### Container Image Settings
```makefile
IMAGE_NAME = fedora-bootc-hass          # Container image name
REGISTRY = quay.io/rh-ee-jkryhut        # Container registry
IMAGE_TAG = latest                      # Image tag/version
```

### Build Settings
```makefile
CONFIG_FILE = config-production.toml    # bootc configuration file
OUTPUT_DIR = ./output                   # Output directory for images
CONTAINER_RUNTIME = podman              # Container runtime (podman/docker)
USE_BUILDAH = false                     # Use buildah instead of podman
USE_CACHE = true                        # Enable build cache
VERBOSE = false                         # Enable verbose output
ROOTFS_TYPE = ext4                      # Root filesystem type (ext4/xfs/btrfs)
```

### Virtual Machine Settings
```makefile
VM_NAME = home-assistant-bootc          # VM name
VM_MEMORY = 4096                        # Memory in MB
VM_VCPUS = 2                           # Number of CPU cores
VM_NETWORK = default                    # Network configuration
VM_GRAPHICS = spice                     # Graphics type (spice/vnc/none)
VM_OS_VARIANT = rhel9.0                # OS variant for virt-install
```

## Configuration Examples

### Docker Hub Deployment
```makefile
# config-dockerhub.mk
REGISTRY = docker.io/myusername
IMAGE_NAME = home-assistant-bootc
CONFIG_FILE = config-production.toml
```

### GitHub Container Registry
```makefile
# config-ghcr.mk
REGISTRY = ghcr.io/myusername
IMAGE_NAME = home-assistant-bootc
CONFIG_FILE = config-production.toml
```

### Production Configuration
```makefile
# config-production.mk
REGISTRY = quay.io/myorg
IMAGE_NAME = home-assistant-bootc
IMAGE_TAG = v1.0.0
CONFIG_FILE = config-production.toml
VM_MEMORY = 8192
VM_VCPUS = 4
USE_CACHE = true
VERBOSE = false
```

### Development Configuration
```makefile
# config-dev.mk
REGISTRY = localhost:5000
IMAGE_NAME = home-assistant-bootc
IMAGE_TAG = dev
CONFIG_FILE = config-example.toml
VM_MEMORY = 2048
VM_VCPUS = 1
USE_CACHE = false
VERBOSE = true
```

## Filesystem Types

### ext4 (Default)
- **Pros**: Most stable, widely supported, good performance
- **Cons**: No snapshots, limited advanced features
- **Use case**: General purpose, maximum compatibility

### xfs
- **Pros**: Excellent performance for large files, RHEL/CentOS default
- **Cons**: No snapshots, limited shrinking capability
- **Use case**: High-performance systems, large storage

### btrfs
- **Pros**: Snapshots, compression, advanced features
- **Cons**: Less mature, potential stability issues
- **Use case**: Advanced users, snapshot requirements

## Architecture Support

### Auto-detection
The system automatically detects your architecture and sets appropriate defaults:
- **ARM64**: Apple Silicon, ARM servers
- **x86_64**: Intel/AMD processors

### Manual Configuration
```makefile
# Force specific architecture
TARGET_ARCH = arm64
TARGET_ARCH = amd64
```

## Registry Configuration

### Supported Registries
- **Quay.io**: `quay.io/username`
- **Docker Hub**: `docker.io/username`
- **GitHub Container Registry**: `ghcr.io/username`
- **Private registries**: `your-registry.com/namespace`

### Authentication
```bash
# Login to registry
podman login quay.io
podman login docker.io
podman login ghcr.io
```

## VM Configuration

### Memory and CPU
```makefile
# Small VM (development)
VM_MEMORY = 2048
VM_VCPUS = 1

# Medium VM (home use)
VM_MEMORY = 4096
VM_VCPUS = 2

# Large VM (production)
VM_MEMORY = 8192
VM_VCPUS = 4
```

### Network Configuration
```makefile
# Default network
VM_NETWORK = default

# Bridge network
VM_NETWORK = br0

# Host network
VM_NETWORK = host
```

### Graphics Options
```makefile
# SPICE (recommended)
VM_GRAPHICS = spice

# VNC
VM_GRAPHICS = vnc

# No graphics (headless)
VM_GRAPHICS = none
```

## Build Options

### Cache Control
```makefile
# Enable cache (faster builds)
USE_CACHE = true

# Disable cache (clean builds)
USE_CACHE = false
```

### Verbose Output
```makefile
# Normal output
VERBOSE = false

# Detailed output
VERBOSE = true
```

### Build Arguments
```makefile
# Add custom build arguments
BUILD_ARGS += --build-arg CUSTOM_VAR=value
BUILD_ARGS += --build-arg ANOTHER_VAR=value
```

## Environment-specific Configurations

### Development Environment
```makefile
# config-dev.mk
IMAGE_TAG = dev
CONFIG_FILE = config-example.toml
VM_MEMORY = 2048
VM_VCPUS = 1
USE_CACHE = false
VERBOSE = true
```

### Testing Environment
```makefile
# config-test.mk
IMAGE_TAG = test
CONFIG_FILE = config-test.toml
VM_MEMORY = 4096
VM_VCPUS = 2
USE_CACHE = true
VERBOSE = false
```

### Production Environment
```makefile
# config-prod.mk
IMAGE_TAG = v1.0.0
CONFIG_FILE = config-production.toml
VM_MEMORY = 8192
VM_VCPUS = 4
USE_CACHE = true
VERBOSE = false
```

## Best Practices

### Configuration Management
1. **Use descriptive names**: `config-production.mk`, `config-dev.mk`
2. **Version control**: Include configuration files in version control
3. **Documentation**: Add comments explaining custom settings
4. **Testing**: Test configurations before production use

### Security Considerations
1. **Registry credentials**: Use robot accounts for automated builds
2. **Network isolation**: Use separate networks for different environments
3. **Access control**: Limit VM access based on requirements

### Performance Optimization
1. **Cache usage**: Enable cache for faster builds
2. **Resource allocation**: Match VM resources to workload
3. **Filesystem selection**: Choose appropriate filesystem for use case

## Troubleshooting

### Common Issues

**Configuration not found:**
```bash
# Check if file exists
ls -la config.mk

# Use absolute path
make build CONFIG_MK=/full/path/to/config.mk
```

**Build fails with custom config:**
```bash
# Validate configuration
make config-show CONFIG_MK=my-config.mk

# Check for syntax errors
cat my-config.mk
```

**VM deployment issues:**
```bash
# Check VM settings
make config-show CONFIG_MK=my-config.mk | grep VM_

# Verify libvirt configuration
sudo systemctl status libvirtd
```

### Debugging Configuration
```bash
# Show all configuration values
make config-show CONFIG_MK=my-config.mk

# Show specific variable
make config-show CONFIG_MK=my-config.mk | grep IMAGE_NAME

# Test configuration
make build CONFIG_MK=my-config.mk VERBOSE=true
```