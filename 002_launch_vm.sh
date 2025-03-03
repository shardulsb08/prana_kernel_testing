#!/bin/bash
set -euo pipefail

# Determine the script's directory for consistent file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Source common functions and variables
source "$SCRIPT_DIR/common.sh"

# ========= Configuration Variables =========
VM_NAME="fedora-vm"
DISK_IMAGE="$SCRIPT_DIR/fedora_vm.qcow2"
CLOUD_IMAGE="$SCRIPT_DIR/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
CLOUD_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/${CLOUD_IMAGE##*/}"
CLOUD_INIT_ISO="$SCRIPT_DIR/seed.iso"
OUT_DIR="$SCRIPT_DIR/container_kernel_workspace/out"  # Directory with kernel artifacts
TEST_CONFIG="$SCRIPT_DIR/host_drive/tests/test_config.txt"  # Path to test config on host

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

# Function to wait for Cloud-Init to complete
wait_cloud_init() {
	log "Waiting for Cloud-Init to complete..."
	while ! vm_ssh "test -f /var/lib/cloud/instance/boot-finished"; do
		sleep 10
		log "Waiting for Cloud-Init to complete..."
	done
	log "Cloud-Init has completed."
}

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
if [ ! -f "$CLOUD_INIT_ISO" ]; then
    log "Creating cloud-init ISO for initial VM configuration..."
    mkdir -p "$SCRIPT_DIR/cloudinit"
    cat > "$SCRIPT_DIR/cloudinit/user-data" <<EOF
#cloud-config
users:
  - name: ${SSH_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    shell: /bin/bash
    lock_passwd: false
    passwd: $(openssl passwd -6 ${SSH_PASS})
ssh_pwauth: True
EOF

    cat > "$SCRIPT_DIR/cloudinit/meta-data" <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

    genisoimage -output "${CLOUD_INIT_ISO}" -volid cidata -joliet -rock "$SCRIPT_DIR/cloudinit/user-data" "$SCRIPT_DIR/cloudinit/meta-data" \
        || { log "Error creating cloud-init ISO"; exit 1; }
    rm -rf "$SCRIPT_DIR/cloudinit"
fi

# ========= 3. Launch the QEMU VM =========
log "Launching QEMU VM with ${RAM_MB}MB RAM and ${VCPUS} vCPUs..."

qemu-system-x86_64 \
    -enable-kvm \
    -m ${RAM_MB} \
    -smp ${VCPUS} \
    -drive file="${DISK_IMAGE}",format=qcow2,if=virtio \
    -cdrom "${CLOUD_INIT_ISO}" \
    -boot d \
    -net user,hostfwd=tcp::2222-:22 \
    -net nic \
    -fsdev local,id=host_out,path="${OUT_DIR}",security_model=passthrough \
    -device virtio-9p-pci,fsdev=host_out,mount_tag=host_out \
    -fsdev local,id=host_drive,path="${SCRIPT_DIR}/host_drive",security_model=passthrough \
    -device virtio-9p-pci,fsdev=host_drive,mount_tag=host_drive \
    -nographic &

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
log "Waiting for SSH on port 2222..."
for i in {1..30}; do
    if nc -z localhost 2222; then
        log "SSH is available!"
        break
    fi
    sleep 10
done

if ! nc -z localhost 2222; then
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

log "Ensuring shared folder is mounted at /host_out..."
if ! mountpoint -q /host_out; then
    sudo mkdir -p /host_out
    sudo mount -t 9p -o trans=virtio host_out /host_out || { log "Error mounting shared folder"; exit 1; }
fi

log "Detecting kernel version from artifact directory..."
# Look for versioned directories under /host_out/kernel_artifacts/
KVER=$(ls -d /host_out/kernel_artifacts/v* 2>/dev/null | sort -V | tail -n 1 | sed 's|.*/v||')
if [ -z "$KVER" ]; then
    log "Error: Could not detect kernel version from /host_out/kernel_artifacts/"
    exit 1
fi
log "Detected custom kernel version: $KVER"

# Write KVER to a file in the shared folder
echo "$KVER" > /host_out/kver.txt

ARTIFACT_DIR="/host_out/kernel_artifacts/v${KVER}"
if [ ! -f "${ARTIFACT_DIR}/bzImage-custom" ]; then
    log "Error: Kernel image not found at ${ARTIFACT_DIR}/bzImage-custom"
    exit 1
fi

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

log "Copying new kernel image to /boot/vmlinuz-custom..."
sudo cp "${ARTIFACT_DIR}/bzImage-custom" /boot/vmlinuz-custom || { log "Failed to copy kernel image"; exit 1; }

log "Installing kernel modules..."
sudo mkdir -p /lib/modules/$KVER
sudo cp -r "${ARTIFACT_DIR}/lib/modules/$KVER/"* /lib/modules/$KVER/ || { log "Failed to copy kernel modules"; exit 1; }

log "Generating initramfs for the new kernel..."
sudo dracut -f --add-drivers "virtio_blk virtio_pci" /boot/initramfs-custom.img $KVER || { log "dracut failed"; exit 1; }

log "Adding new kernel entry to bootloader with boot parameters using UUID..."
sudo grubby --add-kernel=/boot/vmlinuz-custom --initrd=/boot/initramfs-custom.img --title="Custom Kernel $KVER" --args="root=UUID=$ROOT_UUID rootflags=subvol=root console=ttyS0" --make-default || {
    log "grubby failed; updating bootloader configuration manually..."
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
}
# Set default kernel
DEFAULT_KERNEL=$(sudo grubby --default-kernel 2>/dev/null || echo "unknown")
log "Current default kernel: $DEFAULT_KERNEL"
if echo "$DEFAULT_KERNEL" | grep -q "vmlinuz-custom"; then
    log "Custom kernel is now set as the default."
else
    log "Custom kernel not set as default. Setting manually..."
    sudo grubby --set-default=/boot/vmlinuz-custom
fi

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
