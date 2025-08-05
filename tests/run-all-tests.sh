#!/bin/bash
# Main test runner for Home Assistant bootc project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test categories
declare -a TEST_CATEGORIES=("scripts" "integration")
declare -A TEST_RESULTS

# Print header
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Home Assistant bootc Test Suite           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Running tests from: $SCRIPT_DIR"
    echo "Project root: $PROJECT_ROOT"
    echo ""
}

# Run tests in a category
run_category_tests() {
    local category="$1"
    local category_dir="$SCRIPT_DIR/$category"
    
    echo -e "\n${BLUE}═══ Running $category tests ═══${NC}"
    
    if [[ ! -d "$category_dir" ]]; then
        echo -e "${YELLOW}Warning: Category directory not found: $category_dir${NC}"
        return 1
    fi
    
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$category_dir" -name "test-*.sh" -type f -print0 | sort -z)
    
    if [[ ${#test_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No test files found in $category${NC}"
        return 0
    fi
    
    local category_passed=0
    local category_failed=0
    
    for test_file in "${test_files[@]}"; do
        local test_name=$(basename "$test_file" .sh)
        echo -e "\n${PURPLE}Running: $test_name${NC}"
        echo -e "${PURPLE}────────────────────────────────${NC}"
        
        if bash "$test_file"; then
            category_passed=$((category_passed + 1))
            TEST_RESULTS["$category/$test_name"]="PASSED"
        else
            category_failed=$((category_failed + 1))
            TEST_RESULTS["$category/$test_name"]="FAILED"
        fi
    done
    
    echo -e "\n${BLUE}Category Summary ($category):${NC}"
    echo -e "  Passed: ${GREEN}$category_passed${NC}"
    echo -e "  Failed: ${RED}$category_failed${NC}"
    
    return $category_failed
}

# Print final summary
print_final_summary() {
    echo -e "\n${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              FINAL TEST SUMMARY                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
    
    local total_passed=0
    local total_failed=0
    
    for test in "${!TEST_RESULTS[@]}"; do
        if [[ "${TEST_RESULTS[$test]}" == "PASSED" ]]; then
            echo -e "${GREEN}✓ $test${NC}"
            total_passed=$((total_passed + 1))
        else
            echo -e "${RED}✗ $test${NC}"
            total_failed=$((total_failed + 1))
        fi
    done | sort
    
    echo -e "\n${BLUE}Total Results:${NC}"
    echo -e "  Tests Run:    $((total_passed + total_failed))"
    echo -e "  ${GREEN}Passed:      $total_passed${NC}"
    echo -e "  ${RED}Failed:      $total_failed${NC}"
    
    if [[ $total_failed -eq 0 ]]; then
        echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           ALL TESTS PASSED! 🎉                 ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
        return 0
    else
        echo -e "\n${RED}╔════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║           SOME TESTS FAILED! ❌                ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════╝${NC}"
        return 1
    fi
}

# Main function
main() {
    print_header
    
    # Make test scripts executable
    find "$SCRIPT_DIR" -name "*.sh" -type f -exec chmod +x {} \;
    
    local exit_code=0
    
    # Run tests for each category
    for category in "${TEST_CATEGORIES[@]}"; do
        if ! run_category_tests "$category"; then
            exit_code=1
        fi
    done
    
    # Print final summary
    print_final_summary || exit_code=$?
    
    exit $exit_code
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --category)
            TEST_CATEGORIES=("$2")
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --category CATEGORY  Run only tests in specified category"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main