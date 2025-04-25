#!/bin/bash

# =============================================================================
# Network Configuration Test Script
# =============================================================================
#
# This script tests the network configuration modules to ensure they work
# correctly in different modes.
#
# Usage: ./test_network.sh
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Change to script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Source all network configurations
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

echo "=== Testing Base Network Configuration ==="
run_test "Default Configuration" '
    setup_network_config &&
    [[ $NETWORK_MODE == "LOCAL" ]] &&
    [[ $VM_SSH_PORT == "2222" ]] &&
    [[ $SSH_HOST == "localhost" ]]
' || true

echo -e "\n=== Testing Syzkaller Network Configuration ==="
run_test "Syzkaller Setup" '
    setup_syzkaller_network &&
    [[ $NETWORK_MODE == "SYZKALLER" ]] &&
    [[ -n $SYZKALLER_HTTP_PORT ]] &&
    [[ -n $SYZKALLER_RPC_PORT ]]
' || true

echo -e "\n=== Testing SyzGen Network Configuration ==="
run_test "SyzGen Setup" '
    setup_syzgen_network &&
    [[ $NETWORK_MODE == "SYZGEN" ]] &&
    [[ -n $SYZGEN_DEBUG_PORT ]] &&
    [[ -n $SYZGEN_MONITOR_PORT ]]
' || true

echo -e "\n=== Testing Port Allocation ==="
run_test "Unique Ports" '
    setup_syzkaller_network
    http_port=$SYZKALLER_HTTP_PORT
    rpc_port=$SYZKALLER_RPC_PORT
    setup_syzgen_network
    debug_port=$SYZGEN_DEBUG_PORT
    monitor_port=$SYZGEN_MONITOR_PORT
    [[ $http_port != $rpc_port ]] &&
    [[ $debug_port != $monitor_port ]] &&
    [[ $http_port != $debug_port ]] &&
    [[ $rpc_port != $monitor_port ]]
' || true

# Print summary
echo -e "\n=== Test Summary ==="
echo "Tests Run: $TESTS_RUN"
echo "Tests Passed: $TESTS_PASSED"

# Exit with success only if all tests passed
[[ $TESTS_RUN -eq $TESTS_PASSED ]] || exit 1 