# Optimized Home Assistant bootc Image Makefile
# Performance-focused build system with parallel processing and advanced caching

# Include configuration file (can be overridden)
CONFIG_MK ?= config.mk
-include $(CONFIG_MK)

# PERFORMANCE: Enable BuildKit for better caching and parallelization
export DOCKER_BUILDKIT = 1
export BUILDAH_FORMAT = docker

# Computed variables with optimization flags
FULL_IMAGE_NAME = $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
CONTAINER_CMD = $(if $(filter true,$(USE_BUILDAH)),buildah,$(CONTAINER_RUNTIME))

# PERFORMANCE: Advanced build flags with caching and parallelization
BUILD_FLAGS = \
	$(if $(filter true,$(USE_CACHE)),,--no-cache) \
	$(if $(filter true,$(VERBOSE)),--progress=plain --log-level=debug,--progress=auto) \
	$(if $(filter true,$(PARALLEL_BUILD)),--jobs=$(shell nproc),) \
	--pull=always \
	$(BUILD_ARGS)

# PERFORMANCE: Optimized run flags with resource limits
RUN_FLAGS = \
	$(if $(filter true,$(VERBOSE)),-v,) \
	--memory=$(BUILD_MEMORY) \
	--cpus=$(BUILD_CPUS) \
	--security-opt label=type:unconfined_t \
	$(RUN_ARGS)

# Build optimization variables
BUILD_MEMORY ?= 4g
BUILD_CPUS ?= $(shell nproc)

# Build targets with performance focus
.PHONY: help build build-basic build-security build-parallel push clean qcow2 qcow2-basic iso raw deploy-vm deploy-vm-basic status status-detailed
.PHONY: dev-build dev-qcow2 dev-deploy all vm clean-vm clean-cache cache-push cache-pull cache-clean pull-deps
.PHONY: config-create config-show config-template validate-config info benchmark
.PHONY: deps-update deps-check performance-test test test-scripts test-integration version version-bump release
.PHONY: security-scan security-quick security-report security-monitor security-install
# Cross-platform targets
.PHONY: build-x86 build-arm64 iso-x86 iso-arm64 qcow2-x86 qcow2-arm64 show-arch

help: ## Show this help message with performance features
	@echo "Optimized Home Assistant bootc Build System"
	@echo ""
	@echo "Performance Features:"
	@echo "  - Multi-stage builds with aggressive caching"
	@echo "  - Parallel processing support"
	@echo "  - Layer optimization and squashing"
	@echo "  - Dependency management automation"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "📱 Cross-Platform Targets:"
	@echo "  show-arch           Show architecture information"
	@echo "  build-x86           Build x86_64 container image"
	@echo "  build-arm64         Build ARM64 container image"
	@echo "  iso-x86             Build x86_64 ISO installer"
	@echo "  iso-arm64           Build ARM64 ISO installer"
	@echo "  qcow2-x86           Build x86_64 qcow2 image"
	@echo "  qcow2-arm64         Build ARM64 qcow2 image"
	@echo "  raw-x86             Build x86_64 raw disk image for bare metal"
	@echo "  raw-arm64           Build ARM64 raw disk image for bare metal"

# High-performance build with advanced caching (now standard)
build: ## High-performance build with caching and optimization
	@echo "🚀 Building $(FULL_IMAGE_NAME)..."
	@echo "💡 Using: $(BUILD_CPUS) CPUs, $(BUILD_MEMORY) memory"
	@echo "📦 Configuration: $(CONFIG_MK)"
	@if [ -n "$(USE_ROOTLESS)" ]; then echo "🔓 Rootless mode detected"; fi
	time $(SUDO_CMD) $(CONTAINER_CMD) build $(BUILD_FLAGS) \
		-t $(FULL_IMAGE_NAME) \
		.
	@echo "✅ Build completed: $(FULL_IMAGE_NAME)"

# Parallel build for maximum performance
build-parallel: ## Parallel build with maximum performance
	@echo "⚡ Parallel build with $(shell nproc) CPUs..."
	sudo $(CONTAINER_CMD) build \
		--jobs=$(shell nproc) \
		--memory=$(BUILD_MEMORY) \
		--cpus=$(BUILD_CPUS) \
		$(BUILD_FLAGS) \
		-t $(FULL_IMAGE_NAME) .

# Basic build without optimizations (legacy)
build-basic: ## Basic build without advanced optimizations
	@echo "Building $(FULL_IMAGE_NAME) (basic mode)..."
	@echo "Using configuration: $(CONFIG_MK)"
	sudo $(CONTAINER_RUNTIME) build --no-cache -t $(FULL_IMAGE_NAME) .
	@echo "Build completed: $(FULL_IMAGE_NAME)"

# PERFORMANCE: Security build with optimizations
build-security: cache-pull ## Security-focused build with performance optimizations
	@echo "🛡️ Building secure optimized $(FULL_IMAGE_NAME)..."
	sudo $(CONTAINER_CMD) build \
		--no-cache --pull=always \
		--security-opt label=type:unconfined_t \
		-t $(FULL_IMAGE_NAME)-secure \
		--build-arg SECURITY_SCAN=true \
		.
	@echo "🔒 Security build completed"

push: build ## Build and push image to registry
	@echo "Pushing $(FULL_IMAGE_NAME) to registry..."
	$(SUDO_CMD) podman push $(FULL_IMAGE_NAME)
	@echo "Push completed"

# CACHE MANAGEMENT: Local build cache strategies  
cache-pull: ## Pull latest image for layer caching
	@echo "📥 Pulling latest image for cache..."
	@sudo $(CONTAINER_CMD) pull $(FULL_IMAGE_NAME) || echo "No existing image for cache"

cache-push: ## Push built image to registry (creates cache for others)
	@echo "📤 Pushing image to registry for cache sharing..."
	@sudo $(CONTAINER_CMD) push $(FULL_IMAGE_NAME) || echo "Push failed - check registry login"

cache-clean: ## Clean local build cache
	@echo "🧹 Cleaning local build cache..."
	@sudo $(CONTAINER_CMD) system prune -f --volumes
	@echo "✅ Cache cleaned"

pull-deps: ## Pull required base images
	@echo "Pulling dependencies..."
	podman pull quay.io/fedora/fedora-bootc:latest
	podman pull quay.io/centos-bootc/bootc-image-builder:latest

# High-performance qcow2 image creation (now standard)
qcow2: build pull-deps ## Build high-performance qcow2 with compression and tuning (requires rootful podman)
	@echo "💾 Building qcow2 image..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Using podman machine for ISO build"; \
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
	@echo "✅ qcow2 image created in $(OUTPUT_DIR)/"

# Basic qcow2 without performance optimizations (legacy)
qcow2-basic: build pull-deps ## Basic qcow2 build without optimizations (requires rootful podman)
	@echo "Building basic qcow2 image..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "⚠️  Failed to set rootful mode"; \
		podman machine start || echo "⚠️  Failed to start machine"; \
		sleep 3; \
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
			$(FULL_IMAGE_NAME); \
	else \
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
			$(FULL_IMAGE_NAME); \
	fi
	@echo "✅ Basic qcow2 image created in $(OUTPUT_DIR)/"

iso: build pull-deps ## Build ISO installer (requires rootful podman)
	@echo "Building ISO installer..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "⚠️  Failed to set rootful mode"; \
		podman machine start || echo "⚠️  Failed to start machine"; \
		sleep 3; \
		echo "🔄 Ensuring image is available in rootful context..."; \
		sudo podman pull $(FULL_IMAGE_NAME) 2>/dev/null || \
		echo "⚠️  Image not found in registry - trying local build"; \
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
			$(FULL_IMAGE_NAME); \
	else \
		echo "🔄 Ensuring image is available for bootc-image-builder..."; \
		sudo podman pull $(FULL_IMAGE_NAME) 2>/dev/null || \
		echo "⚠️  Image not found in registry - using local build"; \
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
			$(FULL_IMAGE_NAME); \
	fi
	@echo "✅ ISO installer created in $(OUTPUT_DIR)/"

raw: build pull-deps ## Build raw disk image (requires rootful podman)
	@echo "Building raw disk image..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "⚠️  Failed to set rootful mode"; \
		podman machine start || echo "⚠️  Failed to start machine"; \
		sleep 3; \
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
			$(FULL_IMAGE_NAME); \
	else \
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
			$(FULL_IMAGE_NAME); \
	fi
	@echo "✅ Raw disk image created in $(OUTPUT_DIR)/"

raw-x86: build-x86 pull-deps ## Build x86_64 raw disk image for bare metal
	@echo "🔧 Building x86_64 raw disk image for bare metal..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "⚠️  Failed to set rootful mode"; \
		podman machine start || echo "⚠️  Failed to start machine"; \
		sleep 3; \
		echo "🔄 Ensuring x86_64 image is available in rootful context..."; \
		sudo podman pull $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG) 2>/dev/null || \
		echo "⚠️  Image not found in registry - trying local build"; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type raw \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch x86_64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG); \
	else \
		echo "⚠️  On Linux: Make sure podman daemon is in rootful mode"; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type raw \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch x86_64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG); \
	fi
	@echo "✅ x86_64 raw disk image created in $(OUTPUT_DIR)/image/"
	@echo "📦 Image ready for bare metal deployment:"
	@echo "   Write to USB/SSD: sudo dd if=output/image/disk.raw of=/dev/sdX bs=1M status=progress"

raw-arm64: build-arm64 pull-deps ## Build ARM64 raw disk image for bare metal
	@echo "🔧 Building ARM64 raw disk image for bare metal..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "⚠️  Failed to set rootful mode"; \
		podman machine start || echo "⚠️  Failed to start machine"; \
		sleep 3; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type raw \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch aarch64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
	else \
		echo "⚠️  On Linux: Make sure podman daemon is in rootful mode"; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type raw \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch aarch64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
	fi
	@echo "✅ ARM64 raw disk image created in $(OUTPUT_DIR)/image/"
	@echo "📦 Image ready for bare metal deployment:"
	@echo "   Write to USB/SSD: sudo dd if=output/image/disk.raw of=/dev/sdX bs=1M status=progress"

# High-performance VM deployment (now standard)
deploy-vm: qcow2 ## Deploy high-performance VM with optimized settings
	@echo "🚀 Deploying VM: $(VM_NAME)"
	@echo "⚙️ Configuration: Memory=$(VM_MEMORY)MB, vCPUs=$(VM_VCPUS)"
	sudo mv $(OUTPUT_DIR)/qcow2/disk.qcow2 /var/lib/libvirt/images/$(VM_NAME).qcow2
	sudo virt-install \
		--name $(VM_NAME) \
		--memory $(VM_MEMORY) \
		--cpu host-passthrough,cache=passthrough \
		--vcpus $(VM_VCPUS),maxvcpus=$(VM_VCPUS) \
		--import --disk /var/lib/libvirt/images/$(VM_NAME).qcow2,bus=virtio,cache=writeback \
		--network network=$(VM_NETWORK),model=virtio \
		--graphics $(VM_GRAPHICS) \
		--os-variant $(VM_OS_VARIANT) \
		--features acpi=on,apic=on \
		--clock offset=utc \
		$(if $(filter none,$(VM_GRAPHICS)),--noautoconsole,)
	@echo "✅ VM deployed successfully"

# Basic VM deployment without performance optimizations (legacy)
deploy-vm-basic: qcow2-basic ## Deploy basic VM without performance tuning
	@echo "Deploying basic VM: $(VM_NAME)"
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
	@echo "Basic VM deployed successfully"

# DEPENDENCY MANAGEMENT: Advanced dependency handling
deps-update: ## Update and optimize dependencies
	@echo "🔄 Updating dependencies..."
	@./scripts/deps-update.sh
	@echo "📦 Dependencies updated"

deps-check: ## Check dependency versions and security
	@echo "🔍 Checking dependencies..."
	@./scripts/deps-check.sh
	@echo "✅ Dependency check completed"

# PERFORMANCE MONITORING
benchmark: build ## Benchmark build performance
	@echo "⏱️ Benchmarking build performance..."
	@time $(MAKE) clean && time $(MAKE) build
	@echo "📊 Benchmark completed"

performance-test: ## Run comprehensive performance tests
	@echo "🏎️ Running performance tests..."
	@./scripts/performance-test.sh --all

# STATUS REPORTING
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

status-detailed: ## Show detailed build and performance status
	@echo "=== 📊 Performance Build Status ==="
	@echo "Image: $(FULL_IMAGE_NAME)"
	@echo "Config: $(CONFIG_FILE)"
	@echo "Build Resources: $(BUILD_CPUS) CPUs, $(BUILD_MEMORY) memory"
	@echo ""
	@echo "=== 🖼️ Local Images ==="
	@sudo $(CONTAINER_CMD) images | grep $(IMAGE_NAME) || echo "No local images found"
	@echo ""
	@echo "=== 📈 Image Sizes ==="
	@sudo $(CONTAINER_CMD) images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep $(IMAGE_NAME) || true
	@echo ""
	@echo "=== 💾 System Storage ==="
	@sudo $(CONTAINER_CMD) system df
	@echo ""
	@echo "=== 🖥️ VMs ==="
	@sudo virsh list --all | grep $(IMAGE_NAME) || echo "No VMs found"

