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

cd ..

# 2. Fetch a valid Fedora Rawhide kernel configuration
if [ ! -d "fedora_kernel" ]; then
    log "Fedora kernel repository not found. Cloning with fedpkg..."
    attempt=0
    max_attempts=3
    until [ $attempt -ge $max_attempts ]; do
        if fedpkg clone -a kernel fedora_kernel; then
            break
        else
            attempt=$((attempt+1))
            log "fedpkg clone attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        fi
    done
    if [ $attempt -eq $max_attempts ]; then
        log "Error: fedpkg clone failed after $max_attempts attempts."
        exit 1
    fi
else
    log "Fedora kernel repository already exists. Updating..."
    cd fedora_kernel
    git checkout rawhide
    git pull
    # Optional: create a unique branch with a timestamp
    # timestamp=$(date +"%Y%m%d-%H%M%S")
    # git checkout -b rawhide-$timestamp
    cd ..
fi

# Copy the generated configuration for x86_64 from fedora_kernel into the Linux source
if [ ! -f "linux/.config" ]; then
    log "Generating Fedora Rawhide configuration..."
    cd fedora_kernel
    if [ ! -f ./generate_all_configs.sh ]; then
        log "Error: generate_all_configs.sh not found in fedora_kernel directory. Please verify the repository structure."
        exit 1
    fi
    # Ensure the script is executable
    if [ ! -x ./generate_all_configs.sh ]; then
        log "generate_all_configs.sh is not executable. Attempting to set execute permission..."
        chmod +x ./generate_all_configs.sh || { log "Failed to set execute permission on generate_all_configs.sh"; exit 1; }
    fi

    # Run the configuration generator.
    # If it fails, log a warning but do not exit immediately.
    if ! ./generate_all_configs.sh; then
        log "Warning: generate_all_configs.sh exited with a non-zero status. Checking for generated configuration..."
    fi
    
    # Verify that the expected configuration file exists.
    if [ ! -f kernel-x86_64-fedora.config ]; then
        log "Error: Configuration file kernel-x86_64-fedora.config was not generated. Exiting."
        exit 1
    fi

    # Adjust the file name if necessary; here we assume kernel-x86_64.config is produced.
    cp kernel-x86_64-fedora.config ../linux/.config
    cd ..
fi

cd linux

# 3. Update configuration
log "Updating kernel configuration with 'make oldconfig'..."
make oldconfig

# (Optional) Uncomment the next line for interactive configuration
# make menuconfig

# 4. Build the kernel image and modules
log "Building kernel bzImage..."
make -j"$(nproc)" bzImage

log "Building kernel modules..."
make -j"$(nproc)" modules

# 5. Install modules and copy the kernel image to the output directory
log "Installing kernel modules into ../out directory..."
make modules_install INSTALL_MOD_PATH=../out

log "Copying kernel image (bzImage) to ../out directory as bzImage-custom..."
cp arch/x86/boot/bzImage ../out/bzImage-custom

log "Kernel build complete. Artifacts available in the 'out' directory."
