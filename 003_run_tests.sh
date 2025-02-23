#!/bin/bash
set -euo pipefail

# Configuration
VM_SSH_USER="user"          # Adjust to your VM's SSH user
VM_SSH_PORT=2222            # Adjust to your VM's SSH port
TEST_CONFIG="host_drive/tests/test_config.txt"  # Path on host (adjusted for VM context)
TESTS_DIR="/home/user/host_drive/tests" # Path in VM where tests/ is mounted

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

# Read test config from the VM's mounted path
TEST_CONFIG_VM="/home/user/$TEST_CONFIG"
if [ ! -f "$TEST_CONFIG_VM" ]; then
    log "Error: Test configuration file '$TEST_CONFIG_VM' not found in VM."
    exit 1
fi

# Parse each line of test_config.txt, allowing optional parameters
while IFS=' ' read -r test_name param; do
    if [ -z "$test_name" ]; then
        continue  # Skip empty lines
    fi
    log "Running test: $test_name${param:+ with parameter $param}"
    ssh -o StrictHostKeyChecking=no -p $VM_SSH_PORT $VM_SSH_USER@localhost <<EOF
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
