#!/bin/bash
set -euo pipefail

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source common functions and variables (which includes all configurations)
source "$SCRIPT_DIR/common.sh"

# Configuration
TEST_CONFIG="$SCRIPT_DIR/host_drive/tests/test_config.txt"  # Path on host (adjusted for VM context)
TESTS_DIR="$SCRIPT_DIR/host_drive/tests" # Path on host where tests/ is present
VM_TESTS_DIR="/home/user/host_drive/tests" # Path on host where tests/ is present

# Helper function for logging
log() {
    echo -e "\n\e[32m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

# Parse test mode from arguments
TEST_MODE="LOCAL"
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            TEST_MODE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--mode LOCAL|SYZKALLER|SYZGEN]"
            exit 1
            ;;
    esac
done

# Configure network and kernel based on mode
case $TEST_MODE in
    "SYZKALLER")
        setup_syzkaller_network
        setup_syzkaller_kernel
        ;;
    "SYZGEN")
        setup_syzgen_network
        setup_syzgen_kernel
        ;;
    "LOCAL")
        setup_network_config "LOCAL"
        setup_kernel_config "LOCAL"
        ;;
    *)
        echo "Invalid test mode: $TEST_MODE"
        echo "Valid modes: LOCAL, SYZKALLER, SYZGEN"
        exit 1
        ;;
esac

# Check if SSH is available
log "Checking SSH availability..."
for i in {1..30}; do
    if nc -z "$SSH_HOST" "$VM_SSH_PORT"; then
        log "SSH is available."
        break
    fi
    sleep 10
done
if ! nc -z "$SSH_HOST" "$VM_SSH_PORT"; then
    log "Error: SSH is not available. Is the VM running?"
    exit 1
fi

# Check if the test directory exists
if [ ! -d "$TESTS_DIR" ]; then
    log "Error: Test directory '$TESTS_DIR' not mounted in VM."
    exit 1
fi

# Read and execute tests
if [ ! -f "$TEST_CONFIG" ]; then
    log "Error: Test configuration file '$TEST_CONFIG' not found on host."
    exit 1
fi

# VM-based tests (safer tests that run inside VM)
while IFS=' ' read -r test_name param; do
    if [ -z "$test_name" ]; then
        continue  # Skip empty lines
    fi
    vm_ssh --script <<EOF
set -euo pipefail
case "$test_name" in
    smoke_test)
        log() {
            echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
        }
        log "Running test: $test_name${param:+ with parameter $param}"
        chmod +x $VM_TESTS_DIR/001_kernel_smoke_test.sh
        $VM_TESTS_DIR/001_kernel_smoke_test.sh${param:+ "$param"}
        ;;
esac
EOF
    if [ $? -ne 0 ]; then
        log "Test '$test_name' failed."
        exit 1
    fi
done < "$TEST_CONFIG"

# Host-based tests (tests that need to run from host)
while IFS=' ' read -r test_name param; do
    if [ -z "$test_name" ]; then
        continue  # Skip empty lines
    fi
set -euo pipefail
case "$test_name" in
    syzkaller)
        chmod +x $TESTS_DIR/002_run_syzkaller.sh
        chmod +x $TESTS_DIR/syzkaller/setup_syzkaller.sh

        # Use kernel configuration paths
        KVER="$(<"$KERNEL_OUT/kver.txt")"
        ARTIFACT_DIR="$KERNEL_OUT"

        if [ ! -f "${ARTIFACT_DIR}/${KERNEL_BUILD_TARGET}" ]; then
            log "Error: Kernel image not found at ${ARTIFACT_DIR}/${KERNEL_BUILD_TARGET}"
            exit 1
        fi

        "$TESTS_DIR/syzkaller/setup_syzkaller.sh"
        mkdir -p "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/"
        cp -r "${ARTIFACT_DIR}" "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/"
        cp "${KERNEL_ROOT}/vmlinux" "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/"

        # Mount kernel build dir to VM
        log "Mounting kernel build dir for Syzkaller access..."
        vm_ssh -- script <<'EOF'
            set -euo pipefail
            sudo mkdir -p /host_out
            sudo mount -t 9p -o trans=virtio host_out /host_out
            KVER=$(cat /host_out/kver.txt)
            ln -sfn /host_out/linux /home/user/host_drive/tests/syzkaller/kernel_build/v${KVER}/v${KVER}/
            exit # Ensure SSH session exits
EOF

        # Prepare VM for secure SSH access
        vm_ssh -- script <<'SECURE_SSH'
set -euo pipefail

log() {
    echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

# Ensure SSH server is installed
sudo dnf -y update
sudo dnf -y install openssh-server

# Configure SSH to allow root login with keys only
sudo sed -i 's/#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sudo sed -i 's/PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

# Restart SSH service to apply changes
sudo systemctl restart sshd
SECURE_SSH

        echo "Starting Syzkaller..."
        $TESTS_DIR/002_run_syzkaller.sh ${param:+ "$param"} --kernel-dir "$KVER"
        ;;
esac
    if [ $? -ne 0 ]; then
        log "Test '$test_name' failed."
        exit 1
    fi
done < "$TEST_CONFIG"

log "All selected tests passed."
