# Home Assistant bootc Image Makefile

# Variables
IMAGE_NAME ?= fedora-bootc-hass
REGISTRY ?= quay.io/rh-ee-jkryhut
IMAGE_TAG ?= latest
FULL_IMAGE_NAME = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
CONFIG_FILE ?= config-production.json
OUTPUT_DIR ?= ./output

# Build targets
.PHONY: help build push clean qcow2 iso raw deploy-vm status

help: ## Show this help message
	@echo "Home Assistant bootc Build System"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the bootc container image
	@echo "Building $(FULL_IMAGE_NAME)..."
	sudo podman build -t $(FULL_IMAGE_NAME) .
	@echo "Build completed: $(FULL_IMAGE_NAME)"

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
	sudo podman run \
		--rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type qcow2 \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "qcow2 image created in $(OUTPUT_DIR)/"

iso: build pull-deps ## Build ISO installer
	@echo "Building ISO installer..."
	@mkdir -p $(OUTPUT_DIR)
	sudo podman run \
		--rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type iso \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "ISO installer created in $(OUTPUT_DIR)/"

raw: build pull-deps ## Build raw disk image
	@echo "Building raw disk image..."
	@mkdir -p $(OUTPUT_DIR)
	sudo podman run \
		--rm -it --privileged --pull=newer \
		--security-opt label=type:unconfined_t \
		-v /var/lib/containers/storage:/var/lib/containers/storage \
		-v ./$(CONFIG_FILE):/config.toml:ro \
		-v $(OUTPUT_DIR):/output \
		quay.io/centos-bootc/bootc-image-builder:latest \
		--type raw \
		--config /config.toml \
		$(FULL_IMAGE_NAME)
	@echo "Raw disk image created in $(OUTPUT_DIR)/"

deploy-vm: qcow2 ## Deploy VM using libvirt
	@echo "Deploying VM..."
	sudo mv $(OUTPUT_DIR)/qcow2/disk.qcow2 /var/lib/libvirt/images/$(IMAGE_NAME).qcow2
	sudo virt-install \
		--name $(IMAGE_NAME) \
		--memory 4096 \
		--cpu host-model \
		--vcpus 2 \
		--import --disk /var/lib/libvirt/images/$(IMAGE_NAME).qcow2 \
		--network network=default \
		--graphics spice \
		--os-variant rhel9.0 \
		--noautoconsole
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
	@echo "Removing VM $(IMAGE_NAME)..."
	@sudo virsh destroy $(IMAGE_NAME) 2>/dev/null || true
	@sudo virsh undefine $(IMAGE_NAME) 2>/dev/null || true
	@sudo rm -f /var/lib/libvirt/images/$(IMAGE_NAME).qcow2
	@echo "VM removed"

# Development targets
dev-build: ## Build with development settings
	$(MAKE) build CONFIG_FILE=config-example.json IMAGE_TAG=dev

dev-qcow2: ## Build development qcow2
	$(MAKE) qcow2 CONFIG_FILE=config-example.json IMAGE_TAG=dev

dev-deploy: ## Deploy development VM
	$(MAKE) deploy-vm CONFIG_FILE=config-example.json IMAGE_TAG=dev IMAGE_NAME=hass-dev

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
	@echo "Output Directory: $(OUTPUT_DIR)"
	@echo ""
	@echo "=== System Information ==="
	@echo "OS: $$(grep PRETTY_NAME /etc/os-release | cut -d'\"' -f2)"
	@echo "Kernel: $$(uname -r)"
	@echo "Architecture: $$(uname -m)"
	@echo "Podman Version: $$(podman --version)"
	@echo ""
	@echo "=== Available Space ==="
	@df -h . | tail -1