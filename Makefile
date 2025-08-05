# Home Assistant bootc Image Makefile

# Include configuration file (can be overridden)
CONFIG_MK ?= config.mk
-include $(CONFIG_MK)

# Computed variables
FULL_IMAGE_NAME = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
CONTAINER_CMD = $(if $(filter true,$(USE_BUILDAH)),buildah,$(CONTAINER_RUNTIME))
BUILD_FLAGS = $(if $(filter true,$(USE_CACHE)),,--no-cache) $(if $(filter true,$(VERBOSE)),--progress=plain,) $(BUILD_ARGS)
RUN_FLAGS = $(if $(filter true,$(VERBOSE)),-v,) $(RUN_ARGS)

# Build targets
.PHONY: help build build-security push clean qcow2 iso raw deploy-vm status
.PHONY: dev-build dev-qcow2 dev-deploy all vm clean-vm
.PHONY: config-create config-show config-template validate-config info
.PHONY: config-template-dockerhub config-template-ghcr config-template-local
.PHONY: config-template-production config-template-development

help: ## Show this help message
	@echo "Home Assistant bootc Build System"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the bootc container image
	@echo "Building $(FULL_IMAGE_NAME)..."
	@echo "Using configuration: $(CONFIG_MK)"
	sudo $(CONTAINER_CMD) build $(BUILD_FLAGS) -t $(FULL_IMAGE_NAME) .
	@echo "Build completed: $(FULL_IMAGE_NAME)"

build-security: ## Build with security-focused options (no cache, latest packages)
	@echo "Building $(FULL_IMAGE_NAME) with security updates..."
	@echo "Using configuration: $(CONFIG_MK)"
	sudo $(CONTAINER_CMD) build --no-cache --pull=always -t $(FULL_IMAGE_NAME) .
	@echo "Security build completed: $(FULL_IMAGE_NAME)"

push: build ## Build and push image to registry
	@echo "Pushing $(FULL_IMAGE_NAME) to registry..."
	sudo podman push $(FULL_IMAGE_NAME)
	@echo "Push completed"

pull-deps: ## Pull required base images
	@echo "Pulling dependencies..."
	podman pull quay.io/fedora/fedora-bootc:latest
	podman pull quay.io/centos-bootc/bootc-image-builder:latest

qcow2: build pull-deps ## Build qcow2 VM image
	@echo "Building qcow2 image..."
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	sudo podman run \
		--rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--rootfs $(ROOTFS_TYPE) \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "qcow2 image created in $(OUTPUT_DIR)/"

iso: build pull-deps ## Build ISO installer
	@echo "Building ISO installer..."
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	sudo podman run \
		--rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--rootfs $(ROOTFS_TYPE) \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "ISO installer created in $(OUTPUT_DIR)/"

raw: build pull-deps ## Build raw disk image
	@echo "Building raw disk image..."
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	sudo podman run \
		--rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type raw \
		--rootfs $(ROOTFS_TYPE) \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "Raw disk image created in $(OUTPUT_DIR)/"

deploy-vm: qcow2 ## Deploy VM using libvirt
	@echo "Deploying VM: $(VM_NAME)"
	@echo "Configuration: Memory=$(VM_MEMORY)MB, vCPUs=$(VM_VCPUS), Network=$(VM_NETWORK)"
	sudo mv $(OUTPUT_DIR)/qcow2/disk.qcow2 /var/lib/libvirt/images/$(VM_NAME).qcow2
	sudo virt-install \
		--name $(VM_NAME) \
		--memory $(VM_MEMORY) \
		--cpu host-model \
		--vcpus $(VM_VCPUS) \
		--import --disk /var/lib/libvirt/images/$(VM_NAME).qcow2 \
		--network network=$(VM_NETWORK) \
		--graphics $(VM_GRAPHICS) \
		--os-variant $(VM_OS_VARIANT) \
		$(if $(filter none,$(VM_GRAPHICS)),--noautoconsole,)
	@echo "VM deployed successfully"

status: ## Show build and deployment status
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

clean-vm: ## Remove deployed VM
	@echo "Removing VM $(VM_NAME)..."
	@sudo virsh destroy $(VM_NAME) 2>/dev/null || true
	@sudo virsh undefine $(VM_NAME) 2>/dev/null || true
	@sudo rm -f /var/lib/libvirt/images/$(VM_NAME).qcow2
	@echo "VM removed"

# Development targets
dev-build: ## Build with development settings
	$(MAKE) build CONFIG_FILE=$(DEV_CONFIG) IMAGE_TAG=$(DEV_TAG)

dev-qcow2: ## Build development qcow2
	$(MAKE) qcow2 CONFIG_FILE=$(DEV_CONFIG) IMAGE_TAG=$(DEV_TAG)

dev-deploy: ## Deploy development VM
	$(MAKE) deploy-vm CONFIG_FILE=$(DEV_CONFIG) IMAGE_TAG=$(DEV_TAG) VM_NAME=$(DEV_VM_NAME)

# Quick targets
all: build qcow2 iso ## Build container and all image formats

vm: deploy-vm ## Quick VM deployment

# Configuration validation
validate-config: ## Validate configuration file
	@echo "Validating $(CONFIG_FILE)..."
	@jq empty $(CONFIG_FILE) && echo "Configuration is valid JSON" || (echo "Invalid JSON in $(CONFIG_FILE)" && exit 1)

# Information targets
info: ## Show detailed build information
	@echo "=== Build Configuration ==="
	@echo "Image Name: $(FULL_IMAGE_NAME)"
	@echo "Config File: $(CONFIG_FILE)"
	@echo "Config Source: $(CONFIG_MK)"
	@echo "Output Directory: $(OUTPUT_DIR)"
	@echo "Container Runtime: $(CONTAINER_CMD)"
	@echo ""
	@echo "=== VM Configuration ==="
	@echo "VM Name: $(VM_NAME)"
	@echo "Memory: $(VM_MEMORY)MB"
	@echo "vCPUs: $(VM_VCPUS)"
	@echo "Network: $(VM_NETWORK)"
	@echo "Graphics: $(VM_GRAPHICS)"
	@echo ""
	@echo "=== Development Configuration ==="
	@echo "Dev Tag: $(DEV_TAG)"
	@echo "Dev Config: $(DEV_CONFIG)"
	@echo "Dev VM Name: $(DEV_VM_NAME)"
	@echo ""
	@echo "=== System Information ==="
	@echo "OS: $$(grep PRETTY_NAME /etc/os-release | cut -d'\"' -f2)"
	@echo "Kernel: $$(uname -r)"
	@echo "Architecture: $$(uname -m)"
	@echo "Container Runtime Version: $$($(CONTAINER_RUNTIME) --version)"
	@echo ""
	@echo "=== Available Space ==="
	@df -h . | tail -1

# Configuration management targets
config-create: ## Create custom configuration file
	@if [ ! -f "$(CONFIG_MK)" ]; then \
		echo "Creating custom configuration: $(CONFIG_MK)"; \
		cp config.mk $(CONFIG_MK); \
		echo "Edit $(CONFIG_MK) to customize your settings"; \
	else \
		echo "Configuration file $(CONFIG_MK) already exists"; \
	fi

config-show: ## Show current configuration values
	@echo "=== Current Configuration Values ==="
	@echo "CONFIG_MK = $(CONFIG_MK)"
	@echo "IMAGE_NAME = $(IMAGE_NAME)"
	@echo "REGISTRY = $(REGISTRY)"
	@echo "IMAGE_TAG = $(IMAGE_TAG)"
	@echo "FULL_IMAGE_NAME = $(FULL_IMAGE_NAME)"
	@echo "CONFIG_FILE = $(CONFIG_FILE)"
	@echo "OUTPUT_DIR = $(OUTPUT_DIR)"
	@echo "CONTAINER_RUNTIME = $(CONTAINER_RUNTIME)"
	@echo "VM_NAME = $(VM_NAME)"
	@echo "VM_MEMORY = $(VM_MEMORY)"
	@echo "VM_VCPUS = $(VM_VCPUS)"
	@echo "DEV_TAG = $(DEV_TAG)"
	@echo "USE_CACHE = $(USE_CACHE)"
	@echo "VERBOSE = $(VERBOSE)"

config-template: ## Create configuration template for specific use case
	@echo "Available templates:"
	@echo "  1. docker-hub   - Configuration for Docker Hub"
	@echo "  2. ghcr         - Configuration for GitHub Container Registry"  
	@echo "  3. local        - Configuration for local registry"
	@echo "  4. production   - Production-ready configuration"
	@echo "  5. development  - Development configuration"
	@echo ""
	@read -p "Select template (1-5): " template; \
	case $$template in \
		1) $(MAKE) config-template-dockerhub ;; \
		2) $(MAKE) config-template-ghcr ;; \
		3) $(MAKE) config-template-local ;; \
		4) $(MAKE) config-template-production ;; \
		5) $(MAKE) config-template-development ;; \
		*) echo "Invalid selection" ;; \
	esac

config-template-dockerhub:
	@echo "Creating Docker Hub configuration..."
	@echo "# Docker Hub Configuration" > config-dockerhub.mk
	@echo "REGISTRY = docker.io/yourusername" >> config-dockerhub.mk
	@echo "IMAGE_NAME = fedora-bootc-hass" >> config-dockerhub.mk
	@echo "CONFIG_FILE = config-production.json" >> config-dockerhub.mk
	@echo "Created: config-dockerhub.mk"

config-template-ghcr:
	@echo "Creating GitHub Container Registry configuration..."
	@echo "# GitHub Container Registry Configuration" > config-ghcr.mk
	@echo "REGISTRY = ghcr.io/yourusername" >> config-ghcr.mk
	@echo "IMAGE_NAME = home-assistant-bootc" >> config-ghcr.mk
	@echo "CONFIG_FILE = config-production.json" >> config-ghcr.mk
	@echo "Created: config-ghcr.mk"

config-template-local:
	@echo "Creating local registry configuration..."
	@echo "# Local Registry Configuration" > config-local.mk
	@echo "REGISTRY = localhost:5000" >> config-local.mk
	@echo "IMAGE_TAG = test" >> config-local.mk
	@echo "USE_CACHE = false" >> config-local.mk
	@echo "VERBOSE = true" >> config-local.mk
	@echo "Created: config-local.mk"

config-template-production:
	@echo "Creating production configuration..."
	@echo "# Production Configuration" > config-production.mk
	@echo "CONFIG_FILE = config-production.json" >> config-production.mk
	@echo "VM_MEMORY = 8192" >> config-production.mk
	@echo "VM_VCPUS = 4" >> config-production.mk
	@echo "ENABLE_HEALTH_CHECK = true" >> config-production.mk
	@echo "USE_CACHE = true" >> config-production.mk
	@echo "Created: config-production.mk"

config-template-development:
	@echo "Creating development configuration..."
	@echo "# Development Configuration" > config-development.mk
	@echo "CONFIG_FILE = config-example.json" >> config-development.mk
	@echo "IMAGE_TAG = dev" >> config-development.mk
	@echo "DEBUG = true" >> config-development.mk
	@echo "VERBOSE = true" >> config-development.mk
	@echo "USE_CACHE = false" >> config-development.mk
	@echo "VM_MEMORY = 2048" >> config-development.mk
	@echo "Created: config-development.mk"