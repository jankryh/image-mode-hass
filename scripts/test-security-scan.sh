#!/bin/bash

# Test Security Scan Script
# This script helps test and debug security scanning functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="quay.io"
IMAGE_NAME="jankryh/fedora-bootc-hass"
SCAN_RESULTS_DIR="security-results"

# Functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if podman is available
    if ! command -v podman >/dev/null 2>&1; then
        log_error "Podman is not installed"
        exit 1
    fi
    log_success "Podman is available"
    
    # Check if trivy is available
    if ! command -v trivy >/dev/null 2>&1; then
        log_warning "Trivy is not installed - installing..."
        # Install trivy
        curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo gpg --dearmor -o /usr/share/keyrings/trivy-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/trivy-archive-keyring.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
        sudo apt-get update
        sudo apt-get install -y trivy
    fi
    log_success "Trivy is available"
    
    # Check if grype is available
    if ! command -v grype >/dev/null 2>&1; then
        log_warning "Grype is not installed - installing..."
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
    fi
    log_success "Grype is available"
}

# Test registry connectivity
test_registry() {
    log_info "Testing registry connectivity..."
    
    if curl -s --max-time 10 "https://${REGISTRY}/v2/" >/dev/null 2>&1; then
        log_success "Registry ${REGISTRY} is reachable"
    else
        log_error "Registry ${REGISTRY} is not reachable"
        return 1
    fi
}

# Check available images
check_images() {
    log_info "Checking available images..."
    
    echo "Available images:"
    podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}" || echo "No images found"
    echo ""
}

# Try to build image
build_image() {
    log_info "Attempting to build image..."
    
    if podman build \
        --tag "${REGISTRY}/${IMAGE_NAME}:latest" \
        --tag "security-scan-image:latest" \
        --label "org.opencontainers.image.created=$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --label "org.opencontainers.image.revision=$(git rev-parse HEAD 2>/dev/null || echo 'unknown')" \
        --label "security.scan=true" \
        .; then
        log_success "Image built successfully"
        return 0
    else
        log_warning "Image build failed"
        return 1
    fi
}

# Try to pull image from registry
pull_image() {
    log_info "Attempting to pull image from registry..."
    
    # Check if image exists in registry
    if podman manifest inspect "${REGISTRY}/${IMAGE_NAME}:latest" >/dev/null 2>&1; then
        log_success "Image found in registry"
        if podman pull "${REGISTRY}/${IMAGE_NAME}:latest"; then
            log_success "Image pulled successfully"
            return 0
        else
            log_error "Failed to pull image"
            return 1
        fi
    else
        log_warning "Image not found in registry"
        return 1
    fi
}

# Run security scan
run_security_scan() {
    local scan_image="$1"
    local scan_type="$2"
    
    log_info "Running security scan on: ${scan_image} (${scan_type})"
    
    # Create results directory
    mkdir -p "${SCAN_RESULTS_DIR}"
    
    # Run Trivy scan
    log_info "Running Trivy scan..."
    trivy image \
        --exit-code 0 \
        --format table \
        --output "${SCAN_RESULTS_DIR}/trivy-table.txt" \
        --severity HIGH,CRITICAL \
        --ignore-unfixed \
        "${scan_image}"
    
    # Run Grype scan
    log_info "Running Grype scan..."
    grype "${scan_image}" \
        -o table \
        --file "${SCAN_RESULTS_DIR}/grype-table.txt"
    
    log_success "Security scans completed"
}

# Main execution
main() {
    log_info "Starting security scan test..."
    
    # Check prerequisites
    check_prerequisites
    
    # Test registry connectivity
    test_registry
    
    # Check available images
    check_images
    
    # Try to build image
    if build_image; then
        SCAN_IMAGE="security-scan-image:latest"
        SCAN_TYPE="built-image"
        log_success "Using locally built image"
    elif pull_image; then
        SCAN_IMAGE="${REGISTRY}/${IMAGE_NAME}:latest"
        SCAN_TYPE="pulled-image"
        log_success "Using pulled image"
    else
        log_warning "No suitable image available, using fallback base image"
        SCAN_IMAGE="quay.io/fedora/fedora-bootc:42"
        SCAN_TYPE="fallback-base"
        
        if ! podman pull "${SCAN_IMAGE}"; then
            log_error "Failed to pull fallback image"
            exit 1
        fi
    fi
    
    # Run security scan
    run_security_scan "${SCAN_IMAGE}" "${SCAN_TYPE}"
    
    # Show results
    log_info "Scan results:"
    echo "Trivy results:"
    cat "${SCAN_RESULTS_DIR}/trivy-table.txt" 2>/dev/null || echo "No Trivy results"
    echo ""
    echo "Grype results:"
    cat "${SCAN_RESULTS_DIR}/grype-table.txt" 2>/dev/null || echo "No Grype results"
    
    log_success "Security scan test completed"
}

# Run main function
main "$@" 