#!/bin/bash
# Simplified Performance Testing
# Basic performance checks for Home Assistant bootc deployments

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/performance_results"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$RESULTS_DIR/performance_report_$TIMESTAMP.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Performance thresholds
BOOT_TIME_THRESHOLD=120    # seconds
MEMORY_THRESHOLD=80        # percentage
DISK_IO_THRESHOLD=50       # MB/s minimum

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$REPORT_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$REPORT_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$REPORT_FILE"; }

# Initialize performance testing
init_performance_testing() {
    log "Initializing performance testing..."
    mkdir -p "$RESULTS_DIR"
    
    # Check for basic tools
    local required_tools=("systemd-analyze" "free" "df" "uptime")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        warn "Missing tools: ${missing_tools[*]}"
    fi
    
    log "Performance testing ready"
}

# Test system boot time
test_boot_performance() {
    log "Testing boot performance..."
    
    if command -v systemd-analyze >/dev/null 2>&1; then
        local boot_time
        boot_time=$(systemd-analyze | grep "Startup finished in" | sed 's/.*in \([0-9.]*\)s.*/\1/')
        
        if [[ -n "$boot_time" ]]; then
            log "Boot time: ${boot_time}s"
            
            if (( $(echo "$boot_time <= $BOOT_TIME_THRESHOLD" | bc -l 2>/dev/null || echo "1") )); then
                log "✅ Boot time is acceptable (under ${BOOT_TIME_THRESHOLD}s)"
            else
                warn "⚠️ Boot time exceeds threshold (${BOOT_TIME_THRESHOLD}s)"
            fi
        else
            warn "Could not determine boot time"
        fi
    else
        warn "systemd-analyze not available"
    fi
}

# Test memory usage
test_memory_performance() {
    log "Testing memory performance..."
    
    if command -v free >/dev/null 2>&1; then
        local total_mem used_mem available_mem
        read -r total_mem used_mem available_mem <<< "$(free -m | grep '^Mem:' | awk '{print $2, $3, $7}')"
        
        local usage_percent
        usage_percent=$(echo "scale=1; $used_mem * 100 / $total_mem" | bc -l 2>/dev/null || echo "0")
        
        log "Memory usage: ${usage_percent}% (${used_mem}MB / ${total_mem}MB)"
        
        if (( $(echo "$usage_percent <= $MEMORY_THRESHOLD" | bc -l 2>/dev/null || echo "1") )); then
            log "✅ Memory usage is acceptable (under ${MEMORY_THRESHOLD}%)"
        else
            warn "⚠️ Memory usage is high (${MEMORY_THRESHOLD}% threshold)"
        fi
    else
        warn "free command not available"
    fi
}

# Test disk performance
test_disk_performance() {
    log "Testing disk performance..."
    
    if command -v df >/dev/null 2>&1; then
        local disk_usage
        disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
        
        log "Disk usage: ${disk_usage}%"
        
        if [[ "$disk_usage" -lt 80 ]]; then
            log "✅ Disk usage is acceptable (under 80%)"
        else
            warn "⚠️ Disk usage is high (${disk_usage}%)"
        fi
    else
        warn "df command not available"
    fi
}

# Test system uptime
test_system_uptime() {
    log "Testing system uptime..."
    
    if command -v uptime >/dev/null 2>&1; then
        local uptime_info
        uptime_info=$(uptime)
        log "System uptime: $uptime_info"
    else
        warn "uptime command not available"
    fi
}

# Test Home Assistant service
test_hass_service() {
    log "Testing Home Assistant service..."
    
    if systemctl is-active --quiet home-assistant; then
        log "✅ Home Assistant service is running"
        
        # Check service status
        local service_status
        service_status=$(systemctl is-enabled home-assistant 2>/dev/null || echo "unknown")
        log "Service enabled: $service_status"
    else
        error "❌ Home Assistant service is not running"
    fi
}

# Generate simple report
generate_report() {
    log "Generating performance report..."
    
    echo "==============================================" >> "$REPORT_FILE"
    echo "   Home Assistant bootc Performance Report" >> "$REPORT_FILE"
    echo "==============================================" >> "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    log "Report saved to: $REPORT_FILE"
}

# Main function
main() {
    case "${1:-all}" in
        "boot")
            init_performance_testing
            test_boot_performance
            ;;
        "memory")
            init_performance_testing
            test_memory_performance
            ;;
        "disk")
            init_performance_testing
            test_disk_performance
            ;;
        "uptime")
            init_performance_testing
            test_system_uptime
            ;;
        "hass")
            init_performance_testing
            test_hass_service
            ;;
        "all")
            init_performance_testing
            test_boot_performance
            test_memory_performance
            test_disk_performance
            test_system_uptime
            test_hass_service
            generate_report
            ;;
        *)
            echo "Usage: $0 {boot|memory|disk|uptime|hass|all}"
            echo "  boot   - Test boot performance"
            echo "  memory - Test memory usage"
            echo "  disk   - Test disk usage"
            echo "  uptime - Test system uptime"
            echo "  hass   - Test Home Assistant service"
            echo "  all    - Run all tests (default)"
            exit 1
            ;;
    esac
}

main "$@"