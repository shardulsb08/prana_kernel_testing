#!/bin/bash

# =============================================================================
# Common Configuration Test Script
# =============================================================================
#
# This script tests the common configuration module to ensure it works correctly.
#
# Usage: ./test_common.sh
# =============================================================================

# Change to script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Source common configuration
source ./common.sh

# Colors for test output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_PASSED=0

# Test function
run_test() {
    local name=$1
    local cmd=$2
    
    ((TESTS_RUN++))
    echo -n "Testing $name... "
    
    # Run the test command in a subshell to avoid affecting the main shell
    if (set -e; eval "$cmd") > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
}

echo "=== Testing Common Configuration ==="

# Test project root
run_test "Project Root" '
    [[ -n "$PROJECT_ROOT" ]] &&
    [[ -d "$PROJECT_ROOT" ]] &&
    [[ -f "$PROJECT_ROOT/infrastructure/config-system/common.sh" ]]
' || true

# Test mode validation
run_test "Mode Validation" '
    validate_mode "LOCAL" &&
    validate_mode "SYZKALLER" &&
    validate_mode "SYZGEN" &&
    ! validate_mode "INVALID" 2>/dev/null
' || true

# Test quiet mode
run_test "Quiet Mode" '
    ! is_quiet &&
    QUIET=1 is_quiet
' || true

# Test config directory
run_test "Config Directory" '
    [[ "$(get_config_dir network)" == "$PROJECT_ROOT/configs/network" ]] &&
    [[ "$(get_config_dir kernel)" == "$PROJECT_ROOT/configs/kernel" ]]
' || true

# Test logging functions
run_test "Logging Functions" '
    log "Test message" > /dev/null &&
    log_error "Test error" 2> /dev/null &&
    log_warning "Test warning" 2> /dev/null &&
    log_info "Test info" > /dev/null
' || true

# Print summary
echo -e "\n=== Test Summary ==="
echo "Tests Run: $TESTS_RUN"
echo "Tests Passed: $TESTS_PASSED"

# Exit with success only if all tests passed
[[ $TESTS_RUN -eq $TESTS_PASSED ]] || exit 1 