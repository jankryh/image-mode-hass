# Test Suite for Home Assistant bootc

This directory contains the automated test suite for the Home Assistant bootc project.

## 📁 Structure

```
tests/
├── test-framework.sh      # Core testing framework with assertions
├── run-all-tests.sh       # Main test runner
├── scripts/               # Unit tests for scripts
│   ├── test-health-check.sh
│   ├── test-backup-hass.sh
│   └── ...
└── integration/           # Integration tests
    ├── test-build.sh
    └── ...
```

## 🚀 Running Tests

### Run all tests
```bash
make test
# or
./tests/run-all-tests.sh
```

### Run specific category
```bash
# Script tests only
make test-scripts

# Integration tests only
make test-integration
```

### Run individual test
```bash
./tests/scripts/test-health-check.sh
```

## 🧪 Test Framework

The test framework provides these assertion functions:

- `assert_equals` - Check if two values are equal
- `assert_not_equals` - Check if two values are not equal
- `assert_true` - Check if a condition is true
- `assert_false` - Check if a condition is false
- `assert_file_exists` - Check if a file exists
- `assert_dir_exists` - Check if a directory exists
- `assert_command_exists` - Check if a command is available
- `assert_contains` - Check if string contains substring
- `assert_exit_code` - Check command exit code

## ✍️ Writing Tests

### Example test file

```bash
#!/bin/bash
# Tests for my-script.sh

set -euo pipefail

# Source test framework
source "$(dirname "$0")/../test-framework.sh"

# Test function
test_example() {
    assert_equals "expected" "actual" "Values should match"
    assert_file_exists "/path/to/file" "File should exist"
}

# Main test runner
main() {
    init_tests
    
    run_test "Example test" test_example
    
    print_summary
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
```

### Best Practices

1. **Isolation**: Each test runs in its own temporary directory
2. **Independence**: Tests should not depend on each other
3. **Cleanup**: Always clean up temporary files
4. **Clear names**: Use descriptive test names
5. **Assertions**: Use appropriate assertions for clarity

## 🎯 Test Categories

### Script Tests (`tests/scripts/`)
- Unit tests for individual scripts
- Mock external dependencies
- Test specific functions and logic

### Integration Tests (`tests/integration/`)
- Test build process
- Validate configuration files
- Check system requirements
- Test component interactions

## 📊 Test Output

Tests produce colored output showing:
- ✓ PASSED (green) - Test succeeded
- ✗ FAILED (red) - Test failed
- ⚠ SKIPPED (yellow) - Test was skipped

Final summary shows:
- Total tests run
- Number passed/failed/skipped
- Overall pass/fail status

## 🔧 Continuous Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: make test
```

## 🐛 Debugging Tests

Enable verbose output:
```bash
VERBOSE=true ./tests/run-all-tests.sh
```

Run specific test with bash debugging:
```bash
bash -x ./tests/scripts/test-health-check.sh
```