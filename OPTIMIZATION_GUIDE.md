# Home Assistant bootc - Optimization Guide

This guide covers optimization features for performance, dependency management, and build efficiency.

## Performance Optimizations

### Build Performance

#### Optimized Containerfile
The main `Containerfile` includes:
- Multi-stage builds with caching
- Layer optimization and proper ordering
- Parallel processing capabilities
- Build cache management
- Resource optimization

```bash
# Use optimized build process
make build

# Parallel build with maximum performance
make build-parallel
```

#### Build Performance Features

| Feature | Description | Benefits |
|---------|-------------|----------|
| Multi-stage caching | Separate dependency resolution stage | 50-70% faster rebuilds |
| Layer optimization | Strategic layer ordering | Reduced image size |
| Parallel processing | Utilize all CPU cores | 2-4x faster builds |
| Resource limits | Memory and CPU constraints | Predictable performance |
| Build cache | Registry-based cache storage | Consistent build speed |

### Performance Testing

#### Benchmarking
```bash
# Run all performance tests
./scripts/performance-test.sh --all

# Specific tests
./scripts/performance-test.sh --cpu --memory --disk
./scripts/performance-test.sh --boot --container
./scripts/performance-test.sh --network

# Generate detailed report
./scripts/performance-test.sh --all --verbose
```

#### Performance Metrics
The testing suite measures:
- **Boot performance** - System startup time analysis
- **CPU performance** - Computation benchmarks  
- **Memory performance** - RAM usage and speed tests
- **Disk I/O** - Read/write performance testing
- **Network performance** - Connectivity and latency tests
- **Container performance** - Startup and runtime tests

## Dependency Management

### Automated Dependency Resolution

#### Ansible Integration
The system uses Ansible for automatic dependency discovery:

```dockerfile
# Stage 1: Dependency Discovery
FROM quay.io/fedora/fedora-bootc:42 as ansible-stage
RUN dnf -y install linux-system-roles
RUN /usr/share/ansible/collections/ansible_collections/fedora/linux_system_roles/roles/podman/.ostree/get_ostree_data.sh packages runtime fedora-42 raw >> /deps/bindep.txt

# Stage 2: Production Image  
FROM quay.io/fedora/fedora-bootc:42
RUN --mount=type=bind,from=ansible-stage,source=/deps/,target=/deps \
    grep -v '^#' /deps/bindep.txt | xargs dnf -y install
```

#### Dependency Sources

1. **Manual dependencies** (`bindep.txt`):
   ```bash
   # Home Assistant specific packages
   zerotier-one, openssh-server, nut
   htop, tree, rsync, tmux, jq
   fail2ban, chrony, vim-enhanced
   ```

2. **Auto-discovered dependencies** (via Ansible):
   ```bash
   # Podman runtime requirements for bootc
   containernetworking-plugins, containers-common
   container-selinux, fuse-overlayfs, slirp4netns
   ```

### Benefits

| Traditional Approach | Ansible Approach |
|---------------------|------------------|
| Manual dependency tracking | Automated dependency resolution |
| Version conflicts possible | Community-tested combinations |
| Outdated package lists | Always current for Fedora version |
| Bloated with unnecessary packages | Minimal, optimized package set |
| Breaks with Fedora updates | Adapts to new Fedora releases |

## Cache Management

### Build Cache Strategies

#### Local Cache
```bash
# Enable build cache (default)
USE_CACHE=true make build

# Disable cache for clean builds
USE_CACHE=false make build

# Clean local cache
make cache-clean
```

#### Registry Cache
```bash
# Pull latest image for layer caching
make cache-pull

# Push built image to registry (creates cache for others)
make cache-push
```

### Cache Configuration
```makefile
# Build cache settings
USE_CACHE = true
BUILD_CACHE = ./.buildcache
FORCE_REBUILD = false
```

## Resource Optimization

### Build Resources
```makefile
# Resource limits for builds
BUILD_MEMORY = 4g
BUILD_CPUS = $(shell nproc)
```

### VM Optimization
```makefile
# Optimized VM settings
VM_MEMORY = 4096
VM_VCPUS = 2
VM_CPU_MODEL = host-passthrough
VM_DISK_CACHE = writeback
```

## Usage Examples

### High-Performance Build Workflow
```bash
# 1. Pull cache for faster builds
make cache-pull

# 2. Build with optimizations
make build

# 3. Create optimized VM image
make qcow2

# 4. Deploy with performance tuning
make deploy-vm

# 5. Run performance tests
./scripts/performance-test.sh --all
```

### Development Workflow
```bash
# Development build with optimizations
make build CONFIG_MK=config-dev.mk

# Quick testing
make qcow2 CONFIG_MK=config-dev.mk

# Performance validation
./scripts/performance-test.sh --quick
```

### Production Deployment
```bash
# Production build with security
make build-security

# Optimized deployment
make qcow2 CONFIG_MK=config-production.mk
make deploy-vm CONFIG_MK=config-production.mk

# Performance verification
./scripts/performance-test.sh --production
```

## Best Practices

### Build Optimization
1. **Use cache**: Enable build cache for faster rebuilds
2. **Parallel builds**: Utilize all available CPU cores
3. **Layer optimization**: Order operations to maximize cache hits
4. **Resource limits**: Set appropriate memory and CPU constraints

### Dependency Management
1. **Automated discovery**: Let Ansible handle dependency resolution
2. **Version tracking**: Monitor dependency versions for security
3. **Minimal packages**: Only include necessary dependencies
4. **Regular updates**: Keep dependencies current

### Performance Monitoring
1. **Regular testing**: Run performance tests regularly
2. **Baseline comparison**: Compare against known good performance
3. **Resource monitoring**: Track CPU, memory, and disk usage
4. **Optimization validation**: Verify improvements with testing

## Troubleshooting

### Common Performance Issues

#### Slow Builds
```bash
# Check cache status
make cache-pull

# Verify resource allocation
make config-show | grep BUILD_

# Enable verbose output
VERBOSE=true make build
```

#### High Resource Usage
```bash
# Adjust resource limits
BUILD_MEMORY=2g BUILD_CPUS=2 make build

# Monitor system resources
htop
iotop
```

#### Cache Issues
```bash
# Clean cache
make cache-clean

# Reset build environment
make clean
make cache-pull
```

### Performance Debugging
```bash
# Enable detailed logging
VERBOSE=true make build

# Monitor build process
watch -n 1 'ps aux | grep podman'

# Check system resources
vmstat 1
```

### Optimization Validation
```bash
# Run performance tests
./scripts/performance-test.sh --all

# Compare results
./scripts/performance-test.sh --compare baseline.json

# Generate optimization report
./scripts/performance-test.sh --report
```