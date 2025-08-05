#!/bin/bash
# Example script demonstrating error handling and logging
# This shows how to use the new libraries in scripts

set -euo pipefail

# Load common libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Initialize script
init_script "example"

# Function demonstrating various features
main() {
    log_section "Demonstrating Logging Features"
    
    # Different log levels
    debug "This is a debug message (only shown with --verbose)"
    info "This is an info message"
    warn "This is a warning message"
    success "This is a success message"
    
    # Progress steps
    log_step 1 3 "Checking requirements"
    require_commands bash grep awk
    success "All required commands found"
    
    log_step 2 3 "Validating configuration"
    # Validate some values
    if validate_port "$HASS_PORT" "Home Assistant port"; then
        success "Port validation passed"
    fi
    
    log_step 3 3 "Performing safe operations"
    # Safe command execution with retry
    safe_exec 3 2 ls -la "$HASS_CONFIG_DIR" || warn "Failed to list config directory"
    
    # Check disk space
    if check_disk_space "/" 100; then
        success "Sufficient disk space available"
    fi
    
    # Timeout example
    info "Running command with timeout"
    if with_timeout 5 sleep 2; then
        success "Command completed within timeout"
    fi
    
    # Progress indicator
    (sleep 3) &
    show_progress "Processing data" $!
    
    # Error handling example
    info "Demonstrating error recovery"
    disable_strict_mode
    false || warn "Command failed but we recovered"
    enable_strict_mode
    
    log_section "Script Completed"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo "Usage: $0 [--verbose] [--log-file FILE]"
            echo "Example script demonstrating error handling and logging"
            exit 0
            ;;
        *)
            # Let parse_log_args handle common arguments
            ARGS=$(parse_log_args "$@")
            set -- $ARGS
            if [[ $# -gt 0 ]]; then
                error "Unknown argument: $1"
                exit $ERR_INVALID_ARGS
            fi
            break
            ;;
    esac
done

# Run main function
main

# Cleanup is handled automatically by trap in common.sh