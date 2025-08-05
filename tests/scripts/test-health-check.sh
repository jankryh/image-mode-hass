#!/bin/bash
# Tests for health-check.sh script

set -euo pipefail

# Source test framework
source "$(dirname "$0")/../test-framework.sh"

# Source the script to test (in test mode)
export TEST_MODE=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test: Script exists and is executable
test_script_exists() {
    assert_file_exists "$PROJECT_ROOT/scripts/health-check.sh" "health-check.sh should exist"
    assert_true "[[ -x '$PROJECT_ROOT/scripts/health-check.sh' ]]" "health-check.sh should be executable"
}

# Test: Check required commands
test_required_commands() {
    # These commands should be available on the system
    assert_command_exists "systemctl" "systemctl should be available"
    assert_command_exists "free" "free command should be available"
    assert_command_exists "df" "df command should be available"
}

# Test: Validate check_service function
test_check_service_function() {
    # Create a mock systemctl function for testing
    systemctl() {
        case "$1 $2 $3" in
            "is-active --quiet sshd")
                return 0  # Active
                ;;
            "is-active --quiet fake-service")
                return 1  # Inactive
                ;;
            *)
                return 1
                ;;
        esac
    }
    export -f systemctl
    
    # Source functions from health-check.sh (without running main)
    source <(grep -E '^(check_service|log|warn|error)\(\)' "$PROJECT_ROOT/scripts/health-check.sh" | sed 's/^//')
    
    # Test active service
    local output
    output=$(check_service "sshd" 2>&1) || true
    assert_contains "$output" "sshd" "Should mention service name"
    
    # Test inactive service
    output=$(check_service "fake-service" 2>&1) || true
    assert_contains "$output" "fake-service" "Should mention service name"
}

# Test: Validate memory check thresholds
test_memory_thresholds() {
    # Test threshold calculations
    local total_mem=8192  # 8GB in MB
    local warning_threshold=$((total_mem * 80 / 100))
    local critical_threshold=$((total_mem * 90 / 100))
    
    assert_equals "6553" "$warning_threshold" "Warning threshold should be 80% of total"
    assert_equals "7372" "$critical_threshold" "Critical threshold should be 90% of total"
}

# Test: Validate disk space check
test_disk_space_check() {
    # Create a mock df function
    df() {
        if [[ "$1" == "-h" ]]; then
            echo "Filesystem      Size  Used Avail Use% Mounted on"
            echo "/dev/sda1        20G   15G  4.0G  80% /"
            echo "/dev/sda2        50G   40G  8.0G  85% /var"
        fi
    }
    export -f df
    
    # Test parsing df output
    local output
    output=$(df -h | grep -E "^/dev/" | awk '{print $5}' | tr -d '%')
    assert_contains "$output" "80" "Should parse disk usage percentage"
}

# Run all tests
main() {
    init_tests
    
    run_test "Script exists and is executable" test_script_exists
    run_test "Required commands available" test_required_commands
    run_test "Service check function" test_check_service_function
    run_test "Memory threshold calculations" test_memory_thresholds
    run_test "Disk space check parsing" test_disk_space_check
    
    print_summary
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi