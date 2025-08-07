# Home Assistant bootc Configuration (Default)
# Essential settings for building and deploying Home Assistant bootc images

#==========================================
# Basic Configuration
#==========================================

# Container image name
IMAGE_NAME ?= fedora-bootc-hass

# Container registry
REGISTRY ?= quay.io/rh-ee-jkryhut

# Image tag
IMAGE_TAG ?= latest

# Configuration file for bootc image builder
CONFIG_FILE ?= config-production.toml

# Output directory
OUTPUT_DIR ?= ./output

# Container runtime
CONTAINER_RUNTIME ?= podman

# Sudo command
SUDO_CMD ?= sudo

#==========================================
# Build Configuration
#==========================================

# Root filesystem type
ROOTFS_TYPE ?= ext4

# Timezone
TIMEZONE ?= Europe/Prague

# Build optimization
USE_CACHE ?= true
VERBOSE ?= false

# Build resources
BUILD_MEMORY ?= 4g
BUILD_CPUS ?= $(shell nproc)

#==========================================
# VM Configuration
#==========================================

# VM settings
VM_NAME ?= home-assistant-bootc
VM_MEMORY ?= 4096
VM_VCPUS ?= 2
VM_NETWORK ?= default
VM_GRAPHICS ?= spice
VM_OS_VARIANT ?= rhel9.0

#==========================================
# Override Examples
#==========================================

# For Docker Hub:
# REGISTRY = docker.io/yourusername

# For GitHub Container Registry:
# REGISTRY = ghcr.io/yourusername

# For production:
# VM_MEMORY = 8192
# VM_VCPUS = 4
