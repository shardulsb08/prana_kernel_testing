#!/bin/bash
set -euo pipefail

# ========= Configuration Variables =========
VM_NAME="fedora-vm"
DISK_IMAGE="fedora_vm.qcow2"
# Fedora Cloud Base image (adjust URL as needed)
CLOUD_IMAGE="Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
CLOUD_IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/${CLOUD_IMAGE}"
CLOUD_INIT_ISO="seed.iso"
OUT_DIR="$(pwd)/container_kernel_workspace/out"    # Directory containing compiled kernel artifacts (from Docker build)
SSH_USER="user"
SSH_PASS="fedora"        # Default password (set in cloud-init below)

# VM resources
RAM_MB=20480            # 20GB RAM
VCPUS=16                # 16 vCPUs
DISK_SIZE="35G"         # Disk image size

# ========= Helper Functions =========
# Use ANSI escape sequences for green text and blank lines before/after each log message
log() {
    echo -e "\n\e[32m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

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
    mkdir -p cloudinit
    cat > cloudinit/user-data <<EOF
#cloud-config
users:
  - name: ${SSH_USER}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    shell: /bin/bash
    ssh_pwauth: True
    lock_passwd: false
    passwd: $(openssl passwd -6 ${SSH_PASS})
chpasswd:
  list: |
    ${SSH_USER}:${SSH_PASS}
  expire: False
ssh_pwauth: True
EOF

    cat > cloudinit/meta-data <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

    genisoimage -output "${CLOUD_INIT_ISO}" -volid cidata -joliet -rock cloudinit/user-data cloudinit/meta-data \
        || { log "Error creating cloud-init ISO"; exit 1; }
    rm -rf cloudinit
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
    -nographic &

sleep 10

VM_PID=$!
log "VM launched (PID ${VM_PID})."

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

# ========= 5. Install the Custom Kernel in the VM =========
log "Connecting via SSH to install the custom kernel..."
ssh-keygen -f "/home/shardul/.ssh/known_hosts" -R "[localhost]:2222"
ssh -tt -o StrictHostKeyChecking=no -p 2222 ${SSH_USER}@localhost <<'REMOTE_EOF'
set -euo pipefail
# Use a similar log function with color for readability inside the VM
log() {
    echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

log "Ensuring shared folder is mounted at /host_out..."
if ! mountpoint -q /host_out; then
    sudo mkdir -p /host_out
    sudo mount -t 9p -o trans=virtio host_out /host_out || { log "Error mounting shared folder"; exit 1; }
fi

if [ ! -f /host_out/kernel_artifacts/bzImage-custom ]; then
    log "Error: Kernel image not found at /host_out/kernel_artifacts/bzImage-custom"
    exit 1
fi

KVER=$(ls /host_out/kernel_artifacts/lib/modules 2>/dev/null | head -n 1)
if [ -z "$KVER" ]; then
    log "Error: Could not detect kernel version from /host_out/kernel_artifacts/lib/modules"
    exit 1
fi
log "Detected custom kernel version: $KVER"

# Retrieve the UUID of the root filesystem
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
sudo cp /host_out/kernel_artifacts/bzImage-custom /boot/vmlinuz-custom || { log "Failed to copy kernel image"; exit 1; }

log "Installing kernel modules..."
sudo mkdir -p /lib/modules/$KVER
sudo cp -r /host_out/kernel_artifacts/lib/modules/$KVER/* /lib/modules/$KVER/ || { log "Failed to copy kernel modules"; exit 1; }

log "Generating initramfs for the new kernel..."
sudo dracut -f --add-drivers "virtio_blk virtio_pci" /boot/initramfs-custom.img $KVER || { log "dracut failed"; exit 1; }

log "Adding new kernel entry to bootloader with boot parameters using UUID..."
sudo grubby --add-kernel=/boot/vmlinuz-custom --initrd=/boot/initramfs-custom.img --title="Custom Kernel $KVER" --args="root=UUID=$ROOT_UUID rootflags=subvol=root console=ttyS0" --make-default || {
    log "grubby failed; updating bootloader configuration manually..."
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
}

DEFAULT_KERNEL=$(sudo grubby --default-kernel 2>/dev/null || echo "unknown")
log "Current default kernel: $DEFAULT_KERNEL"
if echo "$DEFAULT_KERNEL" | grep -q "vmlinuz-custom"; then
    log "Custom kernel is now set as the default."
else
    log "Custom kernel not set as default. Setting manually..."
    sudo grubby --set-default=/boot/vmlinuz-custom
fi

log "Kernel installation complete. Rebooting to test the custom kernel..."
sudo reboot
REMOTE_EOF

log "Kernel installation commands were sent to the VM."
log "After reboot, SSH back into the VM with: ssh -p 2222 ${SSH_USER}@localhost"
