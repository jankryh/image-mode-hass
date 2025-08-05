#!/bin/bash
# Test Framework for Home Assistant bootc project
# Provides basic testing functionality for bash scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test results array
declare -a TEST_RESULTS

# Initialize test environment
init_tests() {
    echo -e "${BLUE}=== Test Framework Initialized ===${NC}"
    TESTS_RUN=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0
    TEST_RESULTS=()
}

# Run a test
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    echo -e "\n${BLUE}Running test:${NC} $test_name"
    TESTS_RUN=$((TESTS_RUN + 1))
    
    # Create temporary test directory
    local test_dir="/tmp/hass-test-$$"
    mkdir -p "$test_dir"
    
    # Run test in subshell to isolate it
    if (
        cd "$test_dir"
        set +e
        $test_function
    ); then
        echo -e "${GREEN}✓ PASSED${NC}: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        TEST_RESULTS+=("PASS: $test_name")
    else
        echo -e "${RED}✗ FAILED${NC}: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TEST_RESULTS+=("FAIL: $test_name")
    fi
    
    # Cleanup
    rm -rf "$test_dir"
}

# Skip a test
skip_test() {
    local test_name="$1"
    local reason="${2:-No reason provided}"
    
    echo -e "\n${YELLOW}Skipping test:${NC} $test_name"
    echo -e "${YELLOW}Reason:${NC} $reason"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    TEST_RESULTS+=("SKIP: $test_name - $reason")
}

# Assert functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "Expected: '$expected'"
        echo -e "Actual:   '$actual'"
        return 1
    fi
}

assert_not_equals() {
    local unexpected="$1"
    local actual="$2"
    local message="${3:-Values should not be equal}"
    
    if [[ "$unexpected" == "$actual" ]]; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "Unexpected value: '$actual'"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local message="${2:-Condition should be true}"
    
    if ! eval "$condition"; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "Condition: $condition"
        return 1
    fi
}

assert_false() {
    local condition="$1"
    local message="${2:-Condition should be false}"
    
    if eval "$condition"; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "Condition: $condition"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"
    
    if [[ ! -f "$file" ]]; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "File not found: $file"
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist}"
    
    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "Directory not found: $dir"
        return 1
    fi
}

assert_command_exists() {
    local cmd="$1"
    local message="${2:-Command should exist}"
    
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "Command not found: $cmd"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"
    
    if [[ ! "$haystack" == *"$needle"* ]]; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "String: '$haystack'"
        echo -e "Should contain: '$needle'"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Exit code should match}"
    
    if [[ "$expected" -ne "$actual" ]]; then
        echo -e "${RED}Assertion failed:${NC} $message"
        echo -e "Expected exit code: $expected"
        echo -e "Actual exit code: $actual"
        return 1
    fi
}

# Print test summary
print_summary() {
    echo -e "\n${BLUE}=== Test Summary ===${NC}"
    echo -e "Tests run:     $TESTS_RUN"
    echo -e "${GREEN}Tests passed:  $TESTS_PASSED${NC}"
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Tests failed:  $TESTS_FAILED${NC}"
    else
        echo -e "Tests failed:  $TESTS_FAILED"
    fi
    if [[ $TESTS_SKIPPED -gt 0 ]]; then
        echo -e "${YELLOW}Tests skipped: $TESTS_SKIPPED${NC}"
    else
        echo -e "Tests skipped: $TESTS_SKIPPED"
    fi
    
    echo -e "\n${BLUE}=== Test Results ===${NC}"
    for result in "${TEST_RESULTS[@]}"; do
        if [[ "$result" == PASS:* ]]; then
            echo -e "${GREEN}$result${NC}"
        elif [[ "$result" == FAIL:* ]]; then
            echo -e "${RED}$result${NC}"
        elif [[ "$result" == SKIP:* ]]; then
            echo -e "${YELLOW}$result${NC}"
        else
            echo "$result"
        fi
    done
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "\n${RED}TESTS FAILED!${NC}"
        return 1
    else
        echo -e "\n${GREEN}ALL TESTS PASSED!${NC}"
        return 0
    fi
}

# Export all functions
export -f init_tests run_test skip_test print_summary
export -f assert_equals assert_not_equals assert_true assert_false
export -f assert_file_exists assert_dir_exists assert_command_exists
export -f assert_contains assert_exit_code