# CLEANUP
clean: ## Clean up build artifacts
	@echo "Cleaning up..."
	@rm -rf $(OUTPUT_DIR)
	@sudo podman rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	@sudo podman system prune -f
	@echo "Cleanup completed"

clean-cache: ## Comprehensive cleanup including cache
	@echo "🧹 Comprehensive cleanup..."
	@rm -rf $(OUTPUT_DIR)
	@sudo $(CONTAINER_CMD) rmi $(FULL_IMAGE_NAME) 2>/dev/null || true
	@sudo $(CONTAINER_CMD) system prune -af --volumes
	@echo "✅ Cleanup completed"

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
	@if command -v jq >/dev/null 2>&1; then \
		jq empty $(CONFIG_FILE) && echo "Configuration is valid JSON"; \
	else \
		echo "jq not available, skipping JSON validation"; \
	fi

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

test: ## Run all tests
	@echo "🧪 Running all tests..."
	@chmod +x tests/run-all-tests.sh
	@tests/run-all-tests.sh

test-scripts: ## Run script tests only
	@echo "🧪 Running script tests..."
	@chmod +x tests/run-all-tests.sh
	@tests/run-all-tests.sh --category scripts

test-integration: ## Run integration tests only
	@echo "🧪 Running integration tests..."
	@chmod +x tests/run-all-tests.sh
	@tests/run-all-tests.sh --category integration

version: ## Show current version
	@chmod +x scripts/version-manager.sh
	@scripts/version-manager.sh show

version-bump: ## Bump version (use VERSION_BUMP=major|minor|patch)
	@chmod +x scripts/version-manager.sh
	@scripts/version-manager.sh bump $(VERSION_BUMP)

release: ## Prepare release
	@chmod +x scripts/version-manager.sh
	@scripts/version-manager.sh release

#==================================================
# Security Targets
#==================================================

security-install: ## Install security scanning tools
	@echo "🔧 Installing security scanning tools..."
	@chmod +x scripts/security-check.sh
	@scripts/security-check.sh install-trivy

security-quick: ## Quick security vulnerability check
	@echo "🔍 Running quick security scan..."
	@chmod +x scripts/security-check.sh
	@scripts/security-check.sh quick --image $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

security-scan: ## Comprehensive security vulnerability scan
	@echo "🛡️  Running comprehensive security scan..."
	@chmod +x scripts/security-check.sh
	@scripts/security-check.sh scan --image $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) --fix-suggestions

security-report: ## Generate detailed security report
	@echo "📊 Generating security report..."
	@chmod +x scripts/security-check.sh
	@scripts/security-check.sh report --image $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

security-monitor: ## Set up continuous security monitoring
	@echo "🔔 Setting up security monitoring..."
	@chmod +x scripts/security-check.sh
	@scripts/security-check.sh monitor

# Enhanced security build with vulnerability fixes
build-secure: ## Build with enhanced security (removes vulnerable packages)
	@echo "🔒 Building secure image with vulnerability fixes..."
	@$(SUDO_CMD) $(CONTAINER_CMD) build \
		$(BUILD_ARGS) \
		--target security-hardened \
		--tag $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)-secure \
		--tag $(REGISTRY)/$(IMAGE_NAME):latest-secure \
		--label "org.opencontainers.image.created=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')" \
		--label "org.opencontainers.image.revision=$(shell git rev-parse HEAD)" \
		--label "org.opencontainers.image.version=$(IMAGE_TAG)-secure" \
		--label "bootc.security.hardened=true" \
		.
	@echo "✅ Secure image built: $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)-secure"

#==========================================
# Cross-Platform Architecture Support
#==========================================

show-arch: ## Show current and target architecture information
	@echo "Architecture Information:"
	@echo "  Host Architecture: $(shell uname -m)"
	@echo "  Target Architecture: $(TARGET_ARCH)"
	@echo "  Platform Suffix: $(PLATFORM_SUFFIX)"
	@echo "  Image Name: $(ARCH_IMAGE_NAME)"
	@echo "  Full Image Name: $(FULL_ARCH_IMAGE_NAME)"

