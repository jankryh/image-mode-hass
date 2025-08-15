# Optimized Home Assistant bootc image with enhanced performance
# Multi-stage build with aggressive optimization

#==================================================
# Stage 1: Base Preparation (Shared Dependencies)
#==================================================
FROM quay.io/fedora/fedora-bootc:42 as base-stage
LABEL stage=base-preparation

# Essential build arguments
ARG TIMEZONE=Europe/Prague
ARG HASS_BASE_DIR=/var/home-assistant
ARG HASS_SCRIPTS_DIR=/opt/hass-scripts
ARG HASS_CONFIG_BASE=/opt/hass-config

# Copy repository configurations first (for better caching)
COPY repos/zerotier.repo /etc/yum.repos.d/zerotier.repo

# Initialize DNF cache once
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    dnf makecache --refresh

# Remove unwanted packages early (single operation)
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y remove \
        toolbox* container-tools* golang* buildah* skopeo* \
        podman-compose* go-toolset* golang-*mapstructure* \
        golang-github* \
    || true && \
    dnf -y autoremove && \
    dnf clean packages

#==================================================
# Stage 2: Package Installation (Optimized)
#==================================================
FROM base-stage as package-stage
LABEL stage=package-installation

# Copy dependency list
COPY bindep.txt /tmp/bindep.txt

# Install packages in optimized order (stable packages first)
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y install \
        # Core system packages (most stable)
        vim-enhanced git curl wget nano rsync \
        bind-utils tcpdump strace lsof tree jq \
        # Network packages
        iwlwifi-dvm-firmware iwlwifi-mvm-firmware \
        wpa_supplicant openssh-server zerotier-one \
        # System utilities
        htop tmux python3-pip nut chrony \
        # Security packages (updated frequently)
        fail2ban \
    && dnf clean packages

# Apply security updates in separate layer
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y upgrade --refresh --security --exclude=kernel* \
    && dnf clean all

#==================================================
# Stage 3: Production Build (Final Image)
#==================================================
FROM package-stage as production
LABEL maintainer="Home Assistant bootc Image" \
      version="2.1.0-optimized" \
      description="High-performance immutable OS with Home Assistant" \
      org.opencontainers.image.title="Home Assistant bootc Image Optimized" \
      org.opencontainers.image.description="High-performance immutable OS with Home Assistant" \
      org.opencontainers.image.vendor="Custom Build Optimized" \
      org.opencontainers.image.version="2.1.0" \
      performance.optimized="true" \
      security.hardened="standard"

# Fix urllib3 vulnerability
RUN pip3 install --upgrade --force-reinstall \
    "urllib3>=2.5.0" "requests>=2.32.0" "cryptography>=42.0.0"

# System configuration (combined for efficiency)
RUN systemctl enable sshd chronyd fail2ban && \
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime && \
    # Firewall configuration
    firewall-offline-cmd --add-port=8123/tcp && \
    firewall-offline-cmd --add-port=22/tcp && \
    firewall-offline-cmd --add-service=ssh

# SSH hardening
RUN sed -i \
        -e 's/#PermitRootLogin yes/PermitRootLogin no/' \
        -e 's/#PasswordAuthentication yes/PasswordAuthentication no/' \
        -e 's/#Protocol 2/Protocol 2/' \
        -e 's/#LogLevel INFO/LogLevel VERBOSE/' \
        -e 's/#MaxAuthTries 6/MaxAuthTries 3/' \
        -e 's/#ClientAliveInterval 0/ClientAliveInterval 300/' \
        -e 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' \
        -e 's/#AllowTcpForwarding yes/AllowTcpForwarding no/' \
        -e 's/#X11Forwarding yes/X11Forwarding no/' \
        -e 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' \
        /etc/ssh/sshd_config

# Create directory structure
RUN mkdir -p \
        "${HASS_BASE_DIR}/config" \
        "${HASS_BASE_DIR}/backups" \
        "${HASS_BASE_DIR}/secrets" \
        "/var/log/home-assistant" \
        "${HASS_SCRIPTS_DIR}" \
        "${HASS_CONFIG_BASE}" \
        "/etc/hass-secrets" \
        "/etc/fail2ban/jail.d" \
    && chmod 755 \
        "${HASS_BASE_DIR}/config" \
        "${HASS_BASE_DIR}/backups" \
        "/var/log/home-assistant" \
        "${HASS_SCRIPTS_DIR}" \
        "${HASS_CONFIG_BASE}" \
    && chmod 700 \
        "${HASS_BASE_DIR}/secrets" \
        "/etc/hass-secrets" \
        "/root"

# Copy application files
COPY containers-systemd/ /usr/share/containers/systemd/
COPY scripts/ ${HASS_SCRIPTS_DIR}/
COPY configs/ ${HASS_CONFIG_BASE}/

# Configure fail2ban
RUN echo '[sshd]' > /etc/fail2ban/jail.d/custom.conf && \
    echo 'enabled = true' >> /etc/fail2ban/jail.d/custom.conf && \
    echo 'maxretry = 3' >> /etc/fail2ban/jail.d/custom.conf && \
    echo 'bantime = 3600' >> /etc/fail2ban/jail.d/custom.conf && \
    echo 'findtime = 600' >> /etc/fail2ban/jail.d/custom.conf

# Set up log rotation
RUN cat > /etc/logrotate.d/home-assistant << 'EOF'
/var/log/home-assistant/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

# Set executable permissions and final permissions
RUN chmod +x ${HASS_SCRIPTS_DIR}/*.sh && \
    find /etc -type f -name "*.conf" -exec chmod 644 {} \; && \
    find /etc -type f -name "*passwd*" -exec chmod 640 {} \; && \
    find /etc -type f -name "*shadow*" -exec chmod 600 {} \;

#==================================================
# Stage 4: Security Hardened Build (Optional)
#==================================================
FROM production as security-hardened
LABEL security.hardened="enhanced" \
      security.level="high" \
      security.compliance="cis-basic"

# Enhanced security: Remove development packages
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y remove \
        '*-devel' '*-debuginfo' '*-debugsource' \
        'gcc*' 'make*' 'automake*' 'autoconf*' \
        'cmake*' 'kernel-devel*' 'kernel-headers*' \
    || true && \
    dnf -y autoremove && \
    dnf clean all

# Enhanced firewall rules
RUN firewall-offline-cmd --set-default-zone=public && \
    firewall-offline-cmd --remove-service=dhcpv6-client 2>/dev/null || true && \
    firewall-offline-cmd --remove-service=mdns 2>/dev/null || true && \
    firewall-offline-cmd --remove-service=samba-client 2>/dev/null || true

# Security cleanup: Remove unnecessary files
RUN rm -rf \
        /usr/share/doc/* \
        /usr/share/man/* \
        /usr/share/info/* \
        /usr/share/locale/* \
        /usr/include/* \
        /usr/lib*/gconv \
        /usr/lib*/gcc \
        /usr/lib*/cmake \
        /usr/lib*/pkgconfig \
        /var/cache/* \
        /var/log/* \
        /tmp/* \
        /var/tmp/* \
    && mkdir -p /var/log/home-assistant

# Final security verification
RUN dnf -y check-update --security || true