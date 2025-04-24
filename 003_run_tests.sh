#!/bin/bash

# =============================================================================
# Kernel Test Execution Script
# =============================================================================
#
# This script orchestrates the execution of kernel tests in both VM and host
# environments. It executes tests in two phases:
# 1. VM-based tests that are safer to run (less likely to crash VM)
# 2. Host-based tests that may affect VM stability
#
# Features:
# - Two-phase test execution (VM-safe tests first, then host tests)
# - Automated test environment setup
# - SSH connectivity verification
# - Test directory mounting verification
# - Syzkaller fuzzing test support
#
# Usage:
#   ./003_run_tests.sh
#
# Configuration:
#   Tests are configured in: ./host_drive/tests/test_config.txt
#   Format: <test_name> [optional_parameter]
#
# Available Tests:
#   - smoke_test: Basic kernel functionality test (runs in VM)
#   - syzkaller: Kernel fuzzing framework (runs from host)
#     - Requires kernel artifacts in OUT_DIR
#     - Sets up VM for syzkaller access
#     - Configures secure SSH access
#
# Prerequisites:
#   - VM must be running (launched via 002_launch_vm.sh)
#   - Test configuration file must exist
#   - Required test directories must be mounted
#   - SSH access must be available on VM_SSH_PORT
#
# Environment:
#   SCRIPT_DIR    - Script's directory path
#   TEST_CONFIG   - Path to test configuration file
#   TESTS_DIR     - Host path to tests directory
#   VM_TESTS_DIR  - VM path to tests directory
#   OUT_DIR       - Output directory for kernel artifacts
#
# Exit Codes:
#   0 - All tests passed
#   1 - Test failure or environment setup error
#
# =============================================================================

set -euo pipefail

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source common functions and variables
source "$SCRIPT_DIR/common.sh"

# Configuration
TEST_CONFIG="$SCRIPT_DIR/host_drive/tests/test_config.txt"  # Path on host (adjusted for VM context)
TESTS_DIR="$SCRIPT_DIR/host_drive/tests" # Path on host where tests/ is present
VM_TESTS_DIR="/home/user/host_drive/tests" # Path on host where tests/ is present

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

# Add tests with lower chances of crash (loss of VM access) in the first
# loop, since it runs inside the VM. The others, add them in the second
# loop. This runs from the host machine.
# Fyi, if we exchange loop positions, we risk skipping the tests inside
# VM, even though they could have been run beforehand successfully.

# Parse each line of test_config.txt from VM, allowing optional parameters
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

# Parse each line of test_config.txt from host, allowing optional parameters
while IFS=' ' read -r test_name param; do
    if [ -z "$test_name" ]; then
        continue  # Skip empty lines
    fi
set -euo pipefail
case "$test_name" in
    syzkaller)
        chmod +x $TESTS_DIR/002_run_syzkaller.sh
        chmod +x $TESTS_DIR/syzkaller/setup_syzkaller.sh
        KVER="$(<./container_kernel_workspace/out/kver.txt)"
        ARTIFACT_DIR="$OUT_DIR/kernel_artifacts/v${KVER}" 
        if [ ! -f "${ARTIFACT_DIR}/vmlinuz-${KVER}" ]; then
            log "Error: Kernel image not found at ${ARTIFACT_DIR}/bzImage-custom"
            exit 1
        fi
        "$TESTS_DIR/syzkaller/setup_syzkaller.sh"
        mkdir -p "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/"
        cp -r "${ARTIFACT_DIR}" "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/"
        cp "${OUT_DIR}/../linux/vmlinux" "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/"
	# Mount kernel build dir to VM
	log "Mounting kernel build dir for Syzkaller access..."
	vm_ssh -- script <<'EOF'
            set -euo pipefail
            sudo mkdir -p /host_out
            sudo mount -t 9p -o trans=virtio host_out /host_out
            KVER=$(cat /host_out/out/kver.txt)
#            ln -s "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/linux" /host_out/linux
            ln -sfn /host_out/linux /home/user/host_drive/tests/syzkaller/kernel_build/v${KVER}/v${KVER}/
            exit # Ensure SSH session exits
EOF
#        cp -r "${OUT_DIR}/../linux" "$TESTS_DIR/syzkaller/kernel_build/v${KVER}/"

#Prepare VM for secure SSH access
        vm_ssh -- script <<SECURE_SSH
set -euo pipefail

#!/bin/bash

log() {
    echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}
# Ensure SSH server is installed
sudo dnf -y update
sudo dnf -y install openssh-server

## Create .ssh directory for root if it doesn't exist
#sudo mkdir -p /root/.ssh
#sudo chmod 700 /root/.ssh
#
## Add the public key to authorized_keys (replace <PUBLIC_KEY> with the key from Step 1)
#sudo echo "<PUBLIC_KEY>" >> /root/.ssh/authorized_keys
#sudo chmod 600 /root/.ssh/authorized_keys
#sudo chown root:root /root/.ssh /root/.ssh/authorized_keys

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
