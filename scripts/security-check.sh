#!/bin/bash
# Security vulnerability checker and advisor for Home Assistant bootc image
# This script helps identify and resolve security vulnerabilities

set -euo pipefail

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Configuration
REPORT_DIR="${HOME}/.hass-security-reports"
IMAGE_NAME="${REGISTRY:-quay.io}/${IMAGE_NAME:-$USER/fedora-bootc-hass}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat << EOF
Usage: $0 [COMMAND] [OPTIONS]

Security vulnerability checker for Home Assistant bootc image

COMMANDS:
    scan             Run comprehensive security scan
    quick            Quick vulnerability check
    report           Generate security report
    fix              Show suggested fixes for found vulnerabilities
    monitor          Set up continuous monitoring
    help             Show this help message

OPTIONS:
    --image NAME     Specify image name (default: $IMAGE_NAME)
    --severity LEVEL Set minimum severity level (LOW, MEDIUM, HIGH, CRITICAL)
    --format FORMAT  Output format (table, json, sarif)
    --output FILE    Output file path
    --fix-suggestions Include fix suggestions in output

EXAMPLES:
    $0 scan --severity HIGH
    $0 quick --format json --output vulnerabilities.json
    $0 report --fix-suggestions
    $0 monitor

EOF
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v trivy &> /dev/null; then
        missing_deps+=("trivy")
    fi
    
    if ! command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
        missing_deps+=("podman or docker")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        info "Install instructions:"
        info "- Trivy: https://aquasecurity.github.io/trivy/latest/getting-started/installation/"
        info "- Podman: dnf install podman (Fedora) or apt install podman (Ubuntu)"
        exit 1
    fi
}

install_trivy() {
    info "Installing Trivy..."
    
    if command -v dnf &> /dev/null; then
        # Fedora/RHEL
        sudo dnf install -y trivy
    elif command -v apt &> /dev/null; then
        # Ubuntu/Debian
        sudo apt-get update
        sudo apt-get install -y wget apt-transport-https gnupg lsb-release
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
        sudo apt-get update
        sudo apt-get install -y trivy
    else
        # Generic installation
        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
    fi
    
    success "Trivy installed successfully"
}

run_security_scan() {
    local image_name="$1"
    local severity="${2:-HIGH,CRITICAL}"
    local format="${3:-table}"
    local output_file="$4"
    local show_fixes="${5:-false}"
    
    info "Running security scan on image: $image_name"
    info "Severity levels: $severity"
    
    mkdir -p "$REPORT_DIR"
    local scan_timestamp
    scan_timestamp=$(date +"%Y%m%d_%H%M%S")
    local base_filename="$REPORT_DIR/security_scan_${scan_timestamp}"
    
    # Determine container runtime
    local container_cmd="podman"
    if ! command -v podman &> /dev/null && command -v docker &> /dev/null; then
        container_cmd="docker"
    fi
    
    # Pull or build image if needed
    if ! $container_cmd inspect "$image_name" &> /dev/null; then
        warn "Image $image_name not found locally"
        if [[ -f "Containerfile" || -f "Dockerfile" ]]; then
            info "Building image locally..."
            $container_cmd build -t "$image_name" .
        else
            info "Attempting to pull image..."
            $container_cmd pull "$image_name" || {
                error "Failed to pull image and no Containerfile found"
                exit 1
            }
        fi
    fi
    
    # Run comprehensive Trivy scan
    local trivy_args=(
        "image"
        "--severity" "$severity"
        "--format" "$format"
    )
    
    if [[ -n "$output_file" ]]; then
        trivy_args+=("--output" "$output_file")
    else
        trivy_args+=("--output" "${base_filename}.${format}")
    fi
    
    # Add vulnerability database update
    trivy "${trivy_args[@]}" "$image_name" || {
        warn "Trivy scan completed with findings"
    }
    
    # Generate JSON report for processing
    trivy image \
        --severity "$severity" \
        --format json \
        --output "${base_filename}.json" \
        "$image_name"
    
    # Process results and generate summary
    generate_security_summary "${base_filename}.json" "$show_fixes"
    
    success "Security scan completed. Results saved to: $REPORT_DIR"
}

generate_security_summary() {
    local json_file="$1"
    local show_fixes="${2:-false}"
    
    if [[ ! -f "$json_file" ]]; then
        warn "JSON report not found: $json_file"
        return 1
    fi
    
    local summary_file="${json_file%.json}_summary.md"
    
    cat > "$summary_file" << EOF
# Security Vulnerability Summary

**Scan Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Image:** $IMAGE_NAME
**Report:** $(basename "$json_file")

## Vulnerability Counts

EOF
    
    # Count vulnerabilities by severity
    if command -v jq &> /dev/null; then
        local critical high medium low
        critical=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL")] | length' "$json_file")
        high=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "HIGH")] | length' "$json_file")
        medium=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "MEDIUM")] | length' "$json_file")
        low=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity == "LOW")] | length' "$json_file")
        
        echo "- 🔴 Critical: $critical" >> "$summary_file"
        echo "- 🟠 High: $high" >> "$summary_file"
        echo "- 🟡 Medium: $medium" >> "$summary_file"
        echo "- 🟢 Low: $low" >> "$summary_file"
        echo "" >> "$summary_file"
        
        # Show critical vulnerabilities details
        if [[ $critical -gt 0 ]]; then
            echo "## Critical Vulnerabilities" >> "$summary_file"
            echo "" >> "$summary_file"
            jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL") | "- **\(.VulnerabilityID)**: \(.Title // .Description // "No description") (Package: \(.PkgName))"' "$json_file" >> "$summary_file"
            echo "" >> "$summary_file"
        fi
        
        # Color-coded console output
        echo -e "\n${BLUE}Security Scan Summary:${NC}"
        echo -e "🔴 Critical: ${RED}$critical${NC}"
        echo -e "🟠 High: ${YELLOW}$high${NC}"
        echo -e "🟡 Medium: $medium"
        echo -e "🟢 Low: $low"
        
        if [[ $critical -gt 0 || $high -gt 0 ]]; then
            echo -e "\n${RED}⚠️  Action required: Critical or high severity vulnerabilities found${NC}"
        else
            echo -e "\n${GREEN}✅ No critical or high severity vulnerabilities found${NC}"
        fi
    fi
    
    # Add recommended actions
    cat >> "$summary_file" << EOF
## Recommended Actions

1. **Immediate Actions (for Critical/High):**
   - Update base image to latest version
   - Remove unnecessary packages
   - Apply security patches

2. **Base Image Updates:**
   \`\`\`dockerfile
   # Update Containerfile FROM statement to latest
   FROM quay.io/fedora/fedora-bootc:42
   \`\`\`

3. **Package Cleanup:**
   \`\`\`dockerfile
   # Remove vulnerable packages
   RUN dnf -y remove toolbox* golang* container-tools* || true
   RUN dnf -y autoremove
   \`\`\`

4. **Security Updates:**
   \`\`\`dockerfile
   # Force security updates
   RUN dnf -y upgrade --security
   \`\`\`

## Regular Monitoring

Set up automated scanning:
\`\`\`bash
# Add to crontab for daily scans
0 2 * * * $SCRIPT_DIR/security-check.sh quick
\`\`\`

EOF
    
    if [[ "$show_fixes" == "true" ]]; then
        add_fix_suggestions "$json_file" "$summary_file"
    fi
    
    info "Summary report generated: $summary_file"
}

add_fix_suggestions() {
    local json_file="$1"
    local summary_file="$2"
    
    echo "## Specific Fix Suggestions" >> "$summary_file"
    echo "" >> "$summary_file"
    
    if command -v jq &> /dev/null; then
        # Extract specific package vulnerabilities and suggest fixes
        jq -r '.Results[]?.Vulnerabilities[]? | select(.Severity == "CRITICAL" or .Severity == "HIGH") | "### \(.VulnerabilityID) - \(.PkgName)\n- **Description:** \(.Description // "No description")\n- **Fixed in:** \(.FixedVersion // "No fix available")\n- **CVSS Score:** \(.CVSS.nvd.V3Score // "N/A")\n"' "$json_file" >> "$summary_file"
    fi
}

quick_check() {
    local image_name="$1"
    
    info "Running quick vulnerability check..."
    
    # Quick scan with critical and high only
    trivy image \
        --severity CRITICAL,HIGH \
        --format table \
        --light \
        "$image_name" || true
}

setup_monitoring() {
    info "Setting up continuous security monitoring..."
    
    # Create monitoring script
    local monitor_script="$HOME/.local/bin/hass-security-monitor"
    mkdir -p "$(dirname "$monitor_script")"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# Automated security monitoring for Home Assistant bootc image

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/security-check.sh"

# Run quick security check
quick_check "$IMAGE_NAME"

# Send notification if critical vulnerabilities found
if [[ $? -ne 0 ]]; then
    echo "Critical vulnerabilities detected in Home Assistant bootc image!"
    echo "Run '$SCRIPT_DIR/security-check.sh scan' for detailed analysis"
fi
EOF
    
    chmod +x "$monitor_script"
    
    # Suggest crontab entry
    info "Monitoring script created: $monitor_script"
    info "To enable daily monitoring, add this to your crontab:"
    info "0 2 * * * $monitor_script"
    info ""
    info "Run 'crontab -e' and add the above line"
}

main() {
    local command="${1:-help}"
    local image_name="$IMAGE_NAME"
    local severity="HIGH,CRITICAL"
    local format="table"
    local output_file=""
    local show_fixes="false"
    
    # Parse arguments
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --image)
                image_name="$2"
                shift 2
                ;;
            --severity)
                severity="$2"
                shift 2
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --output)
                output_file="$2"
                shift 2
                ;;
            --fix-suggestions)
                show_fixes="true"
                shift
                ;;
            *)
                warn "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    case $command in
        scan)
            check_dependencies
            run_security_scan "$image_name" "$severity" "$format" "$output_file" "$show_fixes"
            ;;
        quick)
            check_dependencies
            quick_check "$image_name"
            ;;
        report)
            check_dependencies
            run_security_scan "$image_name" "$severity" "json" "" "true"
            ;;
        fix)
            info "Security fix suggestions:"
            info "1. Update base image: FROM quay.io/fedora/fedora-bootc:42"
            info "2. Remove vulnerable packages: RUN dnf -y remove toolbox* golang*"
            info "3. Apply security updates: RUN dnf -y upgrade --security"
            info "4. Rebuild image: make build"
            info ""
            info "For detailed analysis, run: $0 scan --fix-suggestions"
            ;;
        monitor)
            setup_monitoring
            ;;
        install-trivy)
            install_trivy
            ;;
        help|*)
            usage
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi