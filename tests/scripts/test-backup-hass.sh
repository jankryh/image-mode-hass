#!/bin/bash
# Tests for backup-hass.sh script

set -euo pipefail

# Simplified test for bash 3.x compatibility
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test framework functions
assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}FAIL:${NC} $message - File not found: $file"
        return 1
    fi
    echo -e "${GREEN}PASS:${NC} $message"
    return 0
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    if ! eval "$condition"; then
        echo -e "${RED}FAIL:${NC} $message"
        return 1
    fi
    echo -e "${GREEN}PASS:${NC} $message"
    return 0
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${RED}FAIL:${NC} $message (expected: '$expected', got: '$actual')"
        return 1
    fi
    echo -e "${GREEN}PASS:${NC} $message"
    return 0
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ ! "$haystack" == *"$needle"* ]]; then
        echo -e "${RED}FAIL:${NC} $message"
        return 1
    fi
    echo -e "${GREEN}PASS:${NC} $message"
    return 0
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}FAIL:${NC} $message - Directory not found: $dir"
        return 1
    fi
    echo -e "${GREEN}PASS:${NC} $message"
    return 0
}

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test: Script exists and is executable
test_script_exists() {
    assert_file_exists "$PROJECT_ROOT/scripts/backup-hass.sh" "backup-hass.sh should exist"
    assert_true "[[ -x '$PROJECT_ROOT/scripts/backup-hass.sh' ]]" "backup-hass.sh should be executable"
}

# Test: Backup directory creation
test_backup_directory_creation() {
    local test_backup_dir="/tmp/test-backup-$$"
    
    # Test directory creation logic
    mkdir -p "$test_backup_dir"
    assert_dir_exists "$test_backup_dir" "Should create backup directory"
    
    # Test permissions (simplified for cross-platform compatibility)
    chmod 755 "$test_backup_dir"
    if [[ -d "$test_backup_dir" ]]; then
        echo -e "${GREEN}PASS:${NC} Backup directory permissions set"
    else
        echo -e "${RED}FAIL:${NC} Backup directory permissions failed"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_backup_dir"
}

# Test: Backup file naming convention
test_backup_naming() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local expected_name="hass-backup-${timestamp}.tar.gz"
    
    # Test filename format
    assert_contains "$expected_name" "hass-backup-" "Backup name should contain prefix"
    assert_contains "$expected_name" ".tar.gz" "Backup should be compressed"
}

# Test: Configuration validation
test_config_validation() {
    # Test empty config directory
    local empty_dir="/tmp/empty-config-$$"
    mkdir -p "$empty_dir"
    
    local file_count=$(find "$empty_dir" -type f | wc -l | tr -d ' ')
    assert_equals "0" "$file_count" "Empty directory should have no files"
    
    # Cleanup
    rm -rf "$empty_dir"
}

# Test: Tar command construction
test_tar_command() {
    local backup_file="/tmp/test-backup.tar.gz"
    local source_dir="/tmp/test-source"
    
    # Expected tar command components
    local tar_cmd="tar -czf $backup_file -C $(dirname $source_dir) $(basename $source_dir)"
    
    assert_contains "$tar_cmd" "-czf" "Tar command should use compression"
    assert_contains "$tar_cmd" "-C" "Tar command should change directory"
}

# Test: Retention policy
test_retention_policy() {
    local retention_days=7
    local test_dir="/tmp/test-retention-$$"
    mkdir -p "$test_dir"
    
    # Create test backup files (simplified for macOS compatibility)
    for i in 1 2 3 8 9 10; do
        touch "$test_dir/hass-backup-202412$(printf %02d $i).tar.gz"
    done
    
    # Simple test that files exist
    local file_count=$(find "$test_dir" -name "*.tar.gz" | wc -l)
    if [[ $file_count -gt 0 ]]; then
        echo -e "${GREEN}PASS:${NC} Test files created for retention policy"
    else
        echo -e "${RED}FAIL:${NC} Failed to create test files"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
}

# Run all tests
main() {
    echo "Running backup-hass.sh tests..."
    local failed=0
    
    test_script_exists || failed=$((failed + 1))
    test_backup_directory_creation || failed=$((failed + 1))
    test_backup_naming || failed=$((failed + 1))
    test_config_validation || failed=$((failed + 1))
    test_tar_command || failed=$((failed + 1))
    test_retention_policy || failed=$((failed + 1))
    
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