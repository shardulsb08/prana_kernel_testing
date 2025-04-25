#!/bin/bash

# =============================================================================
# Syzkaller Network Configuration Test Suite
# =============================================================================
#
# This script tests the Syzkaller network configuration module.
#
# Usage:
#   ./test_syzkaller.sh
#
# Features:
# - Tests Syzkaller network configuration setup
# - Validates port assignments
# - Checks mode switching
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Source the Syzkaller network configuration
source "$(dirname "${BASH_SOURCE[0]}")/syzkaller.sh"

# Test helper functions
test_start() {
    echo "Running test: $1"
}

test_pass() {
    echo "✓ Test passed: $1"
}

test_fail() {
    echo "✗ Test failed: $1"
    exit 1
}

# Test 1: Basic Syzkaller network setup
test_start "Basic Syzkaller network setup"
setup_syzkaller_network
[[ -n "${SYZKALLER_HTTP_PORT:-}" ]] || test_fail "SYZKALLER_HTTP_PORT not set"
[[ -n "${SYZKALLER_RPC_PORT:-}" ]] || test_fail "SYZKALLER_RPC_PORT not set"
test_pass "Basic Syzkaller network setup"

# Test 2: Network mode switching
test_start "Network mode switching"
setup_syzkaller_network
if ! is_syzkaller_mode; then
    test_fail "Network mode not set to SYZKALLER"
fi
test_pass "Network mode switching"

# Test 3: Port configuration
test_start "Port configuration"
[[ $SYZKALLER_HTTP_PORT -gt 1024 ]] || test_fail "Invalid HTTP port"
[[ $SYZKALLER_RPC_PORT -gt 1024 ]] || test_fail "Invalid RPC port"
[[ $SYZKALLER_HTTP_PORT -ne $SYZKALLER_RPC_PORT ]] || test_fail "HTTP and RPC ports are the same"
test_pass "Port configuration"

# Test 4: Configuration retrieval
test_start "Configuration retrieval"
config_output=$(get_syzkaller_network_config)
[[ "$config_output" == *"HTTP Port"* ]] || test_fail "HTTP port not in config output"
[[ "$config_output" == *"RPC Port"* ]] || test_fail "RPC port not in config output"
test_pass "Configuration retrieval"

echo "All tests passed successfully!" 