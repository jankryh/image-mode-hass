# Home Assistant bootc Configuration
# Copy this file and customize for your environment
# Usage: make build (uses defaults) or CONFIG_FILE=my-config.mk make build

#==========================================
# Container Image Configuration
#==========================================

# Container image name (without registry/tag)
IMAGE_NAME ?= fedora-bootc-hass

# Container registry (quay.io, docker.io, your-registry.com)
REGISTRY ?= quay.io/rh-ee-jkryhut

# Image tag/version
IMAGE_TAG ?= latest

# Alternative registries examples:
# REGISTRY = docker.io/myusername
# REGISTRY = localhost:5000
# REGISTRY = ghcr.io/myuser

#==========================================
# Build Configuration
#==========================================

# Configuration file for bootc image builder
CONFIG_FILE ?= config-production.json

# Output directory for generated images
OUTPUT_DIR ?= ./output

# Container runtime (podman or docker)
CONTAINER_RUNTIME ?= podman

# Enable buildah for faster builds (if available)
USE_BUILDAH ?= false

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
# Development Configuration
#==========================================

# Development image tag
DEV_TAG ?= dev

# Development config file
DEV_CONFIG ?= config-example.json

# Development VM name
DEV_VM_NAME ?= hass-dev

# Enable debug output
DEBUG ?= false

#==========================================
# Deployment Configuration
#==========================================

# SSH user for remote deployment
SSH_USER ?= root

# SSH host for remote deployment
SSH_HOST ?= 

# SSH key file for authentication
SSH_KEY ?= ~/.ssh/id_rsa

# Remote deployment directory
REMOTE_DIR ?= /tmp/hass-deployment

#==========================================
# Build Options
#==========================================

# Enable parallel builds
PARALLEL_BUILD ?= true

# Build cache directory
BUILD_CACHE ?= ./.buildcache

# Enable build cache
USE_CACHE ?= true

# Force rebuild (ignore cache)
FORCE_REBUILD ?= false

# Enable verbose output
VERBOSE ?= false

#==========================================
# Testing Configuration
#==========================================

# Enable health checks after deployment
ENABLE_HEALTH_CHECK ?= true

# Health check timeout in seconds
HEALTH_CHECK_TIMEOUT ?= 300

# Test configuration file
TEST_CONFIG ?= config-test.json

#==========================================
# Advanced Options
#==========================================

# Custom build arguments
BUILD_ARGS ?=

# Additional podman/docker run arguments
RUN_ARGS ?=

# Custom systemd service enable list
ENABLE_SERVICES ?= sshd chronyd fail2ban firewalld

# Timezone for container
TIMEZONE ?= Europe/Prague

# Locale setting
LOCALE ?= en_US.UTF-8

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
# CONFIG_FILE = config-production.json
# VM_MEMORY = 8192
# VM_VCPUS = 4

# For development:
# CONFIG_FILE = config-example.json
# IMAGE_TAG = dev
# DEBUG = true
# VERBOSE = true