#!/bin/bash
# Performance Testing and Benchmarking Suite
# Comprehensive performance analysis for Home Assistant bootc deployments

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_ROOT/performance_results"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$RESULTS_DIR/performance_report_$TIMESTAMP.html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Performance thresholds
BOOT_TIME_THRESHOLD=120    # seconds
MEMORY_THRESHOLD=80        # percentage
CPU_THRESHOLD=80           # percentage
DISK_IO_THRESHOLD=100      # MB/s minimum

# Test results storage
declare -A test_results

# Logging functions
log() { echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
error() { echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
info() { echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }
debug() { [[ "${VERBOSE:-}" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"; }

# Initialize performance testing
init_performance_testing() {
    log "Initializing performance testing environment..."
    
    mkdir -p "$RESULTS_DIR"
    
    # Check required tools
    local required_tools=("stress" "sysbench" "iotop" "htop" "vmstat" "iostat")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        warn "Missing performance testing tools: ${missing_tools[*]}"
        info "Installing missing tools..."
        
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y stress sysbench iotop htop sysstat
        elif command -v apt >/dev/null 2>&1; then
            sudo apt update && sudo apt install -y stress sysbench iotop htop sysstat
        else
            error "Cannot install required tools automatically"
            return 1
        fi
    fi
    
    log "Performance testing environment ready"
}

# Test system boot time
test_boot_performance() {
    log "Testing boot performance..."
    
    local boot_time
    boot_time=$(systemd-analyze | grep "Startup finished in" | awk '{
        gsub(/[()]/, "", $0)
        for(i=1; i<=NF; i++) {
            if($i ~ /[0-9]+(\.[0-9]+)?s$/) {
                gsub(/s$/, "", $i)
                total += $i
            }
        }
        print total
    }')
    
    test_results["boot_time"]="$boot_time"
    
    if (( $(echo "$boot_time <= $BOOT_TIME_THRESHOLD" | bc -l) )); then
        log "Boot time: ${boot_time}s (PASS - under ${BOOT_TIME_THRESHOLD}s threshold)"
    else
        warn "Boot time: ${boot_time}s (WARNING - exceeds ${BOOT_TIME_THRESHOLD}s threshold)"
    fi
    
    # Analyze boot bottlenecks
    info "Analyzing boot bottlenecks..."
    systemd-analyze blame | head -10 > "$RESULTS_DIR/boot_blame_$TIMESTAMP.txt"
    
    debug "Boot blame report saved to boot_blame_$TIMESTAMP.txt"
}

# Test CPU performance
test_cpu_performance() {
    log "Testing CPU performance..."
    
    # CPU benchmark using sysbench
    info "Running CPU benchmark (prime numbers calculation)..."
    local cpu_result
    cpu_result=$(sysbench cpu --cpu-max-prime=20000 --threads=$(nproc) run | grep "events per second:" | awk '{print $4}')
    
    test_results["cpu_events_per_second"]="$cpu_result"
    log "CPU performance: $cpu_result events/second"
    
    # CPU stress test
    info "Running CPU stress test (30 seconds)..."
    local cpu_usage_before cpu_usage_after
    cpu_usage_before=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    stress --cpu $(nproc) --timeout 30s >/dev/null 2>&1 &
    local stress_pid=$!
    
    sleep 10  # Let stress settle
    local cpu_usage_during
    cpu_usage_during=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    wait $stress_pid
    cpu_usage_after=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    
    test_results["cpu_usage_before"]="$cpu_usage_before"
    test_results["cpu_usage_during"]="$cpu_usage_during"
    test_results["cpu_usage_after"]="$cpu_usage_after"
    
    info "CPU usage: before=$cpu_usage_before%, during stress=$cpu_usage_during%, after=$cpu_usage_after%"
}

# Test memory performance
test_memory_performance() {
    log "Testing memory performance..."
    
    # Memory information
    local total_mem available_mem used_mem mem_usage_percent
    total_mem=$(free -m | awk 'NR==2{print $2}')
    available_mem=$(free -m | awk 'NR==2{print $7}')
    used_mem=$(free -m | awk 'NR==2{print $3}')
    mem_usage_percent=$(( (used_mem * 100) / total_mem ))
    
    test_results["memory_total"]="${total_mem}MB"
    test_results["memory_available"]="${available_mem}MB"
    test_results["memory_used"]="${used_mem}MB"
    test_results["memory_usage_percent"]="$mem_usage_percent%"
    
    if [[ $mem_usage_percent -lt $MEMORY_THRESHOLD ]]; then
        log "Memory usage: $mem_usage_percent% (PASS - under ${MEMORY_THRESHOLD}% threshold)"
    else
        warn "Memory usage: $mem_usage_percent% (WARNING - exceeds ${MEMORY_THRESHOLD}% threshold)"
    fi
    
    # Memory benchmark
    info "Running memory benchmark..."
    local mem_speed
    mem_speed=$(sysbench memory --memory-block-size=1M --memory-total-size=10G run | grep "transferred" | awk '{print $(NF-1), $NF}')
    test_results["memory_speed"]="$mem_speed"
    
    log "Memory speed: $mem_speed"
}

# Test disk I/O performance
test_disk_performance() {
    log "Testing disk I/O performance..."
    
    local test_file="/tmp/disk_test_$TIMESTAMP"
    
    # Write test
    info "Testing disk write performance..."
    local write_speed
    write_speed=$(dd if=/dev/zero of="$test_file" bs=1M count=1000 2>&1 | grep -o '[0-9.]\+ MB/s' | tail -1)
    test_results["disk_write_speed"]="$write_speed"
    
    # Read test
    info "Testing disk read performance..."
    sync  # Ensure write is complete
    echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null  # Clear cache
    local read_speed
    read_speed=$(dd if="$test_file" of=/dev/null bs=1M 2>&1 | grep -o '[0-9.]\+ MB/s' | tail -1)
    test_results["disk_read_speed"]="$read_speed"
    
    # Random I/O test using sysbench
    info "Testing random I/O performance..."
    sysbench fileio --file-total-size=2G prepare >/dev/null 2>&1
    local random_io_result
    random_io_result=$(sysbench fileio --file-total-size=2G --file-test-mode=rndrw --time=30 run | grep "Operations performed:" | awk '{print $3, $4, $5}')
    test_results["random_io_ops"]="$random_io_result"
    sysbench fileio cleanup >/dev/null 2>&1
    
    # Cleanup test file
    rm -f "$test_file"
    
    log "Disk performance - Write: $write_speed, Read: $read_speed"
    log "Random I/O: $random_io_result"
}

# Test network performance
test_network_performance() {
    log "Testing network performance..."
    
    # Test local network interface
    local interface
    interface=$(ip route get 8.8.8.8 | awk 'NR==1{print $5}')
    
    if [[ -n "$interface" ]]; then
        local interface_speed
        interface_speed=$(cat "/sys/class/net/$interface/speed" 2>/dev/null || echo "unknown")
        test_results["network_interface"]="$interface"
        test_results["network_speed"]="${interface_speed}Mbps"
        
        info "Network interface: $interface, Speed: ${interface_speed}Mbps"
    else
        warn "Could not determine network interface"
    fi
    
    # Test internet connectivity and latency
    info "Testing internet connectivity..."
    local ping_result
    if ping_result=$(ping -c 4 8.8.8.8 2>/dev/null); then
        local avg_latency
        avg_latency=$(echo "$ping_result" | tail -1 | awk '{print $4}' | cut -d'/' -f2)
        test_results["internet_latency"]="${avg_latency}ms"
        log "Internet connectivity: OK, Average latency: ${avg_latency}ms"
    else
        warn "Internet connectivity: FAILED"
        test_results["internet_latency"]="N/A"
    fi
}

# Test container performance
test_container_performance() {
    log "Testing container performance..."
    
    if ! command -v podman >/dev/null 2>&1; then
        warn "Podman not available, skipping container tests"
        return 0
    fi
    
    # Test container startup time
    info "Testing container startup time..."
    local start_time end_time startup_duration
    start_time=$(date +%s.%N)
    
    podman run --rm alpine:latest echo "Hello World" >/dev/null 2>&1
    
    end_time=$(date +%s.%N)
    startup_duration=$(echo "$end_time - $start_time" | bc)
    test_results["container_startup_time"]="${startup_duration}s"
    
    log "Container startup time: ${startup_duration}s"
    
    # Test Home Assistant container if available
    if podman image exists ghcr.io/home-assistant/home-assistant:latest >/dev/null 2>&1; then
        info "Testing Home Assistant container startup..."
        start_time=$(date +%s.%N)
        
        podman run --rm --name ha-test \
            -v /tmp/ha-test-config:/config \
            ghcr.io/home-assistant/home-assistant:latest \
            python -m homeassistant --version >/dev/null 2>&1
        
        end_time=$(date +%s.%N)
        startup_duration=$(echo "$end_time - $start_time" | bc)
        test_results["ha_container_startup_time"]="${startup_duration}s"
        
        log "Home Assistant container startup: ${startup_duration}s"
        rm -rf /tmp/ha-test-config
    fi
}

# Generate performance report
generate_performance_report() {
    log "Generating performance report..."
    
    cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Home Assistant bootc - Performance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric-card { background: #ecf0f1; padding: 15px; border-radius: 6px; border-left: 4px solid #3498db; }
        .metric-label { font-weight: bold; color: #2c3e50; }
        .metric-value { font-size: 1.2em; color: #27ae60; margin-top: 5px; }
        .status-pass { color: #27ae60; font-weight: bold; }
        .status-warn { color: #f39c12; font-weight: bold; }
        .status-fail { color: #e74c3c; font-weight: bold; }
        .summary { background: #d5dbdb; padding: 15px; border-radius: 6px; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #bdc3c7; padding: 10px; text-align: left; }
        th { background-color: #34495e; color: white; }
        tr:nth-child(even) { background-color: #f8f9fa; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #bdc3c7; font-size: 0.9em; color: #7f8c8d; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Home Assistant bootc - Performance Report</h1>
        <div class="summary">
            <strong>Test Date:</strong> $(date)<br>
            <strong>System:</strong> $(uname -a)<br>
            <strong>Hostname:</strong> $(hostname)<br>
            <strong>Report ID:</strong> $TIMESTAMP
        </div>

        <h2>📊 Performance Metrics</h2>
        <div class="metric-grid">
EOF

    # Add metrics to report
    for metric in "${!test_results[@]}"; do
        local value="${test_results[$metric]}"
        cat >> "$REPORT_FILE" << EOF
            <div class="metric-card">
                <div class="metric-label">$(echo "$metric" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1))substr($i,2)}}1')</div>
                <div class="metric-value">$value</div>
            </div>
EOF
    done

    cat >> "$REPORT_FILE" << EOF
        </div>

        <h2>🏁 Performance Summary</h2>
        <table>
            <tr>
                <th>Category</th>
                <th>Metric</th>
                <th>Value</th>
                <th>Threshold</th>
                <th>Status</th>
            </tr>
EOF

    # Add summary rows
    local boot_time="${test_results[boot_time]:-N/A}"
    local mem_usage="${test_results[memory_usage_percent]:-N/A}"
    
    # Boot time status
    local boot_status="N/A"
    if [[ "$boot_time" != "N/A" ]]; then
        if (( $(echo "$boot_time <= $BOOT_TIME_THRESHOLD" | bc -l) )); then
            boot_status='<span class="status-pass">PASS</span>'
        else
            boot_status='<span class="status-warn">WARNING</span>'
        fi
    fi
    
    # Memory usage status
    local memory_status="N/A"
    if [[ "$mem_usage" != "N/A" ]]; then
        local mem_percent=$(echo "$mem_usage" | tr -d '%')
        if [[ $mem_percent -lt $MEMORY_THRESHOLD ]]; then
            memory_status='<span class="status-pass">PASS</span>'
        else
            memory_status='<span class="status-warn">WARNING</span>'
        fi
    fi

    cat >> "$REPORT_FILE" << EOF
            <tr>
                <td>Boot</td>
                <td>Boot Time</td>
                <td>${boot_time}s</td>
                <td>&lt; ${BOOT_TIME_THRESHOLD}s</td>
                <td>$boot_status</td>
            </tr>
            <tr>
                <td>Memory</td>
                <td>Usage</td>
                <td>$mem_usage</td>
                <td>&lt; ${MEMORY_THRESHOLD}%</td>
                <td>$memory_status</td>
            </tr>
            <tr>
                <td>Disk</td>
                <td>Write Speed</td>
                <td>${test_results[disk_write_speed]:-N/A}</td>
                <td>&gt; ${DISK_IO_THRESHOLD} MB/s</td>
                <td><span class="status-pass">INFO</span></td>
            </tr>
            <tr>
                <td>Disk</td>
                <td>Read Speed</td>
                <td>${test_results[disk_read_speed]:-N/A}</td>
                <td>&gt; ${DISK_IO_THRESHOLD} MB/s</td>
                <td><span class="status-pass">INFO</span></td>
            </tr>
        </table>

        <h2>💡 Recommendations</h2>
        <ul>
EOF

    # Add recommendations based on results
    if [[ "$boot_time" != "N/A" ]] && (( $(echo "$boot_time > $BOOT_TIME_THRESHOLD" | bc -l) )); then
        echo "            <li>Consider optimizing boot services - current boot time exceeds recommended threshold</li>" >> "$REPORT_FILE"
    fi
    
    if [[ "$mem_usage" != "N/A" ]]; then
        local mem_percent=$(echo "$mem_usage" | tr -d '%')
        if [[ $mem_percent -gt $MEMORY_THRESHOLD ]]; then
            echo "            <li>Memory usage is high - consider increasing RAM or optimizing memory consumption</li>" >> "$REPORT_FILE"
        fi
    fi

    cat >> "$REPORT_FILE" << EOF
            <li>Regular performance monitoring is recommended for production deployments</li>
            <li>Consider implementing automated performance alerts for critical thresholds</li>
            <li>Review disk I/O patterns for potential optimization opportunities</li>
        </ul>

        <div class="footer">
            <p>Generated by Home Assistant bootc Performance Testing Suite</p>
            <p>For detailed analysis and optimization recommendations, review the individual test logs.</p>
        </div>
    </div>
</body>
</html>
EOF

    log "Performance report generated: $REPORT_FILE"
}

# Main execution
main() {
    echo "=============================================="
    echo "    Performance Testing and Benchmarking"
    echo "=============================================="
    echo ""
    
    # Parse command line arguments
    local test_types=()
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                test_types=("boot" "cpu" "memory" "disk" "network" "container")
                shift
                ;;
            --boot)
                test_types+=("boot")
                shift
                ;;
            --cpu)
                test_types+=("cpu")
                shift
                ;;
            --memory)
                test_types+=("memory")
                shift
                ;;
            --disk)
                test_types+=("disk")
                shift
                ;;
            --network)
                test_types+=("network")
                shift
                ;;
            --container)
                test_types+=("container")
                shift
                ;;
            --verbose|-v)
                export VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --all           Run all performance tests"
                echo "  --boot          Test boot performance"
                echo "  --cpu           Test CPU performance" 
                echo "  --memory        Test memory performance"
                echo "  --disk          Test disk I/O performance"
                echo "  --network       Test network performance"
                echo "  --container     Test container performance"
                echo "  --verbose, -v   Enable verbose output"
                echo "  --help, -h      Show this help"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Default to all tests if none specified
    if [[ ${#test_types[@]} -eq 0 ]]; then
        test_types=("boot" "cpu" "memory" "disk" "network" "container")
    fi
    
    # Initialize testing environment
    init_performance_testing
    
    # Run selected tests
    for test_type in "${test_types[@]}"; do
        case "$test_type" in
            "boot")
                test_boot_performance
                ;;
            "cpu")
                test_cpu_performance
                ;;
            "memory")
                test_memory_performance
                ;;
            "disk")
                test_disk_performance
                ;;
            "network")
                test_network_performance
                ;;
            "container")
                test_container_performance
                ;;
        esac
    done
    
    # Generate comprehensive report
    generate_performance_report
    
    log "Performance testing completed successfully"
    log "View detailed report: $REPORT_FILE"
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi