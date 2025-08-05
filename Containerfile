# Optimized Home Assistant bootc image with enhanced performance
# Multi-stage build with aggressive optimization

#==================================================
# Stage 1: Dependency Resolution (Cached Layer)
#==================================================
FROM quay.io/fedora/fedora-bootc:42 as deps-stage
LABEL stage=dependency-resolution

# Install linux-system-roles early for better caching
RUN --mount=type=cache,target=/var/cache/dnf \
    dnf -y install linux-system-roles && \
    dnf clean metadata

# Create dependency directory and copy static deps
RUN mkdir -p /deps
COPY bindep.txt /deps/

# Generate runtime dependencies via Ansible (cached operation)
RUN /usr/share/ansible/collections/ansible_collections/fedora/linux_system_roles/roles/podman/.ostree/get_ostree_data.sh packages runtime fedora-42 raw >> /deps/bindep.txt || true

#==================================================
# Stage 2: Package Preparation (Optimized Layer)
#==================================================
FROM quay.io/fedora/fedora-bootc:42 as package-stage
LABEL stage=package-optimization

# Copy repository configurations early
COPY repos/zerotier.repo /etc/yum.repos.d/zerotier.repo

# PERFORMANCE: Aggressive package cache optimization
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    dnf makecache --refresh

# SECURITY + PERFORMANCE: Remove vulnerable packages in single layer
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y remove toolbox container-tools golang golang-bin buildah skopeo || true

# PERFORMANCE: Upgrade all packages with cache
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y upgrade --refresh --exclude=kernel*

#==================================================
# Stage 3: Production Build (Final Optimized Image)
#==================================================
FROM quay.io/fedora/fedora-bootc:42
LABEL maintainer="Home Assistant bootc Image" \
      version="2.0.0-optimized" \
      description="High-performance immutable OS with Home Assistant"

# Copy optimized repository configs
COPY repos/zerotier.repo /etc/yum.repos.d/zerotier.repo

# PERFORMANCE: Install packages in optimal order (frequently changing last)
# 1. Essential system packages (rarely change)
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=bind,from=deps-stage,source=/deps/,target=/deps \
    grep -v '^#' /deps/bindep.txt | grep -v '^$' | \
    head -20 | xargs dnf -y install

# 2. Development and utility packages (change occasionally)  
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y install \
    git curl wget nano vim-enhanced \
    rsync tmux tree jq \
    bind-utils tcpdump strace lsof \
    && dnf clean packages

# 3. Security and monitoring packages (change frequently)
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y install \
    openssh-server fail2ban chrony \
    htop python3-pip logrotate \
    && dnf clean all

# PERFORMANCE: Python packages optimization 
RUN pip3 install --upgrade --force-reinstall \
    urllib3==2.5.0 requests cryptography

# PERFORMANCE: Combine system configuration in single layer
RUN firewall-offline-cmd --add-port=8123/tcp && \
    firewall-offline-cmd --add-port=22/tcp && \
    firewall-offline-cmd --add-service=ssh && \
    # SSH hardening
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    # Enable services
    systemctl enable sshd chronyd fail2ban && \
    # Set timezone
    ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime

# PERFORMANCE: Create all directories in single layer
RUN mkdir -p \
    /var/home-assistant/config \
    /var/home-assistant/backups \
    /var/home-assistant/secrets \
    /var/log/home-assistant \
    /opt/hass-scripts \
    /opt/hass-config \
    /etc/hass-secrets && \
    chmod 755 /var/home-assistant/config /var/home-assistant/backups \
              /var/log/home-assistant /opt/hass-scripts /opt/hass-config && \
    chmod 700 /var/home-assistant/secrets /etc/hass-secrets

# PERFORMANCE: Copy all files in optimal order (most stable first)
COPY containers-systemd/ /usr/share/containers/systemd/
COPY scripts/ /opt/hass-scripts/
COPY configs/ /opt/hass-config/

# PERFORMANCE: Set permissions and log rotation in single layer
RUN chmod +x /opt/hass-scripts/*.sh && \
    # Configure log rotation
    echo '/var/log/home-assistant/*.log {' > /etc/logrotate.d/home-assistant && \
    echo '    daily' >> /etc/logrotate.d/home-assistant && \
    echo '    rotate 7' >> /etc/logrotate.d/home-assistant && \
    echo '    compress' >> /etc/logrotate.d/home-assistant && \
    echo '    delaycompress' >> /etc/logrotate.d/home-assistant && \
    echo '    missingok' >> /etc/logrotate.d/home-assistant && \
    echo '    notifempty' >> /etc/logrotate.d/home-assistant && \
    echo '    create 644 root root' >> /etc/logrotate.d/home-assistant && \
    echo '}' >> /etc/logrotate.d/home-assistant

# PERFORMANCE: Final cleanup in single layer
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y remove gcc gcc-c++ make automake autoconf libtool || true && \
    dnf clean all && \
    rm -rf /var/cache/dnf/* /tmp/* /var/tmp/* && \
    # Remove unnecessary documentation
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* && \
    # Clean package manager metadata
    find /var/lib/rpm -name "*.rpm" -delete 2>/dev/null || true

# Optimized metadata labels
LABEL org.opencontainers.image.title="Home Assistant bootc Image Optimized" \
      org.opencontainers.image.description="High-performance immutable OS with Home Assistant" \
      org.opencontainers.image.vendor="Custom Build Optimized" \
      org.opencontainers.image.version="2.0.0" \
      org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      io.buildah.version="$(buildah --version | cut -d' ' -f3)" \
      performance.optimized="true" \
      security.hardened="true"