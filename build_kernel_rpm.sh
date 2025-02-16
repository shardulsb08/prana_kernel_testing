#!/bin/bash
set -euo pipefail
trap 'echo "Error at line ${LINENO}" >&2' ERR

# Helper logging function
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*"
}

# Create output directory for artifacts
mkdir -p out

# 1. Clone the upstream kernel source if not already present
if [ ! -d "linux" ]; then
    log "Cloning upstream kernel source from torvalds/linux.git..."
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
fi

cd linux

# (Optional) You can add a remote for stable releases if needed:
# git remote add stable git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git || true
# git fetch stable

# 2. Fetch a valid configuration
if [ ! -f .config ]; then
    log "Fetching Fedora Rawhide kernel configuration..."
    cd ..
    # Clone the Fedora kernel repository (if not already present)
    if [ ! -d "fedora_kernel" ]; then
        fedpkg clone -a kernel fedora_kernel
    fi
    cd fedora_kernel
    # Check out the rawhide branch
    git checkout rawhide
    # Generate all configuration files (this script is provided in the Fedora kernel repo)
    ./generate_all_configs.sh
    # Copy the configuration for x86_64 (adjust if needed for a different architecture)
    cp kernel-x86_64.config ../linux/.config
    cd linux
fi

# 3. Update configuration
log "Updating kernel configuration with 'make oldconfig'..."
make oldconfig

# (Optional) Uncomment the following line if you need to adjust the configuration interactively.
# make menuconfig

# 4. Build the kernel image and modules using Fedora’s recommended process
log "Building kernel bzImage..."
make -j"$(nproc)" bzImage

log "Building kernel modules..."
make -j"$(nproc)" modules

# 5. Install modules and copy kernel image to output directory
log "Installing kernel modules into out/ directory..."
make modules_install INSTALL_MOD_PATH=../out

log "Copying kernel image (bzImage) to out/ directory..."
cp arch/x86/boot/bzImage ../out/bzImage-custom

log "Kernel build complete. Artifacts available in the 'out' directory."
