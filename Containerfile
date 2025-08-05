# Home Assistant bootc image with enhanced functionality
FROM quay.io/fedora/fedora-bootc:42 as ansible-stage
RUN dnf -y install linux-system-roles
RUN mkdir -p /deps
COPY bindep.txt /deps/
RUN /usr/share/ansible/collections/ansible_collections/fedora/linux_system_roles/roles/podman/.ostree/get_ostree_data.sh packages runtime fedora-42 raw >> /deps/bindep.txt || true

FROM quay.io/fedora/fedora-bootc:42

# Copy repository configurations
COPY repos/zerotier.repo /etc/yum.repos.d/zerotier.repo

# AGGRESSIVE SECURITY FIXES - Remove vulnerable packages before install
RUN dnf -y remove toolbox container-tools golang || true

# Upgrade all packages to latest versions (security fix)
RUN dnf -y upgrade --refresh

# Install packages from dependency list
RUN --mount=type=bind,from=ansible-stage,source=/deps/,target=/deps grep -v '^#' /deps/bindep.txt | grep -v '^$' | xargs dnf -y install

# Install additional useful packages for Home Assistant deployment
RUN dnf -y install \
    git \
    curl \
    wget \
    nano \
    htop \
    rsync \
    tmux \
    tree \
    jq \
    python3-pip \
    openssh-server \
    fail2ban \
    chrony \
    logrotate \
    && dnf clean all

# SECURITY: Force install latest secure versions of specific packages
# Upgrade urllib3 to fix vulnerability (dnf may not have latest version)
RUN pip3 install --upgrade --force-reinstall urllib3==2.5.0

# SECURITY: Completely remove toolbox and all Go dependencies
RUN dnf -y remove toolbox golang golang-bin container-tools \
    buildah skopeo podman-compose || true

# SECURITY: Force clean package cache and remove development packages
RUN dnf -y remove gcc gcc-c++ make automake autoconf libtool || true && \
    dnf clean all && \
    rm -rf /var/cache/dnf/* /tmp/* /var/tmp/*

# Configure firewall rules
RUN firewall-offline-cmd --add-port=8123/tcp && \
    firewall-offline-cmd --add-port=22/tcp && \
    firewall-offline-cmd --add-service=ssh

# Create necessary directories with proper permissions
RUN mkdir -p /var/home-assistant/config \
    /var/home-assistant/backups \
    /var/log/home-assistant \
    /opt/hass-scripts && \
    chmod 755 /var/home-assistant/config \
    /var/home-assistant/backups \
    /var/log/home-assistant \
    /opt/hass-scripts

# Copy systemd container services
COPY ./containers-systemd/* /usr/share/containers/systemd/

# Copy utility scripts
COPY scripts/ /opt/hass-scripts/
RUN chmod +x /opt/hass-scripts/*.sh

# Configure SSH for remote management
RUN systemctl enable sshd && \
    sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Configure chrony for time synchronization
RUN systemctl enable chronyd

# Configure fail2ban for security
RUN systemctl enable fail2ban

# Configure log rotation for Home Assistant
RUN echo '/var/log/home-assistant/*.log {' > /etc/logrotate.d/home-assistant && \
    echo '    daily' >> /etc/logrotate.d/home-assistant && \
    echo '    rotate 7' >> /etc/logrotate.d/home-assistant && \
    echo '    compress' >> /etc/logrotate.d/home-assistant && \
    echo '    delaycompress' >> /etc/logrotate.d/home-assistant && \
    echo '    missingok' >> /etc/logrotate.d/home-assistant && \
    echo '    notifempty' >> /etc/logrotate.d/home-assistant && \
    echo '    create 644 root root' >> /etc/logrotate.d/home-assistant && \
    echo '}' >> /etc/logrotate.d/home-assistant

# Set timezone to Prague (can be overridden via environment)
RUN ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime

# Add labels for metadata
LABEL org.opencontainers.image.title="Home Assistant bootc Image" \
      org.opencontainers.image.description="Immutable OS image with Home Assistant container orchestration" \
      org.opencontainers.image.vendor="Custom Build" \
      org.opencontainers.image.version="1.0.0"
