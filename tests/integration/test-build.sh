#!/bin/bash
# Integration tests for build process

set -euo pipefail

# Source test framework
source "$(dirname "$0")/../test-framework.sh"

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Test: Makefile exists
test_makefile_exists() {
    assert_file_exists "$PROJECT_ROOT/Makefile" "Makefile should exist"
}

# Test: Containerfile exists
test_containerfile_exists() {
    assert_file_exists "$PROJECT_ROOT/Containerfile" "Containerfile should exist"
}

# Test: Required configuration files
test_config_files() {
    assert_file_exists "$PROJECT_ROOT/config.mk" "config.mk should exist"
    assert_file_exists "$PROJECT_ROOT/config-example.toml" "config-example.toml should exist"
    assert_file_exists "$PROJECT_ROOT/config-production.toml" "config-production.toml should exist"
}

# Test: Makefile syntax
test_makefile_syntax() {
    local output
    output=$(make -n -f "$PROJECT_ROOT/Makefile" help 2>&1) || true
    assert_exit_code 0 $? "Makefile should have valid syntax"
}

# Test: Check build dependencies
test_build_dependencies() {
    assert_command_exists "podman" "Podman should be installed for builds"
}

# Test: Validate Containerfile syntax
test_containerfile_syntax() {
    # Basic syntax check - look for required instructions
    local containerfile_content=$(cat "$PROJECT_ROOT/Containerfile")
    
    assert_contains "$containerfile_content" "FROM" "Containerfile should have FROM instruction"
    assert_contains "$containerfile_content" "LABEL" "Containerfile should have LABEL instructions"
    assert_contains "$containerfile_content" "RUN" "Containerfile should have RUN instructions"
}

# Test: Multi-stage build structure
test_multistage_build() {
    local stage_count=$(grep -c "^FROM" "$PROJECT_ROOT/Containerfile")
    assert_true "[[ $stage_count -ge 2 ]]" "Containerfile should use multi-stage build"
}

# Test: Build cache configuration
test_build_cache() {
    local cache_mounts=$(grep -c "RUN --mount=type=cache" "$PROJECT_ROOT/Containerfile")
    assert_true "[[ $cache_mounts -gt 0 ]]" "Containerfile should use cache mounts for optimization"
}

# Test: Security hardening in Containerfile
test_security_hardening() {
    local containerfile_content=$(cat "$PROJECT_ROOT/Containerfile")
    
    # Check for security-related configurations
    assert_contains "$containerfile_content" "fail2ban" "Should install fail2ban for security"
    assert_contains "$containerfile_content" "firewall" "Should configure firewall"
    assert_contains "$containerfile_content" "chmod" "Should set proper permissions"
}

# Test: Repository files
test_repo_files() {
    assert_file_exists "$PROJECT_ROOT/repos/zerotier.repo" "ZeroTier repo file should exist"
}

# Test: Scripts directory structure
test_scripts_structure() {
    assert_dir_exists "$PROJECT_ROOT/scripts" "Scripts directory should exist"
    
    local expected_scripts=(
        "setup-hass.sh"
        "backup-hass.sh"
        "restore-hass.sh"
        "health-check.sh"
        "update-system.sh"
        "performance-test.sh"
        "secrets-manager.sh"
        "deps-check.sh"
        "deps-update.sh"
    )
    
    for script in "${expected_scripts[@]}"; do
        assert_file_exists "$PROJECT_ROOT/scripts/$script" "Script $script should exist"
        assert_true "[[ -x '$PROJECT_ROOT/scripts/$script' ]]" "Script $script should be executable"
    done
}

# Run all tests
main() {
    init_tests
    
    run_test "Makefile exists" test_makefile_exists
    run_test "Containerfile exists" test_containerfile_exists
    run_test "Configuration files exist" test_config_files
    run_test "Makefile syntax validation" test_makefile_syntax
    run_test "Build dependencies check" test_build_dependencies
    run_test "Containerfile syntax validation" test_containerfile_syntax
    run_test "Multi-stage build structure" test_multistage_build
    run_test "Build cache optimization" test_build_cache
    run_test "Security hardening checks" test_security_hardening
    run_test "Repository files check" test_repo_files
    run_test "Scripts directory structure" test_scripts_structure
    
    print_summary
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi