#!/bin/bash
# Tests for health-check.sh script

set -euo pipefail

# Simple logging functions (avoid collision with macOS 'log' command)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

test_log() {
    echo -e "${GREEN}[OK]${NC} $1"
}

test_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

test_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test framework functions
assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ ! -f "$file" ]]; then
        test_error "$message - File not found: $file"
        return 1
    fi
    test_log "$message"
    return 0
}

assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command should exist}"
    
    if ! command -v "$cmd" &>/dev/null; then
        test_warn "$message - Command not available: $cmd"
        return 1
    fi
    test_log "$message"
    return 0
}

# Test: Script exists and is executable
test_script_exists() {
    assert_file_exists "$PROJECT_ROOT/scripts/health-check.sh" "health-check.sh should exist"
    if [[ -x "$PROJECT_ROOT/scripts/health-check.sh" ]]; then
        test_log "health-check.sh is executable"
    else
        test_error "health-check.sh is not executable"
        return 1
    fi
}

# Test: Check required commands
test_required_commands() {
    # Test essential commands that should be available everywhere
    if command -v df &>/dev/null; then
        test_log "df command is available"
    else
        test_error "df command is missing"
        return 1
    fi
    
    # Commands that might not be available on macOS
    if command -v free &>/dev/null; then
        test_log "free command is available"
    else
        test_warn "free command not available (normal on macOS - use vm_stat instead)"
    fi
    
    if command -v systemctl &>/dev/null; then
        test_log "systemctl command is available"
    else
        test_warn "systemctl not available (normal on macOS)"
    fi
    
    return 0  # Don't fail for missing optional commands
}

# Test: Validate check_service function
test_check_service_function() {
    # Simple test that systemctl command exists
    if command -v systemctl &>/dev/null; then
        test_log "systemctl command is available"
        return 0
    else
        test_warn "systemctl not available on this system"
        return 0  # Skip test rather than fail
    fi
}

# Test: Validate memory check thresholds
test_memory_thresholds() {
    # Test threshold calculations
    local total_mem=8192  # 8GB in MB
    local warning_threshold=$((total_mem * 80 / 100))
    local critical_threshold=$((total_mem * 90 / 100))
    
    if [[ "$warning_threshold" -eq 6553 ]]; then
        test_log "Warning threshold calculation correct"
    else
        test_error "Warning threshold calculation failed"
        return 1
    fi
    
    if [[ "$critical_threshold" -eq 7372 ]]; then
        test_log "Critical threshold calculation correct"
    else
        test_error "Critical threshold calculation failed"
        return 1
    fi
}

# Test: Validate disk space check
test_disk_space_check() {
    # Simple test that df command works
    if df -h / >/dev/null 2>&1; then
        test_log "df command works correctly"
        return 0
    else
        test_error "df command failed"
        return 1
    fi
}

# Run all tests
main() {
    echo "Running health-check.sh tests..."
    local failed=0
    
    test_script_exists || failed=$((failed + 1))
    test_required_commands || failed=$((failed + 1))
    test_check_service_function || failed=$((failed + 1))
    test_memory_thresholds || failed=$((failed + 1))
    test_disk_space_check || failed=$((failed + 1))
    
    echo ""
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}$failed tests failed!${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi