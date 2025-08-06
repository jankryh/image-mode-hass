# Home Assistant bootc Configuration
# Copy this file and customize for your environment

#==========================================
# Container Image Configuration
#==========================================

# Container image name (without registry/tag)
IMAGE_NAME ?= fedora-bootc-hass

# Container registry
REGISTRY ?= quay.io/rh-ee-jkryhut

# Image tag/version
IMAGE_TAG ?= latest

#==========================================
# Build Configuration
#==========================================

# Configuration file for bootc image builder
CONFIG_FILE ?= config-production.toml

# Output directory for generated images
OUTPUT_DIR ?= ./output

# Container runtime (podman or docker)
CONTAINER_RUNTIME ?= podman

# Enable buildah for faster builds (if available)
USE_BUILDAH ?= false

# Rootless mode detection
ROOTLESS_MODE ?= auto

# Podman socket location
PODMAN_SOCKET ?= $(XDG_RUNTIME_DIR)/podman/podman.sock

# Sudo command (empty for rootless)
SUDO_CMD ?= sudo

# Auto-detect rootless mode
ifeq ($(ROOTLESS_MODE),auto)
    ifneq ($(wildcard $(PODMAN_SOCKET)),)
        USE_ROOTLESS = true
        SUDO_CMD =
    endif
endif

# Root filesystem type for disk images
ROOTFS_TYPE ?= ext4

# Target architecture for builds
TARGET_ARCH ?= auto

# Auto-detect architecture if not specified
ifeq ($(TARGET_ARCH),auto)
    DETECTED_ARCH := $(shell uname -m)
    ifeq ($(DETECTED_ARCH),arm64)
        TARGET_ARCH = arm64
        PLATFORM_SUFFIX = 
    else ifeq ($(DETECTED_ARCH),x86_64)
        TARGET_ARCH = amd64
        PLATFORM_SUFFIX = 
    else
        TARGET_ARCH = amd64
        PLATFORM_SUFFIX = 
    endif
else ifeq ($(TARGET_ARCH),arm64)
    PLATFORM_SUFFIX = 
else ifeq ($(TARGET_ARCH),amd64)
    PLATFORM_SUFFIX = -x86
else
    PLATFORM_SUFFIX = -x86
endif

# Full image name with architecture suffix
ARCH_IMAGE_NAME = $(IMAGE_NAME)$(PLATFORM_SUFFIX)
FULL_ARCH_IMAGE_NAME = $(REGISTRY)/$(ARCH_IMAGE_NAME):$(IMAGE_TAG)

#==========================================
# Virtual Machine Configuration
#==========================================

# VM name for libvirt deployment
VM_NAME ?= home-assistant-bootc

# VM memory in MB
VM_MEMORY ?= 4096

# Number of CPU cores
VM_VCPUS ?= 2

# VM network (default, host, bridge name)
VM_NETWORK ?= default

# VM graphics (spice, vnc, none)
VM_GRAPHICS ?= spice

# OS variant for virt-install
VM_OS_VARIANT ?= rhel9.0

#==========================================
# Build Options
#==========================================

# Enable build cache
USE_CACHE ?= true

# Enable verbose output
VERBOSE ?= false

# Build arguments for customization
BUILD_ARGS += --build-arg TIMEZONE=$(TIMEZONE)

# Additional podman/docker run arguments
RUN_ARGS ?=

# Timezone for container
TIMEZONE ?= Europe/Prague

#==========================================
# Override Examples
#==========================================
# Uncomment and modify as needed:

# For Docker Hub:
# REGISTRY = docker.io/yourusername

# For GitHub Container Registry:
# REGISTRY = ghcr.io/yourusername

# For local testing:
# REGISTRY = localhost:5000
# IMAGE_TAG = test

# For production:
# CONFIG_FILE = config-production.toml
# VM_MEMORY = 8192
# VM_VCPUS = 4