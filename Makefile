# Home Assistant bootc Makefile (Default)
# Essential build and deployment tasks

# Include configuration
CONFIG_MK ?= config.mk
-include $(CONFIG_MK)

# Computed variables
FULL_IMAGE_NAME = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# Build flags
BUILD_FLAGS = \
	$(if $(filter true,$(USE_CACHE)),,--no-cache) \
	$(if $(filter true,$(VERBOSE)),--progress=plain,--progress=auto) \
	--pull=always

# Main targets
.PHONY: help build push clean qcow2 iso deploy-vm status

help: ## Show this help message
	@echo "Home Assistant bootc Build System (Simplified)"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build container image
	@echo "Building $(FULL_IMAGE_NAME)..."
	time $(SUDO_CMD) $(CONTAINER_RUNTIME) build $(BUILD_FLAGS) \
		-t $(FULL_IMAGE_NAME) \
		.
	@echo "Build completed: $(FULL_IMAGE_NAME)"

push: build ## Build and push image to registry
	@echo "Pushing $(FULL_IMAGE_NAME) to registry..."
	$(SUDO_CMD) podman push $(FULL_IMAGE_NAME)
	@echo "Push completed"

qcow2: build ## Build qcow2 image
	@echo "Building qcow2 image..."
	@mkdir -p $(OUTPUT_DIR)
	time sudo podman run \
		--rm --privileged --pull=newer \
		--memory=8g --cpus=$(shell nproc) \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--rootfs $(ROOTFS_TYPE) \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "qcow2 image created in $(OUTPUT_DIR)/"

iso: build ## Build ISO installer
	@echo "Building ISO installer..."
	@mkdir -p $(OUTPUT_DIR)
	time sudo podman run \
		--rm --privileged --pull=newer \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--rootfs $(ROOTFS_TYPE) \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "ISO installer created in $(OUTPUT_DIR)/"

deploy-vm: qcow2 ## Deploy VM
	@echo "Deploying VM: $(VM_NAME)"
	sudo mv $(OUTPUT_DIR)/qcow2/disk.qcow2 /var/lib/libvirt/images/$(VM_NAME).qcow2
	sudo virt-install \
		--name $(VM_NAME) \
		--memory $(VM_MEMORY) \
		--cpu host-passthrough \
		--vcpus $(VM_VCPUS) \
		--import --disk /var/lib/libvirt/images/$(VM_NAME).qcow2,bus=virtio \
		--network network=$(VM_NETWORK),model=virtio \
		--graphics $(VM_GRAPHICS) \
		--os-variant $(VM_OS_VARIANT) \
		--features acpi=on,apic=on
	@echo "VM deployed successfully"

status: ## Show build status
	@echo "=== Build Status ==="
	@echo "Image: $(FULL_IMAGE_NAME)"
	@echo "Config: $(CONFIG_FILE)"
	@echo "Output: $(OUTPUT_DIR)"
	@echo ""
	@echo "=== Local Images ==="
	@podman images | grep $(IMAGE_NAME) || echo "No local images found"
	@echo ""
	@echo "=== VMs ==="
	@sudo virsh list --all | grep $(IMAGE_NAME) || echo "No VMs found"

clean: ## Clean up build artifacts
	@echo "Cleaning up..."
	@rm -rf $(OUTPUT_DIR)
	@sudo podman rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	@sudo podman system prune -f
	@echo "Cleanup completed"

# Default target
.DEFAULT_GOAL := build
