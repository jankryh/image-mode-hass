FROM registry.redhat.io/rhel10/rhel-bootc:latest as ansible-stage
RUN dnf -y install rhel-system-roles
RUN mkdir -p /deps
RUN /usr/share/ansible/collections/ansible_collections/redhat/rhel_system_roles/roles/podman/.ostree/get_ostree_data.sh packages runtime centos-10 raw > /deps/ansible.txt || true

FROM registry.redhat.io/rhel10/rhel-bootc:latest
RUN --mount=type=bind,from=ansible-stage,source=/deps/,target=/deps cat /deps/ansible.txt | xargs dnf -y install