build-x86: ## Build container image for x86_64 architecture
	@echo "🔧 Building x86_64 image: $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG)"
	sudo $(CONTAINER_RUNTIME) build \
		--platform linux/amd64 \
		$(BUILD_FLAGS) \
		--build-arg TIMEZONE=$(TIMEZONE) \
		-t $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG) \
		.
	@echo "✅ x86_64 build completed: $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG)"

build-arm64: ## Build container image for ARM64 architecture
	@echo "🔧 Building ARM64 image: $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"
	sudo $(CONTAINER_RUNTIME) build \
		--platform linux/arm64 \
		$(BUILD_FLAGS) \
		--build-arg TIMEZONE=$(TIMEZONE) \
		-t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) \
		.
	@echo "✅ ARM64 build completed: $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"

iso-x86: build-x86 pull-deps ## Build x86_64 ISO installer
	@echo "🔧 Building x86_64 ISO installer..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "⚠️  Failed to set rootful mode"; \
		podman machine start || echo "⚠️  Failed to start machine"; \
		sleep 3; \
		echo "🔄 Ensuring x86_64 image is available in rootful context..."; \
		sudo podman pull $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG) 2>/dev/null || \
		echo "⚠️  Image not found in registry - trying local build"; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type iso \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch x86_64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG); \
	else \
		echo "🔄 Ensuring x86_64 image is available for bootc-image-builder..."; \
		sudo podman pull $(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG) 2>/dev/null || \
		echo "⚠️  Image not found in registry - using local build"; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type iso \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch x86_64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG); \
	fi
	@echo "✅ x86_64 ISO installer created in $(OUTPUT_DIR)/"

iso-arm64: build-arm64 pull-deps ## Build ARM64 ISO installer  
	@echo "🔧 Building ARM64 ISO installer..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@echo "Using configuration file: $(CONFIG_FILE)"
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Configuring podman machine for rootful mode"; \
		podman machine stop 2>/dev/null || true; \
		podman machine set --rootful || echo "⚠️  Failed to set rootful mode"; \
		podman machine start || echo "⚠️  Failed to start machine"; \
		sleep 3; \
		echo "🔄 Ensuring ARM64 image is available in rootful context..."; \
		sudo podman pull $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || \
		echo "⚠️  Image not found in registry - trying local build"; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type iso \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch aarch64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
	else \
		echo "🔄 Ensuring ARM64 image is available for bootc-image-builder..."; \
		sudo podman pull $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || \
		echo "⚠️  Image not found in registry - using local build"; \
		sudo podman run \
			--rm -it --privileged --pull=newer \
			--security-opt label=type:unconfined_t \
			-v /var/lib/containers/storage:/var/lib/containers/storage \
			-v ./$(CONFIG_FILE):/config.toml:ro \
			-v $(OUTPUT_DIR):/output \
			quay.io/centos-bootc/bootc-image-builder:latest \
			--type iso \
			--rootfs $(ROOTFS_TYPE) \
			--target-arch aarch64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
	fi
	@echo "✅ ARM64 ISO installer created in $(OUTPUT_DIR)/"

qcow2-x86: build-x86 pull-deps ## Build x86_64 qcow2 image
	@echo "🔧 Building x86_64 qcow2 image..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Using podman machine for qcow2 build"; \
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
			--target-arch x86_64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG); \
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
			--target-arch x86_64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME)-x86:$(IMAGE_TAG); \
	fi
	@echo "✅ x86_64 qcow2 image created in $(OUTPUT_DIR)/"

qcow2-arm64: build-arm64 pull-deps ## Build ARM64 qcow2 image
	@echo "🔧 Building ARM64 qcow2 image..."
	@echo "⚠️  Note: bootc-image-builder requires rootful podman daemon"
	@mkdir -p $(OUTPUT_DIR)
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "📍 On macOS: Using podman machine for qcow2 build"; \
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
			--target-arch aarch64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
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
			--target-arch aarch64 \
			--config /config.toml \
			$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG); \
	fi
	@echo "✅ ARM64 qcow2 image created in $(OUTPUT_DIR)/"

# Default to high-performance build
.DEFAULT_GOAL := build