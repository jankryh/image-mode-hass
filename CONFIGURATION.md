# Configuration Guide for Home Assistant bootc

This document explains how to configure the build and deployment process using the flexible configuration system.

## 📋 Configuration Files

### Default Configuration
The default configuration is defined in `config.mk` and includes sensible defaults for most use cases.

### Custom Configuration
You can create custom configuration files to override defaults for different environments.

## 🚀 Quick Start

### Using Default Configuration
```bash
# Build with default settings
make build

# Show current configuration
make config-show
```

### Creating Custom Configuration
```bash
# Option 1: Create from template
make config-template

# Option 2: Copy and customize
cp config.mk my-config.mk
# Edit my-config.mk with your settings

# Option 3: Use example
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

## ⚙️ Configuration Variables

### Container Image Settings
```makefile
IMAGE_NAME = fedora-bootc-hass          # Container image name
REGISTRY = quay.io/rh-ee-jkryhut        # Container registry
IMAGE_TAG = latest                      # Image tag/version
```

### Build Settings
```makefile
CONFIG_FILE = config-production.json    # bootc configuration file
OUTPUT_DIR = ./output                   # Output directory for images
CONTAINER_RUNTIME = podman              # Container runtime (podman/docker)
USE_BUILDAH = false                     # Use buildah instead of podman
USE_CACHE = true                        # Enable build cache
VERBOSE = false                         # Enable verbose output
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

### Development Settings
```makefile
DEV_TAG = dev                          # Development image tag
DEV_CONFIG = config-example.json       # Development config file
DEV_VM_NAME = hass-dev                 # Development VM name
DEBUG = false                          # Enable debug mode
```

## 📝 Configuration Examples

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

### Registry Publishing
```makefile
# config-quay.mk
REGISTRY = quay.io/myorganization
IMAGE_NAME = home-assistant-bootc
IMAGE_TAG = v1.0.0
CONFIG_FILE = config-production.toml
```

### Local Development
```makefile
# config-local.mk
REGISTRY = localhost:5000
IMAGE_TAG = test
USE_CACHE = false
VERBOSE = true
DEBUG = true
```

### Production Environment
```makefile
# config-production.mk
CONFIG_FILE = config-production.json
VM_MEMORY = 8192
VM_VCPUS = 4
ENABLE_HEALTH_CHECK = true
USE_CACHE = true
```

## 🛠️ Available Make Targets

### Configuration Management
```bash
make config-show                       # Show current configuration
make config-create                     # Create custom config file
make config-template                   # Create template configurations
make info                             # Show detailed build information
```

### Build Targets
```bash
make build                            # Build container image
make push                             # Push image to registry
make qcow2                            # Build qcow2 VM image
make iso                              # Build ISO installer
make raw                              # Build raw disk image
make all                              # Build all formats
```

### Deployment Targets
```bash
make deploy-vm                        # Deploy VM using libvirt
make vm                               # Quick VM deployment
make clean-vm                         # Remove deployed VM
```

### Development Targets
```bash
make dev-build                        # Build with development settings
make dev-qcow2                        # Build development qcow2
make dev-deploy                       # Deploy development VM
```

## 🎯 Use Cases

### Scenario 1: Local Development
```bash
# Create development configuration
make config-template-development

# Build and deploy development environment
make dev-build CONFIG_MK=config-development.mk
make dev-deploy CONFIG_MK=config-development.mk
```

### Scenario 2: Multi-Registry Deployment
```bash
# Build for Docker Hub
make build CONFIG_MK=config-dockerhub.mk
make push CONFIG_MK=config-dockerhub.mk

# Build for GitHub Container Registry
make build CONFIG_MK=config-ghcr.mk
make push CONFIG_MK=config-ghcr.mk
```

### Scenario 3: Different VM Configurations
```bash
# Small VM for testing
echo "VM_MEMORY = 2048" > config-small.mk
echo "VM_VCPUS = 1" >> config-small.mk
make deploy-vm CONFIG_MK=config-small.mk

# Large VM for production
echo "VM_MEMORY = 8192" > config-large.mk
echo "VM_VCPUS = 4" >> config-large.mk
make deploy-vm CONFIG_MK=config-large.mk
```

### Scenario 4: Registry Publishing Workflow
```bash
# Create publishing configuration
echo "REGISTRY = quay.io/myorg" > config-publish.mk
echo "IMAGE_TAG = v1.0.0" >> config-publish.mk

# Build and publish
make build CONFIG_MK=config-publish.mk
sudo podman login quay.io
make push CONFIG_MK=config-publish.mk

# Verify in registry web interface
echo "Check https://quay.io/repository/myorg/fedora-bootc-hass"
```

## 🔧 Advanced Configuration

### Environment Variables
You can also override any configuration using environment variables:
```bash
# Override registry for one build
REGISTRY=my-registry.com make build

# Override multiple variables
VM_MEMORY=6144 VM_VCPUS=3 make deploy-vm
```

### Build Arguments
```makefile
# Add custom build arguments
BUILD_ARGS = --build-arg HTTP_PROXY=http://proxy:8080
```

### Runtime Arguments
```makefile
# Add custom runtime arguments
RUN_ARGS = --security-opt label=disable
```

## 📁 File Structure
```
├── config.mk                         # Default configuration
├── config-custom.mk.example          # Example custom configuration
├── config-*.mk                       # Custom configurations (gitignored)
├── Makefile                          # Build automation
└── CONFIGURATION.md                  # This documentation
```

## 🔍 Troubleshooting

### Configuration Not Found
```bash
# Check if configuration file exists
ls -la config*.mk

# Create from example
cp config-custom.mk.example my-config.mk
```

### Variable Not Working
```bash
# Show current configuration
make config-show CONFIG_MK=my-config.mk

# Validate syntax
make -n build CONFIG_MK=my-config.mk
```

### Build Issues
```bash
# Enable verbose output
echo "VERBOSE = true" >> my-config.mk
make build CONFIG_MK=my-config.mk

# Disable cache
echo "USE_CACHE = false" >> my-config.mk
make build CONFIG_MK=my-config.mk
```

## 💡 Tips and Best Practices

1. **Use descriptive configuration file names**: `config-production.mk`, `config-testing.mk`
2. **Keep sensitive data out of configuration files**: Use environment variables for passwords
3. **Document your custom configurations**: Add comments explaining your choices
4. **Test configurations**: Use `make config-show` to verify settings before building
5. **Version control**: Add custom configs to `.gitignore` to avoid committing sensitive data

This flexible configuration system allows you to easily manage multiple environments and deployment scenarios while keeping your builds consistent and reproducible.