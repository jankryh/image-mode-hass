# Home Assistant - Image Mode Setup

Repo to test how to deploy and manage Home Assistant in Image Mode.

More about [Image Mode here](https://developers.redhat.com/products/rhel-image-mode/overview).

## The plan

First lets try to run from plain RHEL bootc image, no customizations.

Then lets see if it will make some sense to customize the image... I hope it won't.

## Prerequisites

When on Fedora 42:

- Install podman
- Subscribe system (to easily pass subscription to built containers)
  - `sudo dnf install subscription-manager && sudo subscription-manager register --username YOUR_REDHAT_USERNAME --password YOUR_REDHAT_PASSWORD --auto-attach`
  - `podman login registry.redhat.io`

Backup Option:

- RHEL 9 System with
  - registered
  - podman installed
    - `dnf -y install podman`
  - logged into the registry to non-root and root accounts
    - `podman login registry.redhat.io`
    - `sudo podman login registry.redhat.io`

## Setup image

Build bootc image as a root user:

```bash
podman pull registry.redhat.io/rhel10/rhel-bootc:latest
podman run --rm -it --privileged \
    -v .:/output \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v $(pwd)/config.json:/config.json \
    --pull newer \
    registry.redhat.io/rhel10/bootc-image-builder:10.0 \
    --type qcow2 \
    --config /config.json \
    registry.redhat.io/rhel10/rhel-bootc:latest
```

## Deploy VM

```bash
virt-install \
    --name rhel-bootc-home-assistant \
    --memory 4096 \
    --cpu host-model \
    --vcpus 2 \
    --import --disk ./qcow2/disk.qcow2,format=qcow2 \
    --os-variant rhel10.0
```

### Libvirt deployment

### Deploy to metal

TBD

## References

- Nice [Getting Started blog](https://www.redhat.com/en/blog/image-mode-red-hat-enterprise-linux-quick-start-guide)