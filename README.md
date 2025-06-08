# Home Assistant - Image Mode Setup

Repo to test how to deploy and manage Home Assistant in Image Mode.

More about [Image Mode here](https://developers.redhat.com/products/rhel-image-mode/overview).

## The plan

First lets try to run from plain RHEL bootc image, no customizations.

Then lets see if it will make some sense to customize the image... I hope it won't.

## Prerequisites

- RHEL 9 System with
  - registered
  - podman installed
    - `dnf -y install podman`
  - logged into the registry to non-root and root accounts
    - `podman login registry.redhat.io`
    - `sudo podman login registry.redhat.io`

## Build bootc image

Build bootc image as a root user:

```bash
podman build -t quay.io/jwerak/rhel-bootc-hass .
```

## Deploy instance

### Libvirt deployment

Export qcow2 format:

```bash
podman pull registry.redhat.io/rhel10/rhel-bootc:latest
podman pull registry.redhat.io/rhel10/bootc-image-builder:latest
podman run \
    --rm -it --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    -v ./config.toml:/config.toml \
    -v .:/output \
    registry.redhat.io/rhel10/bootc-image-builder:latest \
    --type qcow2 \
    --config /config.toml \
  quay.io/jwerak/rhel-bootc-hass
```

Run VM:

```bash
sudo mv ./qcow2/disk.qcow2 /var/lib/libvirt/images/rhel-bootc-home-assistant.qcow2
sudo virt-install \
    --name rhel-bootc-home-assistant \
    --memory 4096 \
    --cpu host-model \
    --vcpus 2 \
    --import --disk /var/lib/libvirt/images/rhel-bootc-home-assistant.qcow2 \
    --os-variant rhel10.0
```

### Deploy to metal

TBD

## References

- Nice [Getting Started blog](https://www.redhat.com/en/blog/image-mode-red-hat-enterprise-linux-quick-start-guide)
- How to [Build and Deploy image mode RHEL](https://developers.redhat.com/articles/2025/03/12/how-build-deploy-and-manage-image-mode-rhel#image_mode_for_rhel)