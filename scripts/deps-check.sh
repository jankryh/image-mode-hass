#!/bin/bash
# Dependency Health Check and Security Audit System
# Comprehensive validation of package versions, security status, and compatibility

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$PROJECT_ROOT/dependencies"
VERSIONS_FILE="$DEPS_DIR/versions.json"
CHECK_LOG="$DEPS_DIR/health_check.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Exit codes
EXIT_SUCCESS=0
EXIT_WARNING=1
EXIT_CRITICAL=2
EXIT_ERROR=3

# Global counters
CHECKS_TOTAL=0
CHECKS_PASSED=0
CHECKS_WARNINGS=0
CHECKS_FAILED=0

# Logging functions
log() { echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$CHECK_LOG"; ((CHECKS_PASSED++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$CHECK_LOG"; ((CHECKS_WARNINGS++)); }
error() { echo -e "${RED}[FAIL]${NC} $1" | tee -a "$CHECK_LOG"; ((CHECKS_FAILED++)); }
info() { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$CHECK_LOG"; }

# Initialize check counters
check_start() {
    local check_name="$1"
    info "Starting check: $check_name"
    ((CHECKS_TOTAL++))
}

# Version comparison function
version_compare() {
    local version1="$1"
    local operator="$2"  
    local version2="$3"
    
    # Use dpkg for version comparison if available
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --compare-versions "$version1" "$operator" "$version2"
    else
        # Fallback to basic string comparison
        case "$operator" in
            "lt"|"<")
                [[ "$version1" < "$version2" ]]
                ;;
            "le"|"<=")
                [[ "$version1" <= "$version2" ]]
                ;;
            "eq"|"="|"==")
                [[ "$version1" == "$version2" ]]
                ;;
            "ge"|">=")
                [[ "$version1" >= "$version2" ]]
                ;;
            "gt"|">")
                [[ "$version1" > "$version2" ]]
                ;;
            *)
                return 1
                ;;
        esac
    fi
}

# Check if package is installed
check_package_installed() {
    local package="$1"
    local min_version="${2:-}"
    
    check_start "Package: $package"
    
    if command -v rpm >/dev/null 2>&1; then
        if ! rpm -q "$package" >/dev/null 2>&1; then
            error "Package $package is not installed"
            return 1
        fi
        
        if [[ -n "$min_version" ]]; then
            local current_version
            current_version=$(rpm -q --queryformat '%{VERSION}' "$package" 2>/dev/null)
            if ! version_compare "$current_version" ">=" "$min_version"; then
                error "Package $package version $current_version is below minimum $min_version"
                return 1
            fi
        fi
    elif command -v dpkg >/dev/null 2>&1; then
        if ! dpkg -l "$package" >/dev/null 2>&1; then
            error "Package $package is not installed"
            return 1
        fi
        
        if [[ -n "$min_version" ]]; then
            local current_version
            current_version=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null | cut -d: -f2 | cut -d- -f1)
            if ! version_compare "$current_version" ">=" "$min_version"; then
                error "Package $package version $current_version is below minimum $min_version"
                return 1
            fi
        fi
    else
        warn "No package manager found to check $package"
        return 1
    fi
    
    log "Package $package is properly installed"
    return 0
}

# Check Python package versions
check_python_packages() {
    info "Checking Python packages..."
    
    if ! command -v python3 >/dev/null 2>&1; then
        error "Python3 is not installed"
        return 1
    fi
    
    # Check urllib3 (critical security package)
    check_start "Python: urllib3"
    if python3 -c "import urllib3" >/dev/null 2>&1; then
        local urllib3_version
        urllib3_version=$(python3 -c "import urllib3; print(urllib3.__version__)" 2>/dev/null)
        local min_version="2.5.0"
        
        if version_compare "$urllib3_version" ">=" "$min_version"; then
            log "urllib3 version $urllib3_version meets security requirements"
        else
            error "urllib3 version $urllib3_version is vulnerable (minimum: $min_version)"
            return 1
        fi
    else
        error "urllib3 is not installed"
        return 1
    fi
    
    # Check for other critical Python packages
    local python_packages=("requests" "cryptography")
    for pkg in "${python_packages[@]}"; do
        check_start "Python: $pkg"
        if python3 -c "import $pkg" >/dev/null 2>&1; then
            local version
            version=$(python3 -c "import $pkg; print($pkg.__version__)" 2>/dev/null || echo "unknown")
            log "Python package $pkg version $version is available"
        else
            warn "Python package $pkg is not installed"
        fi
    done
}

# Check container images
check_container_images() {
    info "Checking container images..."
    
    if ! command -v podman >/dev/null 2>&1; then
        warn "Podman is not available for container checks"
        return 1
    fi
    
    # Check base images
    local base_images=("quay.io/fedora/fedora-bootc:42" "quay.io/centos-bootc/bootc-image-builder:latest")
    
    for image in "${base_images[@]}"; do
        check_start "Container: $image"
        if podman image exists "$image" 2>/dev/null; then
            # Check image age
            local created
            created=$(podman inspect "$image" --format '{{.Created}}' 2>/dev/null || echo "unknown")
            local age_days
            if [[ "$created" != "unknown" ]]; then
                age_days=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))
                if [[ $age_days -gt 30 ]]; then
                    warn "Container image $image is $age_days days old (consider updating)"
                else
                    log "Container image $image is up to date ($age_days days old)"
                fi
            else
                warn "Could not determine age of container image $image"
            fi
        else
            warn "Container image $image is not cached locally"
        fi
    done
}

# Check security status
check_security_status() {
    info "Performing security checks..."
    
    # Check for vulnerable packages that should be removed
    local vulnerable_packages=("toolbox" "golang" "buildah" "skopeo")
    
    for pkg in "${vulnerable_packages[@]}"; do
        check_start "Security: $pkg removal"
        if rpm -q "$pkg" >/dev/null 2>&1; then
            error "Vulnerable package $pkg is still installed (should be removed)"
        else
            log "Vulnerable package $pkg is properly removed"
        fi
    done
    
    # Check SSH configuration
    check_start "Security: SSH configuration"
    if [[ -f "/etc/ssh/sshd_config" ]]; then
        local ssh_issues=0
        
        # Check if root login is disabled
        if grep -q "PermitRootLogin no" /etc/ssh/sshd_config; then
            log "SSH root login is properly disabled"
        else
            error "SSH root login is not disabled"
            ((ssh_issues++))
        fi
        
        # Check if password authentication is disabled
        if grep -q "PasswordAuthentication no" /etc/ssh/sshd_config; then
            log "SSH password authentication is properly disabled"
        else
            error "SSH password authentication is not disabled"
            ((ssh_issues++))
        fi
        
        if [[ $ssh_issues -eq 0 ]]; then
            log "SSH security configuration is correct"
        fi
    else
        warn "SSH configuration file not found"
    fi
    
    # Check firewall status
    check_start "Security: Firewall"
    if systemctl is-enabled firewalld >/dev/null 2>&1; then
        if systemctl is-active firewalld >/dev/null 2>&1; then
            log "Firewall is enabled and active"
        else
            warn "Firewall is enabled but not active"
        fi
    else
        error "Firewall is not enabled"
    fi
    
    # Check fail2ban status
    check_start "Security: Fail2ban"
    if systemctl is-enabled fail2ban >/dev/null 2>&1; then
        if systemctl is-active fail2ban >/dev/null 2>&1; then
            log "Fail2ban is enabled and active"
        else
            warn "Fail2ban is enabled but not active"
        fi
    else
        warn "Fail2ban is not enabled"
    fi
}

# Check system services
check_system_services() {
    info "Checking system services..."
    
    local critical_services=("sshd" "chronyd")
    local optional_services=("fail2ban" "firewalld" "zerotier-one")
    
    for service in "${critical_services[@]}"; do
        check_start "Service: $service (critical)"
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            if systemctl is-active "$service" >/dev/null 2>&1; then
                log "Critical service $service is enabled and running"
            else
                error "Critical service $service is enabled but not running"
            fi
        else
            error "Critical service $service is not enabled"
        fi
    done
    
    for service in "${optional_services[@]}"; do
        check_start "Service: $service (optional)"
        if systemctl is-enabled "$service" >/dev/null 2>&1; then
            if systemctl is-active "$service" >/dev/null 2>&1; then
                log "Optional service $service is enabled and running"
            else
                warn "Optional service $service is enabled but not running"
            fi
        else
            info "Optional service $service is not enabled"
        fi
    done
}

# Check filesystem and storage
check_filesystem() {
    info "Checking filesystem and storage..."
    
    # Check disk space
    check_start "Storage: Disk space"
    local root_usage
    root_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $root_usage -lt 80 ]]; then
        log "Root filesystem usage is acceptable ($root_usage%)"
    elif [[ $root_usage -lt 90 ]]; then
        warn "Root filesystem usage is high ($root_usage%)"
    else
        error "Root filesystem usage is critical ($root_usage%)"
    fi
    
    # Check Home Assistant directories
    local ha_dirs=("/var/home-assistant/config" "/var/home-assistant/backups" "/var/log/home-assistant")
    
    for dir in "${ha_dirs[@]}"; do
        check_start "Directory: $dir"
        if [[ -d "$dir" ]]; then
            if [[ -r "$dir" && -w "$dir" ]]; then
                log "Directory $dir exists and is accessible"
            else
                error "Directory $dir exists but has permission issues"
            fi
        else
            error "Required directory $dir does not exist"
        fi
    done
}

# Generate summary report
generate_summary() {
    echo ""
    echo "=============================================="
    echo "           DEPENDENCY CHECK SUMMARY"
    echo "=============================================="
    echo ""
    
    echo "Total Checks: $CHECKS_TOTAL"
    echo -e "Passed: ${GREEN}$CHECKS_PASSED${NC}"
    echo -e "Warnings: ${YELLOW}$CHECKS_WARNINGS${NC}"
    echo -e "Failed: ${RED}$CHECKS_FAILED${NC}"
    echo ""
    
    # Determine overall status
    local exit_code=$EXIT_SUCCESS
    
    if [[ $CHECKS_FAILED -gt 0 ]]; then
        echo -e "Overall Status: ${RED}CRITICAL${NC}"
        echo "Action Required: Fix failed checks before deployment"
        exit_code=$EXIT_CRITICAL
    elif [[ $CHECKS_WARNINGS -gt 0 ]]; then
        echo -e "Overall Status: ${YELLOW}WARNING${NC}"
        echo "Action Recommended: Review warnings for potential issues"
        exit_code=$EXIT_WARNING
    else
        echo -e "Overall Status: ${GREEN}HEALTHY${NC}"
        echo "System is ready for deployment"
        exit_code=$EXIT_SUCCESS
    fi
    
    echo ""
    echo "Detailed log: $CHECK_LOG"
    
    return $exit_code
}

# Main execution
main() {
    echo "=============================================="
    echo "    Home Assistant bootc - Dependency Check"
    echo "=============================================="
    echo ""
    
    # Initialize log
    mkdir -p "$DEPS_DIR"
    echo "Dependency health check started at $(date)" > "$CHECK_LOG"
    
    # Parse command line arguments
    local verbose=false
    local security_only=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose=true
                shift
                ;;
            --security-only)
                security_only=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --verbose, -v      Enable verbose output"
                echo "  --security-only    Only run security checks"
                echo "  --help, -h         Show this help"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit $EXIT_ERROR
                ;;
        esac
    done
    
    # Run checks
    if [[ "$security_only" == "true" ]]; then
        check_security_status
    else
        # System packages
        if [[ -f "$VERSIONS_FILE" ]] && command -v jq >/dev/null 2>&1; then
            info "Using versions file for package validation"
            while IFS= read -r package; do
                local min_version
                min_version=$(jq -r ".system_packages.critical.\"$package\".min_version // empty" "$VERSIONS_FILE")
                check_package_installed "$package" "$min_version"
            done < <(jq -r '.system_packages.critical | keys[]' "$VERSIONS_FILE" 2>/dev/null)
        else
            info "No versions file found, using basic package checks"
            local basic_packages=("openssh-server" "fail2ban" "chrony" "git" "htop")
            for pkg in "${basic_packages[@]}"; do
                check_package_installed "$pkg"
            done
        fi
        
        # Other checks
        check_python_packages
        check_container_images
        check_security_status
        check_system_services
        check_filesystem
    fi
    
    # Generate summary and return appropriate exit code
    generate_summary
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi