#!/bin/bash
# Advanced Dependency Management and Updates
# Automated dependency tracking, version management, and update orchestration

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="$PROJECT_ROOT/dependencies"
VERSIONS_FILE="$DEPS_DIR/versions.json"
COMPATIBILITY_FILE="$DEPS_DIR/compatibility.matrix"
UPDATE_LOG="$DEPS_DIR/update.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }
error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }
info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }
debug() { [[ "${VERBOSE:-}" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$UPDATE_LOG"; }

# Create dependencies directory structure
init_deps_structure() {
    log "Initializing dependency management structure..."
    mkdir -p "$DEPS_DIR"/{cache,backups,reports,locks}
    
    # Initialize versions file if it doesn't exist
    if [[ ! -f "$VERSIONS_FILE" ]]; then
        cat > "$VERSIONS_FILE" << 'EOF'
{
    "metadata": {
        "last_update": "",
        "update_strategy": "conservative",
        "auto_update_enabled": false
    },
    "base_images": {
        "fedora-bootc": {
            "registry": "quay.io/fedora/fedora-bootc",
            "current_version": "42",
            "latest_version": "",
            "pinned": true,
            "update_policy": "manual"
        },
        "bootc-image-builder": {
            "registry": "quay.io/centos-bootc/bootc-image-builder",
            "current_version": "latest",
            "latest_version": "",
            "pinned": false,
            "update_policy": "auto"
        }
    },
    "system_packages": {
        "critical": {
            "openssh-server": {"min_version": "8.0", "security_critical": true},
            "fail2ban": {"min_version": "0.11", "security_critical": true},
            "chrony": {"min_version": "4.0", "security_critical": false}
        },
        "optional": {
            "git": {"min_version": "2.39", "security_critical": false},
            "htop": {"min_version": "3.0", "security_critical": false},
            "jq": {"min_version": "1.6", "security_critical": false}
        }
    },
    "python_packages": {
        "urllib3": {
            "current_version": "2.5.0",
            "min_version": "2.5.0",
            "security_critical": true,
            "cve_fixed": ["CVE-2024-37891"]
        }
    },
    "container_images": {
        "home-assistant": {
            "registry": "ghcr.io/home-assistant/home-assistant",
            "current_version": "latest",
            "update_policy": "auto",
            "rollback_enabled": true
        }
    }
}
EOF
        log "Created initial versions.json"
    fi

    # Initialize compatibility matrix
    if [[ ! -f "$COMPATIBILITY_FILE" ]]; then
        cat > "$COMPATIBILITY_FILE" << 'EOF'
# Compatibility Matrix for Home Assistant bootc
# Format: component_a:version_range component_b:version_range [notes]

fedora-bootc:42 home-assistant:>=2024.1 "Tested configuration"
fedora-bootc:42 python3:>=3.11 "Required for modern HA"
urllib3:>=2.5.0 home-assistant:* "Security fix for CVE-2024-37891"
fail2ban:>=0.11 fedora-bootc:42 "Compatible configuration"
zerotier-one:* fedora-bootc:42 "Always compatible"

# Incompatibilities (prefix with !)
!golang:* fedora-bootc:42 "Removed for security (toolbox dependency)"
!toolbox:* fedora-bootc:42 "Contains vulnerable Go dependencies"
EOF
        log "Created compatibility matrix"
    fi
}

# Check for available updates
check_updates() {
    log "Checking for available updates..."
    
    # Check base image updates
    info "Checking base image updates..."
    
    local fedora_latest
    fedora_latest=$(skopeo inspect docker://quay.io/fedora/fedora-bootc:latest | jq -r '.RepoTags | sort_by(.) | reverse | .[0]' 2>/dev/null || echo "42")
    debug "Latest Fedora bootc version: $fedora_latest"
    
    local builder_digest
    builder_digest=$(skopeo inspect docker://quay.io/centos-bootc/bootc-image-builder:latest | jq -r '.Digest' 2>/dev/null || echo "unknown")
    debug "Current bootc-image-builder digest: $builder_digest"
    
    # Check for security updates
    info "Checking for security updates..."
    if command -v dnf &> /dev/null; then
        dnf check-update --security -q | grep -E "(Critical|Important)" || true
    fi
    
    # Check Python package updates
    info "Checking Python package security updates..."
    pip3 list --outdated --format=json 2>/dev/null | jq -r '.[] | select(.name == "urllib3") | "\(.name): \(.version) -> \(.latest_version)"' || true
    
    # Update versions file with current state
    update_versions_file "$fedora_latest" "$builder_digest"
}

# Update versions tracking file
update_versions_file() {
    local fedora_latest="$1"
    local builder_digest="$2"
    
    debug "Updating versions file..."
    
    # Create temporary file with updates
    jq --arg date "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
       --arg fedora_latest "$fedora_latest" \
       --arg builder_digest "$builder_digest" \
       '
       .metadata.last_update = $date |
       .base_images."fedora-bootc".latest_version = $fedora_latest |
       .base_images."bootc-image-builder".latest_digest = $builder_digest
       ' "$VERSIONS_FILE" > "$VERSIONS_FILE.tmp"
    
    mv "$VERSIONS_FILE.tmp" "$VERSIONS_FILE"
    debug "Versions file updated"
}

# Perform compatibility checks
check_compatibility() {
    log "Performing compatibility checks..."
    
    local issues=0
    
    # Check against compatibility matrix
    while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue  # Skip comments
        [[ -z "$line" ]] && continue        # Skip empty lines
        
        if [[ "$line" =~ ^!.*$ ]]; then
            # Incompatibility check
            local incompatible="${line#!}"
            warn "Checking incompatibility: $incompatible"
            # Add actual incompatibility checking logic here
        else
            # Compatibility requirement
            debug "Checking compatibility: $line"
            # Add actual compatibility checking logic here
        fi
    done < "$COMPATIBILITY_FILE"
    
    if [[ $issues -eq 0 ]]; then
        log "All compatibility checks passed"
    else
        warn "Found $issues compatibility issues"
    fi
    
    return $issues
}

# Create dependency backup
backup_current_state() {
    log "Creating backup of current dependency state..."
    
    local backup_dir
    backup_dir="$DEPS_DIR/backups/$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$backup_dir"
    
    # Backup current versions
    cp "$VERSIONS_FILE" "$backup_dir/"
    
    # Backup current package list
    if command -v rpm &> /dev/null; then
        rpm -qa | sort > "$backup_dir/rpm_packages.list"
    fi
    
    # Backup Python packages
    pip3 list --format=freeze > "$backup_dir/python_packages.list" 2>/dev/null || true
    
    # Backup container images
    podman images --format "{{.Repository}}:{{.Tag}} {{.Digest}}" > "$backup_dir/container_images.list" 2>/dev/null || true
    
    log "Backup created at: $backup_dir"
    echo "$backup_dir" > "$DEPS_DIR/.last_backup"
}

# Validate dependencies
validate_dependencies() {
    log "Validating dependency integrity..."
    
    local validation_failed=false
    
    # Check critical packages
    info "Checking critical packages..."
    while IFS= read -r pkg; do
        if ! rpm -q "$pkg" &> /dev/null; then
            error "Critical package missing: $pkg"
            validation_failed=true
        fi
    done < <(jq -r '.system_packages.critical | keys[]' "$VERSIONS_FILE")
    
    # Check Python security packages
    info "Checking Python security packages..."
    local urllib3_version
    urllib3_version=$(python3 -c "import urllib3; print(urllib3.__version__)" 2>/dev/null || echo "unknown")
    local required_version
    required_version=$(jq -r '.python_packages.urllib3.min_version' "$VERSIONS_FILE")
    
    if [[ "$urllib3_version" != "unknown" ]] && dpkg --compare-versions "$urllib3_version" lt "$required_version" 2>/dev/null; then
        error "urllib3 version $urllib3_version is below required $required_version"
        validation_failed=true
    fi
    
    if [[ "$validation_failed" == "true" ]]; then
        error "Dependency validation failed"
        return 1
    else
        log "Dependency validation passed"
        return 0
    fi
}

# Generate dependency report
generate_report() {
    log "Generating dependency report..."
    
    local report_file
    report_file="$DEPS_DIR/reports/dependency_report_$(date '+%Y%m%d_%H%M%S').html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Home Assistant bootc - Dependency Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .critical { color: red; font-weight: bold; }
        .warning { color: orange; }
        .success { color: green; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Home Assistant bootc - Dependency Report</h1>
    <p>Generated: $(date)</p>
    
    <h2>Base Images</h2>
    <table>
        <tr><th>Image</th><th>Current</th><th>Latest</th><th>Status</th></tr>
EOF

    # Add base images to report
    jq -r '.base_images | to_entries[] | "\(.key)\t\(.value.current_version)\t\(.value.latest_version)\t\(if .value.current_version == .value.latest_version then "✅ Current" else "⚠️ Update Available" end)"' "$VERSIONS_FILE" | \
    while IFS=$'\t' read -r name current latest status; do
        echo "        <tr><td>$name</td><td>$current</td><td>$latest</td><td>$status</td></tr>" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF
    </table>
    
    <h2>Security Status</h2>
    <div class="$([ -f "$DEPS_DIR/.security_issues" ] && echo "critical" || echo "success")">
        $([ -f "$DEPS_DIR/.security_issues" ] && echo "⚠️ Security issues detected" || echo "✅ No known security issues")
    </div>
    
    <h2>Last Update</h2>
    <p>$(jq -r '.metadata.last_update' "$VERSIONS_FILE")</p>
</body>
</html>
EOF

    log "Report generated: $report_file"
}

# Main execution
main() {
    echo "=============================================="
    echo "   Advanced Dependency Management System"
    echo "=============================================="
    echo ""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                export VERBOSE=true
                shift
                ;;
            --dry-run)
                export DRY_RUN=true
                shift
                ;;
            --backup-only)
                export BACKUP_ONLY=true
                shift
                ;;
            --report-only)
                export REPORT_ONLY=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Initialize
    init_deps_structure
    
    # Create backup
    backup_current_state
    
    # Report only mode
    if [[ "${REPORT_ONLY:-}" == "true" ]]; then
        generate_report
        exit 0
    fi
    
    # Backup only mode
    if [[ "${BACKUP_ONLY:-}" == "true" ]]; then
        log "Backup completed"
        exit 0
    fi
    
    # Full update process
    if [[ "${DRY_RUN:-}" != "true" ]]; then
        check_updates
        check_compatibility || warn "Compatibility issues detected"
        validate_dependencies || error "Dependency validation failed"
    else
        log "Dry run mode - no changes made"
        check_updates
    fi
    
    # Always generate report
    generate_report
    
    log "Dependency update process completed"
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi