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
	$(if $(filter true,$(USE_CACHE)),--cache-from=$(FULL_IMAGE_NAME)-cache,--no-cache) \
	$(if $(filter true,$(VERBOSE)),--progress=plain --log-level=debug,--progress=auto) \
	$(if $(filter true,$(PARALLEL_BUILD)),--jobs=$(shell nproc),) \
	--pull=always \
	--squash-all \
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
CACHE_REGISTRY ?= $(REGISTRY)/$(IMAGE_NAME)-cache
CACHE_TAG ?= latest

# Build targets with performance focus
.PHONY: help build build-optimized build-security build-parallel push clean qcow2 iso raw deploy-vm status
.PHONY: dev-build dev-qcow2 dev-deploy all vm clean-vm cache-push cache-pull
.PHONY: config-create config-show config-template validate-config info benchmark
.PHONY: deps-update deps-check deps-audit performance-test

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

# PERFORMANCE: Optimized build with advanced caching
build-optimized: cache-pull ## High-performance optimized build
	@echo "🚀 Building optimized $(FULL_IMAGE_NAME)..."
	@echo "💡 Using: $(BUILD_CPUS) CPUs, $(BUILD_MEMORY) memory"
	@echo "📦 Configuration: $(CONFIG_MK)"
	time sudo $(CONTAINER_CMD) build $(BUILD_FLAGS) \
		-f Containerfile.optimized \
		-t $(FULL_IMAGE_NAME) \
		-t $(FULL_IMAGE_NAME)-optimized \
		--cache-to=type=registry,ref=$(CACHE_REGISTRY):$(CACHE_TAG) \
		.
	@echo "✅ Optimized build completed: $(FULL_IMAGE_NAME)"
	$(MAKE) cache-push

# PERFORMANCE: Parallel build for development
build-parallel: ## Parallel build with maximum performance
	@echo "⚡ Parallel build with $(shell nproc) CPUs..."
	sudo $(CONTAINER_CMD) build \
		--jobs=$(shell nproc) \
		--memory=$(BUILD_MEMORY) \
		--cpus=$(BUILD_CPUS) \
		$(BUILD_FLAGS) \
		-f Containerfile.optimized \
		-t $(FULL_IMAGE_NAME) .

# PERFORMANCE: Standard build (fallback to original)
build: ## Standard build process
	@echo "Building $(FULL_IMAGE_NAME)..."
	@echo "Using configuration: $(CONFIG_MK)"
	sudo $(CONTAINER_CMD) build $(BUILD_FLAGS) -t $(FULL_IMAGE_NAME) .
	@echo "Build completed: $(FULL_IMAGE_NAME)"

# PERFORMANCE: Security build with optimizations
build-security: cache-pull ## Security-focused build with performance optimizations
	@echo "🛡️ Building secure optimized $(FULL_IMAGE_NAME)..."
	sudo $(CONTAINER_CMD) build \
		--no-cache --pull=always \
		--security-opt label=type:unconfined_t \
		-f Containerfile.optimized \
		-t $(FULL_IMAGE_NAME)-secure \
		--build-arg SECURITY_SCAN=true \
		.
	@echo "🔒 Security build completed"

# CACHE MANAGEMENT: Advanced caching strategies
cache-pull: ## Pull build cache from registry
	@echo "📥 Pulling build cache..."
	@sudo $(CONTAINER_CMD) pull $(CACHE_REGISTRY):$(CACHE_TAG) || echo "No cache available"

cache-push: ## Push build cache to registry  
	@echo "📤 Pushing build cache..."
	@sudo $(CONTAINER_CMD) tag $(FULL_IMAGE_NAME) $(CACHE_REGISTRY):$(CACHE_TAG) || true
	@sudo $(CONTAINER_CMD) push $(CACHE_REGISTRY):$(CACHE_TAG) || echo "Cache push failed"

cache-clean: ## Clean local build cache
	@echo "🧹 Cleaning build cache..."
	@sudo $(CONTAINER_CMD) system prune -f --volumes
	@sudo $(CONTAINER_CMD) rmi $(CACHE_REGISTRY):$(CACHE_TAG) 2>/dev/null || true

# PERFORMANCE: Optimized image creation with parallel processing
qcow2-optimized: build-optimized pull-deps ## Build optimized qcow2 with performance tuning
	@echo "💾 Building optimized qcow2 image..."
	@mkdir -p $(OUTPUT_DIR)
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
		--compress \
		$(FULL_IMAGE_NAME)
	@echo "✅ Optimized qcow2 created in $(OUTPUT_DIR)/"

# DEPENDENCY MANAGEMENT: Advanced dependency handling
deps-update: ## Update and optimize dependencies
	@echo "🔄 Updating dependencies..."
	@./scripts/deps-update.sh
	@echo "📦 Dependencies updated"

deps-check: ## Check dependency versions and security
	@echo "🔍 Checking dependencies..."
	@./scripts/deps-check.sh
	@echo "✅ Dependency check completed"

deps-audit: ## Security audit of dependencies
	@echo "🛡️ Auditing dependencies for security issues..."
	@./scripts/deps-audit.sh

# PERFORMANCE MONITORING
benchmark: build-optimized ## Benchmark build performance
	@echo "⏱️ Benchmarking build performance..."
	@time $(MAKE) clean && time $(MAKE) build-optimized
	@echo "📊 Benchmark completed"

performance-test: qcow2-optimized ## Test VM performance
	@echo "🏎️ Testing VM performance..."
	@./scripts/performance-test.sh $(OUTPUT_DIR)/qcow2/disk.qcow2

# OPTIMIZED DEPLOYMENT
deploy-vm-optimized: qcow2-optimized ## Deploy optimized VM with performance tuning
	@echo "🚀 Deploying optimized VM: $(VM_NAME)"
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
	@echo "✅ Optimized VM deployed successfully"

# COMPREHENSIVE STATUS
status-detailed: ## Show detailed build and performance status
	@echo "=== 📊 Performance Build Status ==="
	@echo "Image: $(FULL_IMAGE_NAME)"
	@echo "Cache: $(CACHE_REGISTRY):$(CACHE_TAG)"  
	@echo "Config: $(CONFIG_FILE)"
	@echo "Build Resources: $(BUILD_CPUS) CPUs, $(BUILD_MEMORY) memory"
	@echo ""
	@echo "=== 🖼️ Local Images ==="
	@sudo $(CONTAINER_CMD) images | grep $(IMAGE_NAME) || echo "No local images found"
	@echo ""
	@echo "=== 📈 Image Sizes ==="
	@sudo $(CONTAINER_CMD) images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep $(IMAGE_NAME) || true
	@echo ""
	@echo "=== 💾 Cache Status ==="
	@sudo $(CONTAINER_CMD) system df
	@echo ""
	@echo "=== 🖥️ VMs ==="
	@sudo virsh list --all | grep $(IMAGE_NAME) || echo "No VMs found"

# CLEANUP with optimization
clean-optimized: ## Comprehensive cleanup including cache
	@echo "🧹 Comprehensive cleanup..."
	@rm -rf $(OUTPUT_DIR)
	@sudo $(CONTAINER_CMD) rmi $(FULL_IMAGE_NAME) $(FULL_IMAGE_NAME)-optimized 2>/dev/null || true
	@sudo $(CONTAINER_CMD) rmi $(CACHE_REGISTRY):$(CACHE_TAG) 2>/dev/null || true
	@sudo $(CONTAINER_CMD) system prune -af --volumes
	@echo "✅ Cleanup completed"

# Default to optimized build
.DEFAULT_GOAL := build-optimized

# Keep original targets for backward compatibility
qcow2: build pull-deps ## Standard qcow2 build
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

# Include remaining original targets...
include $(MAKEFILE_LIST)