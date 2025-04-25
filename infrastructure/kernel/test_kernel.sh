#!/bin/bash

# =============================================================================
# Kernel Configuration Test Script
# =============================================================================
#
# This script tests the kernel configuration modules to ensure they work
# correctly in different modes.
#
# Usage: ./test_kernel.sh
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Change to script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Source all kernel configurations
source ./config.sh
source ./syzkaller.sh
source ./syzgen.sh

# Colors for output
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

echo "=== Testing Base Kernel Configuration ==="
run_test "Default Configuration" '
    setup_kernel_config &&
    [[ $KERNEL_MODE == "LOCAL" ]] &&
    [[ $KERNEL_CONFIG_FILE == "base/config-base" ]] &&
    [[ $KERNEL_BUILD_TARGET == "bzImage" ]]
' || true

echo -e "\n=== Testing Syzkaller Kernel Configuration ==="
run_test "Syzkaller Setup" '
    setup_syzkaller_kernel &&
    [[ $KERNEL_MODE == "SYZKALLER" ]] &&
    [[ $KERNEL_CONFIG_FILE == "syzkaller/config-syzkaller" ]] &&
    [[ -n $KERNEL_CMDLINE ]] &&
    [[ $KERNEL_CMDLINE == *"console=ttyS0"* ]] &&
    [[ $KERNEL_CMDLINE == *"debug=1"* ]]
' || true

echo -e "\n=== Testing SyzGen Kernel Configuration ==="
run_test "SyzGen Setup" '
    setup_syzgen_kernel &&
    [[ $KERNEL_MODE == "SYZGEN" ]] &&
    [[ $KERNEL_CONFIG_FILE == "syzgen/config-syzgen" ]] &&
    [[ -n $KERNEL_CMDLINE ]] &&
    [[ $KERNEL_CMDLINE == *"console=ttyS0"* ]] &&
    [[ $KERNEL_CMDLINE == *"kasan=1"* ]]
' || true

echo -e "\n=== Testing Configuration Switching ==="
run_test "Mode Switching" '
    setup_kernel_config "LOCAL" &&
    [[ $KERNEL_MODE == "LOCAL" ]] &&
    setup_syzkaller_kernel &&
    [[ $KERNEL_MODE == "SYZKALLER" ]] &&
    setup_syzgen_kernel &&
    [[ $KERNEL_MODE == "SYZGEN" ]]
' || true

echo -e "\n=== Testing Mode Detection ==="
run_test "Current Mode Detection" '
    setup_kernel_config "LOCAL" &&
    [[ "$(get_current_kernel_mode)" == "LOCAL" ]] &&
    setup_syzkaller_kernel &&
    [[ "$(get_current_kernel_mode)" == "SYZKALLER" ]] &&
    is_syzkaller_kernel_mode
' || true

run_test "Invalid Mode Detection" '
    KERNEL_MODE="INVALID" &&
    ! get_current_kernel_mode &&
    KERNEL_MODE="SYZKALLER" &&
    is_syzkaller_kernel_mode
' || true

# Print summary
echo -e "\n=== Test Summary ==="
echo "Tests Run: $TESTS_RUN"
echo "Tests Passed: $TESTS_PASSED"

# Exit with success only if all tests passed
[[ $TESTS_RUN -eq $TESTS_PASSED ]] || exit 1 