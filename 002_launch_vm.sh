#!/bin/bash

# =============================================================================
# VM Launch and Management Script
# =============================================================================
#
# This script is part of a kernel testing framework that includes:
# 1. Kernel building (001_run_build_fedora.sh)
# 2. VM management (this script)
# 3. Test orchestration (003_run_tests.sh)
#
# Features:
# 1. VM Setup:
#    - Automated Fedora cloud image preparation
#    - Dynamic cloud-init configuration
#    - Shared directory mounting (/host_drive, /host_out)
#    - Resource allocation (CPU, memory, storage)
#
# 2. Network Configuration:
#    Supports three modes via SYZKALLER_SETUP:
#    a) SYZKALLER_LOCAL (Default):
#       - Port: 2222
#       - Host: localhost
#       - For local development/testing
#
#    b) SYZKALLER_SYZGEN:
#       - Port: 10021
#       - Host: 127.0.0.1
#       - For SyzGen++ integration
#
# 3. Kernel Installation (--install-kernel):
#    - Installs latest stable kernel
#    - Configures for debugging/testing
#    - Sets up syzkaller-specific features if needed
#    - Manages boot configuration (grub)
#    - Preserves kernel version info
#
# 4. Test Integration (--run-tests):
#    Executes tests in two phases:
#    a) VM-safe tests (run inside VM)
#       - Basic smoke tests
#       - Kernel feature validation
#    b) Host-based tests
#       - Syzkaller fuzzing
#       - Performance tests
#
# Usage:
#   ./002_launch_vm.sh [options]
#
# Options:
#   --install-kernel  Install and configure custom kernel
#   --run-tests      Execute configured test suites
#
# Prerequisites:
#   1. Build Environment:
#      - Docker with kernel build container
#      - QEMU for VM management
#      - Fedora cloud image
#
#   2. Test Environment:
#      - Syzkaller (auto-installed if needed)
#      - Test configurations in host_drive/tests/
#      - SSH key setup for automation
#
# Directory Structure:
#   /host_drive/     -> Mapped to VM:/home/user/host_drive/
#     tests/         -> Test suites and configurations
#       syzkaller/   -> Syzkaller test environment
#   /host_out/       -> Mapped to VM:/host_out/
#     kernel_artifacts/ -> Built kernel and modules
#
# Configuration Files:
#   - common.sh: Shared variables and functions
#   - test_config.txt: Test suite configuration
#   - kernel_syskaller.config: Syzkaller kernel options
#
# Environment Variables:
#   VM_MEMORY        Memory allocation (default: 20480MB)
#   VM_CPUS         CPU cores (default: 16)
#   SYZKALLER_SETUP Network mode (LOCAL/SYZGEN)
#   SSH_USER        VM username (default: user)
#   SSH_PASS        VM password (default: fedora)
#
# =============================================================================

set -euo pipefail

# Determine the script's directory for consistent file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source common functions and variables
source "$SCRIPT_DIR/common.sh"

# Source network configuration
source "$SCRIPT_DIR/infrastructure/network/config.sh"
source "$SCRIPT_DIR/infrastructure/network/syzkaller.sh"
source "$SCRIPT_DIR/infrastructure/network/syzgen.sh"

# Configure network based on SYZKALLER_SETUP
case "${SYZKALLER_SETUP:-LOCAL}" in
    "SYZGEN")
        setup_syzgen_network
        ;;
    "SYZKALLER")
        setup_syzkaller_network
        ;;
    *)
        setup_network_config "LOCAL"
        ;;
esac

# ========= Configuration Variables =========
VM_NAME="fedora-vm"
DISK_IMAGE="$SCRIPT_DIR/fedora_vm.qcow2"
CLOUD_IMAGE="$SCRIPT_DIR/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"

echo "Fetching latest Fedora release version"
# Fetch the latest Fedora release version
RELEASES=$(curl -sL https://download.fedoraproject.org/pub/fedora/linux/releases/ | grep -oP '(?<=<a href=")[0-9]+(?=/")')
LATEST_VERSION=$(echo "$RELEASES" | sort -n | tail -1)

# Fetch the latest cloud image for that version
IMAGES=$(curl -sL "https://download.fedoraproject.org/pub/fedora/linux/releases/${LATEST_VERSION}/Cloud/x86_64/images/" | grep -oP '(?<=<a href=")Fedora-Cloud-Base-(Generic-)?[0-9]+-[0-9.]+.x86_64.qcow2(?=")')
# Check if images were found
if [ -z "$IMAGES" ]; then
    echo "Error: No cloud images found for Fedora version $LATEST_VERSION."
    exit 1
fi
# Select the latest image
LATEST_IMAGE=$(echo "$IMAGES" | sort -V | tail -1)
CLOUD_IMAGE=$LATEST_IMAGE

# Construct the download URL
CLOUD_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/${LATEST_VERSION}/Cloud/x86_64/images/${LATEST_IMAGE}"

echo "Latest cloud image URL: $CLOUD_IMAGE_URL"

# Optionally, download the image
# wget "$CLOUD_IMAGE_URL" -O fedora-cloud-image.qcow2
CLOUD_INIT_ISO="$SCRIPT_DIR/seed.iso"
OUT_DIR="$SCRIPT_DIR/container_kernel_workspace/out"  # Directory with kernel artifacts
TEST_CONFIG="$SCRIPT_DIR/host_drive/tests/test_config.txt"  # Path to test config on host

# Syzkaller setup
TEST_DIR="$SCRIPT_DIR/host_drive/tests"
SYZKALLER_DIR="$TEST_DIR/syzkaller"
SYZKALLER_BIN_DIR="$TEST_DIR/syzkaller/syzkaller"
SYZKALLER_SSH_KEY="$SYZKALLER_DIR/.ssh/syzkaller_id_rsa"

# Generate SSH key if not exists
if [ ! -f "$SYZKALLER_SSH_KEY" ]; then
    mkdir -p "$SYZKALLER_DIR/.ssh"
    echo "Generating SSH key pair for Syzkaller..."
    ssh-keygen -t rsa -b 4096 -f "$SYZKALLER_SSH_KEY" -N ""
    chmod 600 "$SYZKALLER_SSH_KEY"
    # Output the public key to copy to the VM
    echo "Public key to add to VM's /root/.ssh/authorized_keys:"
    cat "${SYZKALLER_SSH_KEY}.pub"
fi
PUBLIC_KEY=$(cat "$SYZKALLER_SSH_KEY.pub")

# VM resources
RAM_MB=20480  # 20GB RAM
VCPUS=16      # 16 vCPUs
DISK_SIZE="35G"  # Disk image size

# ========= Helper Functions =========
# Empty right now.

# Install sshpass if not present
if ! command -v sshpass &> /dev/null; then
    log "Installing sshpass..."
    sudo apt-get update && sudo apt-get install -y sshpass || { log "Error: Failed to install sshpass"; exit 1; }
fi

# Example usage 1: Running a single command
# vm_ssh "echo 'Hello from the VM!'"

# Example usage 2: Running a multi-line script
# vm_ssh --script <<'EOF'
# echo "This is a multi-line script running on the VM"
# sudo some_command
# echo "Done!"
# EOF

# ========= Parse Command-Line Arguments =========
INSTALL_KERNEL=false
RUN_TESTS=false
for arg in "$@"; do
    if [ "$arg" == "--install-kernel" ]; then
        INSTALL_KERNEL=true
    elif [ "$arg" == "--run-tests" ]; then
        RUN_TESTS=true
    else
        log "Unknown argument: $arg"
        exit 1
    fi
done

# ========= 1. Prepare the VM Disk and Cloud Image =========
if [ ! -f "$DISK_IMAGE" ]; then
    log "Disk image '$DISK_IMAGE' not found; creating a new 35GB disk image..."
    if [ ! -f "$CLOUD_IMAGE" ]; then
        log "Downloading Fedora Cloud image..."
        wget -O "$CLOUD_IMAGE" "$CLOUD_IMAGE_URL" || { log "Error downloading Fedora Cloud image"; exit 1; }
    fi
    log "Creating qcow2 disk with backing file..."
    qemu-img create -f qcow2 -b "$CLOUD_IMAGE" -F qcow2 "$DISK_IMAGE" "$DISK_SIZE" || { log "Error creating disk image"; exit 1; }
fi

# ========= 2. Create Cloud-Init ISO =========
log "Checking if cloud-init configuration has changed..."

# Define paths for configuration files
USER_DATA_FILE="$SCRIPT_DIR/cloudinit/user-data"
META_DATA_FILE="$SCRIPT_DIR/cloudinit/meta-data"
CHECKSUM_FILE="$SCRIPT_DIR/cloud_init_checksums.txt"  # Store checksum outside cloudinit dir to persist after cleanup

# Create temporary configuration files
mkdir -p "$SCRIPT_DIR/cloudinit"

cat > "$USER_DATA_FILE" <<EOF
#cloud-config
#Auto-generated from 002_launch_vm.sh
users:
  - name: ${SSH_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    shell: /bin/bash
    lock_passwd: false
    passwd: $(openssl passwd -6 ${SSH_PASS})
    ssh_authorized_keys:
      - "$PUBLIC_KEY"
ssh_pwauth: True
packages:
  - stress-ng
runcmd:
  - mkdir -p /root/.ssh
  - cp "/home/${SSH_USER}/.ssh/authorized_keys" /root/.ssh/authorized_keys
  - chown root:root /root/.ssh/authorized_keys
  - chmod 600 /root/.ssh/authorized_keys
EOF

cat > "$META_DATA_FILE" <<EOF
#Auto-generated from 002_launch_vm.sh
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

# Calculate current checksum of configuration files
CURRENT_CHECKSUM=$(sha256sum "$USER_DATA_FILE" "$META_DATA_FILE" | sha256sum | cut -d' ' -f1)

# Check if checksum file exists and compare
if [ -f "$CHECKSUM_FILE" ]; then
    STORED_CHECKSUM=$(cat "$CHECKSUM_FILE")
    if [ "$CURRENT_CHECKSUM" == "$STORED_CHECKSUM" ]; then
        log "No changes detected in cloud-init configuration. Using existing seed.iso."
    else
        log "Changes detected in cloud-init configuration. Regenerating seed.iso..."
        genisoimage -output "${CLOUD_INIT_ISO}" -volid cidata -joliet -rock "$USER_DATA_FILE" "$META_DATA_FILE" \
            || { log "Error creating cloud-init ISO"; exit 1; }
        echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"
    fi
else
    log "No previous checksum found. Generating seed.iso..."
    genisoimage -output "${CLOUD_INIT_ISO}" -volid cidata -joliet -rock "$USER_DATA_FILE" "$META_DATA_FILE" \
        || { log "Error creating cloud-init ISO"; exit 1; }
    echo "$CURRENT_CHECKSUM" > "$CHECKSUM_FILE"
fi

# Clean up temporary files
rm -rf "$SCRIPT_DIR/cloudinit"

# ========= 3. Launch the QEMU VM =========
log "Launching QEMU VM with ${RAM_MB}MB RAM and ${VCPUS} vCPUs..."

VM_LOGS="vm_$(date +"%Y_%m_%d_%H%M%S").log"

# Use the configured network settings
SSH_PORT="$VM_SSH_PORT"
SSH_HOST="$SSH_HOST"
VM_NET_CONFIG="$VM_HOSTFWD"

# Update QEMU network configuration
QEMU_OPTS="-netdev user,id=user.0,hostfwd=${VM_NET_CONFIG} \
           -device virtio-net-pci,netdev=user.0"

VM_LOGS="vm_$(date +"%Y_%m_%d_%H%M%S").log"
qemu-system-x86_64 \
    -enable-kvm \
    -m "$RAM_MB" \
    -smp "$VCPUS" \
    -drive file="${DISK_IMAGE}",format=qcow2,if=virtio \
    -cdrom "${CLOUD_INIT_ISO}" \
    -boot d \
    -fsdev local,id=host_out,path="${OUT_DIR}/..",security_model=passthrough \
    -device virtio-9p-pci,fsdev=host_out,mount_tag=host_out \
    -fsdev local,id=host_drive,path="${TEST_DIR}/..",security_model=passthrough \
    -device virtio-9p-pci,fsdev=host_drive,mount_tag=host_drive \
    -nographic \
    $QEMU_OPTS \
    2>&1 | tee "$VM_LOGS" &

VM_PID=$!
sleep 10
if ! kill -0 $VM_PID 2>/dev/null; then
    log "Error: QEMU VM failed to start."
    exit 1
fi
log "VM launched (PID ${VM_PID})."

# Wait for Cloud-Init to complete
#log "Waiting for Cloud-Init to complete..."
#while ! vm_ssh "test -f /var/lib/cloud/instance/boot-finished"; do
#    sleep 10
#done
#log "Cloud-Init has completed."
# Wait for Cloud-Init to complete
wait_cloud_init

# Now proceed with SSH commands (e.g., kernel installation or tests)
log "VM is ready. Proceeding with next steps..."

# ========= 4. Wait for SSH Access =========
log "Waiting for SSH on port $VM_SSH_PORT..."
for i in {1..30}; do
    if nc -z $SSH_HOST $VM_SSH_PORT; then
        log "SSH is available!"
        break
    fi
    sleep 10
done

if ! nc -z $SSH_HOST $VM_SSH_PORT; then
    log "Error: SSH did not become available. Exiting."
    exit 1
fi

# ========= 5. Optional: Install the Custom Kernel =========
if [ "$INSTALL_KERNEL" == "true" ]; then
    log "Connecting via SSH to install the custom kernel..."
    vm_ssh --script <<'REMOTE_EOF'
set -euo pipefail
log() {
    echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

log "dnf update to get latest packages"
sudo dnf -y update
sudo dnf install -y rpmbuild

log "Ensuring shared folder is mounted at /host_out..."
if ! mountpoint -q /host_out; then
    sudo mkdir -p /host_out
    sudo mount -t 9p -o trans=virtio host_out /host_out || { log "Error mounting shared folder"; exit 1; }
fi

log "Detecting kernel version from artifact directory..."
# Find the latest artifact directory (e.g., /host_out/out/kernel_artifacts/v6.14.0)
ARTIFACT_DIR=$(ls -d /host_out/out/kernel_artifacts/v* 2>/dev/null | sort -V | tail -n 1)
if [ -z "$ARTIFACT_DIR" ]; then
    log "Error: No artifact directory found in /host_out/out/kernel_artifacts/"
    exit 1
fi

# Extract full kernel version (e.g., 6.14.0)
KVER=$(basename "$ARTIFACT_DIR" | sed 's/^v//')
log "Detected custom kernel version: $KVER"

# Write KVER to a file in the shared folder
echo "$KVER" > /host_out/out/kver.txt

#ARTIFACT_DIR="/host_out/out/kernel_artifacts/v${KVER}"
#if [ ! -f "${ARTIFACT_DIR}/vmlinuz-${KVER}" ]; then
#    log "Error: Kernel image not found at ${ARTIFACT_DIR}/vmlinuz-${KVER}"
#    exit 1
#fi

log "Retrieving UUID of the root filesystem..."
ROOT_DEVICE=$(findmnt -n -o SOURCE --target / | sed 's/\[.*\]//')
ROOT_UUID=$(sudo blkid -s UUID -o value "$ROOT_DEVICE")
if [ -z "$ROOT_UUID" ]; then
    log "Error: Could not determine root filesystem UUID"
    exit 1
fi
log "Root filesystem UUID: $ROOT_UUID"

log "Remounting /boot as read-write..."
sudo mount -o remount,rw /boot || { log "Failed to remount /boot as read-write"; exit 1; }

log "Copying new kernel image to /boot/vmlinuz-${KVER}..."
sudo cp "${ARTIFACT_DIR}/vmlinuz-${KVER}" "/boot/vmlinuz-${KVER}" || { log "Failed to copy kernel image"; exit 1; }
sudo cp "${ARTIFACT_DIR}/config-${KVER}" "/boot/config-${KVER}" || { log "Failed to copy config"; exit 1; }

log "Installing kernel modules..."
sudo mkdir -p /lib/modules/$KVER
sudo cp -r "${ARTIFACT_DIR}/lib/modules/$KVER/"* "/lib/modules/$KVER/" || { log "Failed to copy kernel modules"; exit 1; }

log "Installing kernel headers..."
sudo mkdir -p /usr/src/kernels/$KVER/usr
sudo cp -r "${ARTIFACT_DIR}/include" "/usr/src/kernels/$KVER/usr/" || { log "Failed to copy kernel modules"; exit 1; }

# Ensure rpmbuild SPECS directory exists and copy spec file
mkdir -p ~/rpmbuild/SPECS
cp /host_drive/dummy-kernel-headers.spec ~/rpmbuild/SPECS/

rpmbuild -ba ~/rpmbuild/SPECS/dummy-kernel-headers.spec
sudo dnf install -y ~/rpmbuild/RPMS/noarch/dummy-kernel-headers-6.14.0-1.noarch.rpm

log "Generating initramfs for the new kernel..."
# Update dracut configuration for the correct drivers and filesystem
HOOK_NAME="devexists-$(echo /dev/vda4 | sed 's/\//_/g').sh"
sudo mkdir -p /lib/dracut/hooks/initqueue/finished
sudo tee /lib/dracut/hooks/initqueue/finished/"$HOOK_NAME" <<EOF
#!/bin/sh
[ -e "/dev/vda4" ]
EOF
sudo chmod +x /lib/dracut/hooks/initqueue/finished/"$HOOK_NAME"
echo "force_drivers+=\" virtio_blk virtio_pci btrfs \"" | sudo tee /etc/dracut.conf.d/99-custom.conf
echo "add_drivers+=\" btrfs \"" | sudo tee -a /etc/dracut.conf.d/99-custom.conf
sudo dracut -f --add-drivers "virtio_blk virtio_pci btrfs" --force --kver 6.14.0 \
    --fstab --include /lib/dracut/hooks /lib/dracut/hooks /boot/initramfs-6.14.0.img

log "Adding new kernel entry to bootloader with boot parameters using UUID..."
sudo grubby --add-kernel="/boot/vmlinuz-${KVER}" --initrd="/boot/initramfs-${KVER}.img" --title="Custom Kernel $KVER" --args="root=/dev/vda4 rootfstype=btrfs rootflags=subvol=root console=ttyS0" --make-default || {
    log "grubby failed; updating bootloader configuration manually..."
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
}
# Set default kernel
DEFAULT_KERNEL=$(sudo grubby --default-kernel 2>/dev/null || echo "unknown")
log "Current default kernel: $DEFAULT_KERNEL"
if echo "$DEFAULT_KERNEL" | grep -q "vmlinuz-${KVER}"; then
    log "Custom kernel is now set as the default."
else
    log "Custom kernel not set as default. Setting manually..."
    sudo grubby --set-default="/boot/vmlinuz-${KVER}"
fi

# This prevents kernel packages from updating, so your custom kernel remains the only one in use.
sudo sed -i '/\[main\]/a exclude=kernel*' /etc/dnf/dnf.conf

log "Kernel installation complete. Rebooting to test the custom kernel..."
sudo reboot & exit
exit  # Exit SSH session immediately after reboot command
REMOTE_EOF

    # Read KVER from the file on the host
    KVER=$(cat "$OUT_DIR/kver.txt")
    log "Kernel version detected: $KVER"

    log "Kernel installation commands were sent to the VM."
    log "Waiting for VM to reboot and SSH to become available..."

    # Wait for SSH to go down (VM rebooting)
    for i in {1..30}; do
        if ! nc -z localhost 2222; then
            log "SSH is down; VM is rebooting."
            break
        fi
        sleep 2
    done

    # Wait for Cloud-Init to complete
    wait_cloud_init
    # Wait for SSH to become available after reboot
    for i in {1..30}; do
        if nc -z localhost 2222; then
            log "SSH is available after reboot."
            break
        fi
        sleep 10
    done

    if ! nc -z localhost 2222; then
        log "Error: SSH did not become available after reboot."
        exit 1
    fi

    # Mount host_drive after reboot
    log "Mounting host_drive after reboot..."
    vm_ssh --script <<'EOF'
        sudo mkdir -p /home/user/host_drive
        sudo mount -t 9p -o trans=virtio host_drive /home/user/host_drive
        exit  # Ensure SSH session exits
EOF

    # If running tests after kernel install, update test_config.txt with KVER
    if [ "$RUN_TESTS" == "true" ]; then
        log "Updating test_config.txt with detected kernel version $KVER for smoke_test..."
        if [ ! -f "$TEST_CONFIG" ]; then
            echo "smoke_test $KVER" > "$TEST_CONFIG"
        else
            # Preserve other tests, update or add smoke_test with KVER
            grep -v "^smoke_test" "$TEST_CONFIG" > "$TEST_CONFIG.tmp" || true
            echo "smoke_test $KVER" >> "$TEST_CONFIG.tmp"
            mv "$TEST_CONFIG.tmp" "$TEST_CONFIG"
        fi

	log "Running 003_run_tests.sh on the host..."
        bash "$SCRIPT_DIR/003_run_tests.sh" || {
            log "Error: Test execution failed on the host."
            exit 1
        }
        fi
    else
        log "Connecting via SSH to mount host_drive..."
        vm_ssh --script <<'EOF'
        sudo mkdir -p /home/user/host_drive
        sudo mount -t 9p -o trans=virtio host_drive /home/user/host_drive
        exit  # Ensure SSH session exits
EOF
    log "VM is running. Connect via SSH with: ssh -p 2222 ${SSH_USER}@localhost"

    # Trigger tests if requested (no kernel install)
    if [ "$RUN_TESTS" == "true" ]; then
        log "Running 003_run_tests.sh on the host..."
        bash "$SCRIPT_DIR/003_run_tests.sh" || {
            log "Error: Test execution failed on the host."
        exit 1
    }
    fi
fi

echo "VM is running. SSH: ssh -i $SYZKALLER_SSH_KEY -p 2222 $SSH_USER@localhost"
