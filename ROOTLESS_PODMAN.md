# Rootless Podman Support Guide

This guide explains how to use Home Assistant bootc with rootless Podman for enhanced security.

## 🔒 What is Rootless Podman?

Rootless Podman allows you to run containers without root privileges, providing:
- Enhanced security by limiting potential attack surface
- User namespace isolation
- No daemon running as root
- Compliance with security policies

## 📋 Prerequisites

### System Requirements
- Podman 4.0 or newer
- User namespaces enabled in kernel
- Sufficient subuid/subgid ranges

### Check Prerequisites
```bash
# Check Podman version
podman --version

# Check user namespaces
sysctl user.max_user_namespaces

# Check subuid/subgid
grep $USER /etc/subuid /etc/subgid
```

## 🚀 Setup Instructions

### 1. Configure User Namespaces

```bash
# Enable user namespaces (if not enabled)
sudo sysctl -w user.max_user_namespaces=28633

# Make persistent
echo "user.max_user_namespaces=28633" | sudo tee /etc/sysctl.d/99-userns.conf
```

### 2. Configure Subuid/Subgid

```bash
# Add ranges for your user (if not present)
sudo usermod --add-subuids 100000-165536 $USER
sudo usermod --add-subgids 100000-165536 $USER

# Verify
podman unshare cat /proc/self/uid_map
```

### 3. Configure Storage

Create `~/.config/containers/storage.conf`:
```toml
[storage]
driver = "overlay"
runroot = "$HOME/.local/share/containers/storage"
graphroot = "$HOME/.local/share/containers/storage"

[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
```

## 🔨 Building with Rootless Podman

### Build Configuration

Update your build commands to use rootless Podman:

```bash
# Set DOCKER_HOST for compatibility
export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"

# Build image
podman build -t localhost/fedora-bootc-hass:latest .

# For make targets
CONTAINER_RUNTIME=podman make build
```

### Registry Configuration

For rootless Podman, configure registries in `~/.config/containers/registries.conf`:

```toml
[[registry]]
location = "quay.io"
insecure = false

[[registry]]
location = "docker.io"
insecure = false

# Add short name aliases
[aliases]
"fedora-bootc" = "quay.io/fedora/fedora-bootc"
```

## 🚢 Running Containers

### Systemd User Services

Create user systemd service for Home Assistant:

```bash
# Create user systemd directory
mkdir -p ~/.config/systemd/user

# Generate systemd unit
podman generate systemd --new --name home-assistant > ~/.config/systemd/user/home-assistant.service

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now home-assistant.service
```

### Port Binding Considerations

For ports below 1024, use higher ports and configure port forwarding:

```bash
# Use high port
podman run -d --name home-assistant -p 8123:8123 localhost/fedora-bootc-hass

# Or use pasta for port forwarding (Podman 4.4+)
podman run -d --name home-assistant --network pasta:--map-gw,-a,10.0.2.0,-n,24 -p 8123:8123 localhost/fedora-bootc-hass
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Permission Denied Errors
```bash
# Check ownership
podman unshare ls -la /var/lib/containers

# Reset permissions if needed
podman system reset
```

#### 2. Storage Issues
```bash
# Clean up storage
podman system prune -a

# Check storage driver
podman info | grep -A5 "graphDriverName"
```

#### 3. Network Issues
```bash
# Check network backend
podman info | grep networkBackend

# Use different network modes
podman run --network=host ...  # Host networking
podman run --network=pasta ...  # Pasta networking (newer)
```

### Debug Commands

```bash
# Verbose output
podman --log-level=debug build .

# Check user mapping
podman unshare id

# Inspect storage
podman info

# Check capabilities
capsh --print
```

## 📝 Configuration Updates

### Makefile Adjustments

Add these variables to your `config.mk`:

```makefile
# Rootless Podman settings
ROOTLESS_MODE ?= auto
PODMAN_SOCKET ?= $(XDG_RUNTIME_DIR)/podman/podman.sock

# Auto-detect rootless mode
ifeq ($(ROOTLESS_MODE),auto)
    ifneq ($(wildcard $(PODMAN_SOCKET)),)
        USE_ROOTLESS = true
    endif
endif

# Adjust commands for rootless
ifeq ($(USE_ROOTLESS),true)
    CONTAINER_RUNTIME = podman
    SUDO_CMD =
else
    SUDO_CMD = sudo
endif
```

### Script Updates

Update scripts to detect rootless mode:

```bash
# In scripts/config.sh
detect_rootless_podman() {
    if [[ -S "$XDG_RUNTIME_DIR/podman/podman.sock" ]]; then
        export ROOTLESS_PODMAN=true
        export CONTAINER_RUNTIME=podman
        export SUDO_CMD=""
    else
        export ROOTLESS_PODMAN=false
        export SUDO_CMD="sudo"
    fi
}
```

## 🚀 Best Practices

1. **Use User Services**: Run containers as systemd user services
2. **High Ports**: Use ports above 1024 to avoid permission issues
3. **Volume Permissions**: Ensure proper ownership for mounted volumes
4. **Regular Updates**: Keep Podman and dependencies updated
5. **Security Policies**: Define security policies for rootless containers

## 📚 Additional Resources

- [Podman Rootless Tutorial](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [User Namespaces Documentation](https://man7.org/linux/man-pages/man7/user_namespaces.7.html)
- [Podman Troubleshooting Guide](https://github.com/containers/podman/blob/main/troubleshooting.md)

## 🤝 Contributing

If you encounter issues or have improvements for rootless support, please:
1. Check existing issues
2. Provide detailed environment information
3. Include podman info output
4. Submit pull requests with tested solutions