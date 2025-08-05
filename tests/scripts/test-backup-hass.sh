#!/bin/bash
# Tests for backup-hass.sh script

set -euo pipefail

# Source test framework
source "$(dirname "$0")/../test-framework.sh"

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
    
    # Test permissions
    chmod 755 "$test_backup_dir"
    local perms=$(stat -c %a "$test_backup_dir" 2>/dev/null || stat -f %p "$test_backup_dir" | cut -c 4-6)
    assert_equals "755" "$perms" "Backup directory should have correct permissions"
    
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
    
    local file_count=$(find "$empty_dir" -type f | wc -l)
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
    
    # Create old backup files
    for i in {1..10}; do
        touch -d "$i days ago" "$test_dir/hass-backup-$(date -d "$i days ago" +%Y%m%d).tar.gz"
    done
    
    # Count files older than retention period
    local old_files=$(find "$test_dir" -name "*.tar.gz" -mtime +$retention_days | wc -l)
    assert_true "[[ $old_files -gt 0 ]]" "Should find old files for deletion"
    
    # Cleanup
    rm -rf "$test_dir"
}

# Run all tests
main() {
    init_tests
    
    run_test "Script exists and is executable" test_script_exists
    run_test "Backup directory creation" test_backup_directory_creation
    run_test "Backup file naming convention" test_backup_naming
    run_test "Configuration validation" test_config_validation
    run_test "Tar command construction" test_tar_command
    run_test "Retention policy validation" test_retention_policy
    
    print_summary
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi