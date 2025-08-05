#!/bin/bash
# Home Assistant system health check script
# Usage: ./health-check.sh [--verbose]

set -euo pipefail

# Load common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Initialize script
init_script "health-check"

# Parse arguments
ARGS=$(parse_log_args "$@")
set -- $ARGS

VERBOSE=false
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
    LOG_LEVEL=$LOG_LEVEL_DEBUG
fi

# Redefine log function for backward compatibility
log() {
    success "$1"
}

verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Health check functions
check_system_resources() {
    info "Checking system resources..."
    
    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
    verbose "Memory usage: ${mem_usage}%"
    if (( $(echo "$mem_usage > 90" | bc -l) )); then
        error "High memory usage: ${mem_usage}%"
    elif (( $(echo "$mem_usage > 80" | bc -l) )); then
        warn "Memory usage: ${mem_usage}%"
    else
        log "Memory usage: ${mem_usage}%"
    fi
    
    # Disk usage
    local disk_usage=$(df /var | tail -1 | awk '{print $5}' | sed 's/%//')
    verbose "Disk usage (/var): ${disk_usage}%"
    if [[ $disk_usage -gt 90 ]]; then
        error "High disk usage: ${disk_usage}%"
    elif [[ $disk_usage -gt 80 ]]; then
        warn "Disk usage: ${disk_usage}%"
    else
        log "Disk usage: ${disk_usage}%"
    fi
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    verbose "Load average (1min): $load_avg"
    log "Load average (1min): $load_avg"
}

check_services() {
    info "Checking critical services..."
    
    local services=("home-assistant" "zerotier-one" "sshd" "chronyd" "fail2ban")
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            log "Service $service is running"
            if [[ "$VERBOSE" == true ]]; then
                local status=$(systemctl show "$service" --property=ActiveState,SubState --no-pager)
                verbose "$service status: $status"
            fi
        else
            error "Service $service is not running"
            if systemctl is-enabled --quiet "$service"; then
                warn "Service $service is enabled but not running"
            else
                warn "Service $service is not enabled"
            fi
        fi
    done
}

check_containers() {
    info "Checking containers..."
    
    # Check if podman is available
    if ! command -v podman &> /dev/null; then
        error "Podman is not installed or not in PATH"
        return 1
    fi
    
    # Check Home Assistant container
    if podman ps --format "{{.Names}}" | grep -q "home-assistant"; then
        log "Home Assistant container is running"
        if [[ "$VERBOSE" == true ]]; then
            local container_status=$(podman ps --filter name=home-assistant --format "{{.Status}}")
            verbose "Container status: $container_status"
        fi
    else
        error "Home Assistant container is not running"
        verbose "Available containers:"
        verbose "$(podman ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}')"
    fi
}

check_network() {
    info "Checking network connectivity..."
    
    # Check if Home Assistant port is open
    if ss -tlnp | grep -q ":8123"; then
        log "Home Assistant port 8123 is listening"
    else
        error "Home Assistant port 8123 is not listening"
    fi
    
    # Check ZeroTier network
    if command -v zerotier-cli &> /dev/null; then
        local zt_networks=$(zerotier-cli listnetworks 2>/dev/null | tail -n +2 | wc -l)
        if [[ $zt_networks -gt 0 ]]; then
            log "ZeroTier is connected to $zt_networks network(s)"
            if [[ "$VERBOSE" == true ]]; then
                verbose "ZeroTier networks:"
                zerotier-cli listnetworks 2>/dev/null || true
            fi
        else
            warn "ZeroTier is not connected to any networks"
        fi
    else
        warn "ZeroTier CLI not available"
    fi
    
    # Check internet connectivity
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log "Internet connectivity is working"
    else
        error "No internet connectivity"
    fi
}

check_bootc_status() {
    info "Checking bootc status..."
    
    if command -v bootc &> /dev/null; then
        if [[ "$VERBOSE" == true ]]; then
            verbose "bootc status:"
            bootc status || warn "Failed to get bootc status"
        else
            local bootc_output=$(bootc status 2>/dev/null | grep -E "(Staged|Booted)" | head -2)
            if [[ -n "$bootc_output" ]]; then
                log "bootc status OK"
                verbose "$bootc_output"
            else
                warn "Unable to determine bootc status"
            fi
        fi
    else
        warn "bootc command not available"
    fi
}

check_logs() {
    info "Checking for recent errors in logs..."
    
    local error_count=$(journalctl --since "1 hour ago" --priority=err --no-pager | wc -l)
    if [[ $error_count -gt 0 ]]; then
        warn "Found $error_count error(s) in system logs in the last hour"
        if [[ "$VERBOSE" == true ]]; then
            verbose "Recent errors:"
            journalctl --since "1 hour ago" --priority=err --no-pager | tail -10
        fi
    else
        log "No errors found in recent system logs"
    fi
    
    # Check Home Assistant specific logs
    if systemctl is-active --quiet home-assistant; then
        local hass_errors=$(journalctl -u home-assistant --since "1 hour ago" --priority=err --no-pager | wc -l)
        if [[ $hass_errors -gt 0 ]]; then
            warn "Found $hass_errors error(s) in Home Assistant logs in the last hour"
            if [[ "$VERBOSE" == true ]]; then
                verbose "Home Assistant errors:"
                journalctl -u home-assistant --since "1 hour ago" --priority=err --no-pager | tail -5
            fi
        else
            log "No errors in Home Assistant logs"
        fi
    fi
}

main() {
    echo "=== Home Assistant System Health Check ==="
    echo "Timestamp: $(date)"
    echo "Hostname: $(hostname)"
    echo ""
    
    check_system_resources
    echo ""
    check_services
    echo ""
    check_containers
    echo ""
    check_network
    echo ""
    check_bootc_status
    echo ""
    check_logs
    echo ""
    
    info "Health check completed at $(date)"
}

# Run main function
main "$@"