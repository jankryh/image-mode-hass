# Home Assistant bootc Image Makefile
# Simplified build system for Home Assistant bootc images

# Include configuration file
CONFIG_MK ?= config.mk
-include $(CONFIG_MK)

# Build optimization
export DOCKER_BUILDKIT = 1
export BUILDAH_FORMAT = docker

# Computed variables
FULL_IMAGE_NAME = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
CONTAINER_CMD = $(if $(filter true,$(USE_BUILDAH)),buildah,$(CONTAINER_RUNTIME))

# Build flags
BUILD_FLAGS = \
	$(if $(filter true,$(USE_CACHE)),,--no-cache) \
	$(if $(filter true,$(VERBOSE)),--progress=plain,--progress=auto) \
	--pull=always \
	$(BUILD_ARGS)

# Run flags
RUN_FLAGS = \
	$(if $(filter true,$(VERBOSE)),-v,) \
	--memory=$(BUILD_MEMORY) \
	--cpus=$(BUILD_CPUS) \
	$(RUN_ARGS)

# Build optimization variables
BUILD_MEMORY ?= 4g
BUILD_CPUS ?= $(shell nproc)

# Main targets
.PHONY: help build push clean qcow2 iso raw deploy-vm status
.PHONY: deps-update deps-check test version security-scan
.PHONY: build-x86 build-arm64 show-arch

help: ## Show this help message
	@echo "Home Assistant bootc Build System"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Cross-Platform Targets:"
	@echo "  show-arch           Show architecture information"
	@echo "  build-x86           Build x86_64 container image"
	@echo "  build-arm64         Build ARM64 container image"

build: ## Build container image
	@echo "Building $(FULL_IMAGE_NAME)..."
	@echo "Using: $(BUILD_CPUS) CPUs, $(BUILD_MEMORY) memory"
	time $(SUDO_CMD) $(CONTAINER_CMD) build $(BUILD_FLAGS) \
		-t $(FULL_IMAGE_NAME) \
		.
	@echo "Build completed: $(FULL_IMAGE_NAME)"

push: build ## Build and push image to registry
	@echo "Pushing $(FULL_IMAGE_NAME) to registry..."
	$(SUDO_CMD) podman push $(FULL_IMAGE_NAME)
	@echo "Push completed"

qcow2: build pull-deps ## Build qcow2 image
	@echo "Building qcow2 image..."
	@mkdir -p $(OUTPUT_DIR)
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "On macOS: Using podman machine for qcow2 build"; \
		podman machine set --rootful || true; \
		podman machine start || true; \
		time sudo podman run \
			--rm --privileged --pull=newer \
			$(RUN_FLAGS) \
			--memory=8g --cpus=$(shell nproc) \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type qcow2 \
			--rootfs $(ROOTFS_TYPE) \
			--config /config.toml \
			$(FULL_IMAGE_NAME); \
	else \
		time sudo podman run \
			--rm --privileged --pull=newer \
			$(RUN_FLAGS) \
			--memory=8g --cpus=$(shell nproc) \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type qcow2 \
			--rootfs $(ROOTFS_TYPE) \
			--config /config.toml \
			$(FULL_IMAGE_NAME); \
	fi
	@echo "qcow2 image created in $(OUTPUT_DIR)/"

iso: build pull-deps ## Build ISO installer
	@echo "Building ISO installer..."
	@mkdir -p $(OUTPUT_DIR)
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "Failed to set rootful mode"; \
		podman machine start || echo "Failed to start machine"; \
		sleep 3; \
		sudo podman run \
			--rm --privileged --pull=newer \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type iso \
			--rootfs $(ROOTFS_TYPE) \
			--config /config.toml \
			$(FULL_IMAGE_NAME); \
	else \
		sudo podman run \
			--rm --privileged --pull=newer \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type iso \
			--rootfs $(ROOTFS_TYPE) \
			--config /config.toml \
			$(FULL_IMAGE_NAME); \
	fi
	@echo "ISO installer created in $(OUTPUT_DIR)/"

raw: build pull-deps ## Build raw disk image
	@echo "Building raw disk image..."
	@mkdir -p $(OUTPUT_DIR)
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "Failed to set rootful mode"; \
		podman machine start || echo "Failed to start machine"; \
		sleep 3; \
		sudo podman run \
			--rm --privileged --pull=newer \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type raw \
			--rootfs $(ROOTFS_TYPE) \
			--config /config.toml \
			$(FULL_IMAGE_NAME); \
	else \
		sudo podman run \
			--rm --privileged --pull=newer \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type raw \
			--rootfs $(ROOTFS_TYPE) \
			--config /config.toml \
			$(FULL_IMAGE_NAME); \
	fi
	@echo "Raw disk image created in $(OUTPUT_DIR)/"

deploy-vm: qcow2 ## Deploy VM
	@echo "Deploying VM: $(VM_NAME)"
	@echo "Configuration: Memory=$(VM_MEMORY)MB, vCPUs=$(VM_VCPUS)"
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
		--features acpi=on,apic=on \
		$(if $(filter none,$(VM_GRAPHICS)),--noautoconsole,)
	@echo "VM deployed successfully"

pull-deps: ## Pull required base images
	@echo "Pulling dependencies..."
	podman pull quay.io/fedora/fedora-bootc:latest
	podman pull quay.io/centos-bootc/bootc-image-builder:latest

deps-update: ## Update dependencies
	@echo "Updating dependencies..."
	@./scripts/deps-update.sh
	@echo "Dependencies updated"

deps-check: ## Check dependency versions
	@echo "Checking dependencies..."
	@./scripts/deps-check.sh
	@echo "Dependency check completed"

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

test: ## Run tests
	@echo "Running tests..."
	@chmod +x tests/run-all-tests.sh
	@tests/run-all-tests.sh

version: ## Show current version
	@chmod +x scripts/version-manager.sh
	@scripts/version-manager.sh show

security-scan: ## Run security scan
	@echo "Running security scan..."
	@chmod +x scripts/security-check.sh
	@scripts/security-check.sh scan --image $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

# Cross-platform targets
show-arch: ## Show architecture information
	@echo "Architecture Information:"
	@echo "  Host Architecture: $(shell uname -m)"
	@echo "  Target Architecture: $(TARGET_ARCH)"
	@echo "  Platform Suffix: $(PLATFORM_SUFFIX)"
	@echo "  Image Name: $(ARCH_IMAGE_NAME)"
	@echo "  Full Image Name: $(FULL_ARCH_IMAGE_NAME)"

build-x86: ## Build container image for x86_64 architecture
	@echo "Building x86_64 image: $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG)"
	sudo $(CONTAINER_RUNTIME) build \
		--platform linux/amd64 \
		$(BUILD_FLAGS) \
		--build-arg TIMEZONE=$(TIMEZONE) \
		-t $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG) \
		.
	@echo "x86_64 build completed: $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG)"

build-arm64: ## Build container image for ARM64 architecture
	@echo "Building ARM64 image: $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"
	sudo $(CONTAINER_RUNTIME) build \
		--platform linux/arm64 \
		$(BUILD_FLAGS) \
		--build-arg TIMEZONE=$(TIMEZONE) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		.
	@echo "ARM64 build completed: $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"

# Default target
.DEFAULT_GOAL := build