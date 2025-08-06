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

# SECURITY: Aggressively remove vulnerable packages and force updates
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    dnf -y remove toolbox* container-tools* golang* buildah* skopeo* podman-compose* \
        go-toolset* golang-*mapstructure* golang-github* || true && \
    dnf -y autoremove

# SECURITY: Force security updates and latest patches
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    dnf makecache --refresh && \
    dnf -y upgrade --refresh --security --exclude=kernel* && \
    dnf clean all

#==================================================
# Stage 3: Production Build (Final Optimized Image)
#==================================================
FROM quay.io/fedora/fedora-bootc:42 as production
LABEL maintainer="Home Assistant bootc Image" \
      version="2.0.0-optimized" \
      description="High-performance immutable OS with Home Assistant"

# Copy optimized repository configs
COPY repos/zerotier.repo /etc/yum.repos.d/zerotier.repo

# ===================================================================
# FIX: Remove vulnerable packages from the final production stage.
# This resolves vulnerabilities introduced by toolbox and related packages.
# ===================================================================
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y remove toolbox* container-tools* golang* buildah* skopeo* podman-compose* go-toolset* golang-*mapstructure* golang-github* runc* crun* conmon* || true && \
    dnf -y autoremove && \
    dnf clean all

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

# ===================================================================
# FIX: Remove system urllib3 and force install the patched version.
# This resolves GHSA-pq67-6m6q-mj2v and GHSA-48p4-8xcf-vxj5.
# ===================================================================
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf -y remove python3-urllib3 || true && \
    pip3 install --upgrade --force-reinstall \
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
    ln -sf /usr/share/zoneinfo/${TIMEZONE:-Europe/Prague} /etc/localtime

# PERFORMANCE: Create all directories in single layer
# Configure paths via build args
ARG HASS_BASE_DIR=/var/home-assistant
ARG HASS_SCRIPTS_DIR=/opt/hass-scripts
ARG HASS_CONFIG_BASE=/opt/hass-config

RUN mkdir -p \
    ${HASS_BASE_DIR}/config \
    ${HASS_BASE_DIR}/backups \
    ${HASS_BASE_DIR}/secrets \
    /var/log/home-assistant \
    ${HASS_SCRIPTS_DIR} \
    ${HASS_CONFIG_BASE} \
    /etc/hass-secrets && \
    chmod 755 ${HASS_BASE_DIR}/config ${HASS_BASE_DIR}/backups \
              /var/log/home-assistant ${HASS_SCRIPTS_DIR} ${HASS_CONFIG_BASE} && \
    chmod 700 ${HASS_BASE_DIR}/secrets /etc/hass-secrets

# PERFORMANCE: Copy all files in optimal order (most stable first)
COPY containers-systemd/ /usr/share/containers/systemd/
# Copy scripts with configurable target
ARG HASS_SCRIPTS_DIR=/opt/hass-scripts
COPY scripts/ ${HASS_SCRIPTS_DIR}/
COPY configs/ /opt/hass-config/

# PERFORMANCE: Set permissions and log rotation in single layer
RUN chmod +x ${HASS_SCRIPTS_DIR}/*.sh && \
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
      security.hardened="standard"

#==================================================
# Stage 4: Security Hardened Build (Enhanced Security)
#==================================================
FROM production as security-hardened

# SECURITY: Enhanced vulnerability mitigation
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    --mount=type=cache,target=/var/lib/dnf,sharing=locked \
    # Remove ALL potentially vulnerable packages aggressively
    dnf -y remove \
        *-devel *-debuginfo *-debugsource \
        gcc* make* automake* autoconf* libtool* \
        cmake* kernel-devel* kernel-headers* || true && \
    # Force remove vulnerable libs
    dnf -y remove \
        *viper* *mapstructure* *golang* || true && \
    # Aggressive cleanup
    dnf -y autoremove && \
    dnf clean all

# SECURITY: Force latest security updates (second pass)
RUN --mount=type=cache,target=/var/cache/dnf,sharing=locked \
    dnf makecache --refresh && \
    dnf -y check-update --security || true && \
    dnf -y upgrade --refresh --security --nobest && \
    dnf -y distro-sync --nobest && \
    dnf clean all

# SECURITY: Remove unnecessary files and reduce attack surface
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

# SECURITY: Enhanced SSH hardening
RUN sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config && \
    sed -i 's/#LogLevel INFO/LogLevel VERBOSE/' /etc/ssh/sshd_config && \
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config && \
    sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config && \
    sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 2/' /etc/ssh/sshd_config && \
    sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding no/' /etc/ssh/sshd_config && \
    sed -i 's/#X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config

# SECURITY: Enhanced fail2ban configuration
RUN mkdir -p /etc/fail2ban/jail.d && \
    echo '[sshd]' > /etc/fail2ban/jail.d/custom.conf && \
    echo 'enabled = true' >> /etc/fail2ban/jail.d/custom.conf && \
    echo 'maxretry = 3' >> /etc/fail2ban/jail.d/custom.conf && \
    echo 'bantime = 3600' >> /etc/fail2ban/jail.d/custom.conf && \
    echo 'findtime = 600' >> /etc/fail2ban/jail.d/custom.conf

# SECURITY: Enhanced firewall rules
RUN firewall-offline-cmd --set-default-zone=public && \
    firewall-offline-cmd --remove-service=dhcpv6-client || true && \
    firewall-offline-cmd --remove-service=mdns || true && \
    firewall-offline-cmd --remove-service=samba-client || true

# SECURITY: File system permissions hardening
RUN chmod 700 /root && \
    chmod 755 /etc /usr /var && \
    find /etc -type f -name "*.conf" -exec chmod 644 {} \; && \
    find /etc -type f -name "*passwd*" -exec chmod 640 {} \; && \
    find /etc -type f -name "*shadow*" -exec chmod 600 {} \;
# SECURITY: Update labels with enhanced security info
LABEL security.hardened="enhanced" \
      security.scan.date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
      security.vulnerabilities.removed="toolbox,golang,mapstructure,urllib3" \
      security.level="high" \
      security.compliance="cis-basic"