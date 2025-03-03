#!/bin/bash
set -euo pipefail

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source common functions and variables
source "$SCRIPT_DIR/common.sh"

# Configuration
TEST_CONFIG="$SCRIPT_DIR/host_drive/tests/test_config.txt"  # Path on host (adjusted for VM context)
TESTS_DIR="$SCRIPT_DIR/host_drive/tests" # Path on host where tests/ is present

# Helper function for logging
log() {
    echo -e "\n\e[32m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

# Check if SSH is available (already running in VM, but kept for standalone use)
log "Checking SSH availability..."
for i in {1..30}; do
    if nc -z localhost $VM_SSH_PORT; then
        log "SSH is available."
        break
    fi
    sleep 10
done
if ! nc -z localhost $VM_SSH_PORT; then
    log "Error: SSH is not available. Is the VM running?"
    exit 1
fi

# Check if the test directory is mounted
if [ ! -d "$TESTS_DIR" ]; then
    log "Error: Test directory '$TESTS_DIR' not mounted in VM."
    exit 1
fi

# Read and execute tests
if [ ! -f "$TEST_CONFIG" ]; then
    log "Error: Test configuration file '$TEST_CONFIG' not found on host."
    exit 1
fi

# Parse each line of test_config.txt, allowing optional parameters
while IFS=' ' read -r test_name param; do
    if [ -z "$test_name" ]; then
        continue  # Skip empty lines
    fi
    log "Running test: $test_name${param:+ with parameter $param}"
    vm_ssh --script <<EOF
set -euo pipefail
case "$test_name" in
    smoke_test)
        chmod +x $TESTS_DIR/001_kernel_smoke_test.sh
        $TESTS_DIR/001_kernel_smoke_test.sh${param:+ "$param"}
        ;;
    *)
        echo "Unknown test: $test_name"
        exit 1
        ;;
esac
EOF
    if [ $? -ne 0 ]; then
        log "Test '$test_name' failed."
        exit 1
    fi
done < "$TEST_CONFIG_VM"

log "All selected tests passed."
