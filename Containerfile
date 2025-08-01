FROM quay.io/fedora/fedora-bootc:42 as ansible-stage
RUN dnf -y install linux-system-roles
RUN mkdir -p /deps
COPY bindep.txt /deps/
RUN /usr/share/ansible/collections/ansible_collections/fedora/linux_system_roles/roles/podman/.ostree/get_ostree_data.sh packages runtime fedora-42 raw >> /deps/bindep.txt || true

FROM quay.io/fedora/fedora-bootc:42
COPY repos/zerotier.repo /etc/yum.repos.d/zerotier.repo
RUN --mount=type=bind,from=ansible-stage,source=/deps/,target=/deps cat /deps/bindep.txt | xargs dnf -y install

COPY ./containers-systemd/* /usr/share/containers/systemd/
RUN mkdir -p /var/home-assistant/config && \
    firewall-offline-cmd --add-port=8123/tcp
