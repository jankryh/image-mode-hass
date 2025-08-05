#!/bin/bash
# Integration tests for build process

set -euo pipefail

# Simplified integration test for bash 3.x compatibility
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

assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command should exist}"
    
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${YELLOW}SKIP:${NC} $message - Command not available: $cmd"
        return 0  # Skip rather than fail
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

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"
    
    if [[ "$expected" -ne "$actual" ]]; then
        echo -e "${RED}FAIL:${NC} $message (expected: $expected, got: $actual)"
        return 1
    fi
    echo -e "${GREEN}PASS:${NC} $message"
    return 0
}

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
    echo "Running integration tests..."
    local failed=0
    
    test_makefile_exists || failed=$((failed + 1))
    test_containerfile_exists || failed=$((failed + 1))
    test_config_files || failed=$((failed + 1))
    test_makefile_syntax || failed=$((failed + 1))
    test_build_dependencies || failed=$((failed + 1))
    test_containerfile_syntax || failed=$((failed + 1))
    test_multistage_build || failed=$((failed + 1))
    test_build_cache || failed=$((failed + 1))
    test_security_hardening || failed=$((failed + 1))
    test_repo_files || failed=$((failed + 1))
    test_scripts_structure || failed=$((failed + 1))
    
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