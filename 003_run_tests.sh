#!/bin/bash
set -euo pipefail

# Configuration
VM_SSH_USER="user"          # Adjust to your VM's SSH user
VM_SSH_PORT=2222            # Adjust to your VM's SSH port
TEST_CONFIG="tests/test_config.txt"  # Path on host
TESTS_DIR="/host_tests"     # Path in VM where tests/ is mounted

# Helper function for logging
log() {
    echo -e "\n\e[32m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

# Check if SSH is available
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

# Read test config
if [ ! -f "$TEST_CONFIG" ]; then
    log "Error: Test configuration file '$TEST_CONFIG' not found."
    exit 1
fi

tests_to_run=$(cat "$TEST_CONFIG")

# Run tests via SSH
for test_name in $tests_to_run; do
    log "Running test: $test_name"
    ssh -o StrictHostKeyChecking=no -p $VM_SSH_PORT $VM_SSH_USER@localhost <<EOF
set -euo pipefail
case "$test_name" in
    smoke_test)
        chmod +x $TESTS_DIR/001_kernel_smoke_test.sh
        $TESTS_DIR/001_kernel_smoke_test.sh
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
done

log "All selected tests passed."
