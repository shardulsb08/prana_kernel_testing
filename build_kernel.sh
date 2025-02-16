#!/bin/bash
set -euo pipefail
trap 'echo "Error occurred at line ${LINENO}. Exiting." >&2' ERR

# Function to print messages
log() {
  echo "[`date +"%Y-%m-%d %H:%M:%S"`] $*"
}

# 1. Fetch the latest stable Linux kernel version dynamically
log "Fetching latest stable Linux kernel version from kernel.org..."
KERNEL_RELEASES_JSON=$(curl -s https://www.kernel.org/releases.json)

LATEST_VERSION=$(echo "$KERNEL_RELEASES_JSON" | jq -r '.latest_stable')
if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "null" ]]; then
  log "Error: Could not retrieve the latest stable kernel version."
  exit 1
fi
log "Latest stable kernel version is: $LATEST_VERSION"

# Determine the appropriate subdirectory (e.g., v6.x for version 6.x)
MAJOR_VERSION=$(echo "$LATEST_VERSION" | cut -d. -f1)
KERNEL_SUBDIR="v${MAJOR_VERSION}.x"
DOWNLOAD_URL="https://cdn.kernel.org/pub/linux/kernel/${KERNEL_SUBDIR}/linux-${LATEST_VERSION}.tar.xz"

# 2. Download the kernel source
log "Downloading Linux kernel from ${DOWNLOAD_URL}..."
wget "$DOWNLOAD_URL" -O "linux-${LATEST_VERSION}.tar.xz"

# 3. Extract the kernel source
log "Extracting linux-${LATEST_VERSION}.tar.xz..."
tar -xf "linux-${LATEST_VERSION}.tar.xz"

# Change into the kernel source directory
cd "linux-${LATEST_VERSION}"

# 4. Configure the kernel with default settings (defconfig)
log "Running 'make defconfig' to set up default configuration..."
make defconfig

# 5. Compile the kernel using all available cores
log "Starting kernel compilation with $(nproc) parallel jobs..."
make -j"$(nproc)"

# 6. Prepare kernel artifacts for installation
# Create a directory outside the source tree to store artifacts
cd ..
mkdir -p kernel_artifacts

# Install modules into the artifact directory
log "Installing kernel modules to ./kernel_artifacts/ ..."
cd "linux-${LATEST_VERSION}"
make modules_install INSTALL_MOD_PATH=../kernel_artifacts

# Copy the kernel binary (for x86, typically located at arch/x86/boot/bzImage)
if [ -f arch/x86/boot/bzImage ]; then
  log "Copying kernel image (arch/x86/boot/bzImage) to artifacts directory..."
  cp arch/x86/boot/bzImage ../kernel_artifacts/
else
  log "Warning: Kernel image not found at arch/x86/boot/bzImage. Skipping copy." >&2
fi

cd ..

# Package the compiled kernel artifacts (modules and kernel image) into a tar.gz file
log "Packaging kernel artifacts into kernel_artifacts.tar.gz..."
tar -czf kernel_artifacts.tar.gz -C kernel_artifacts .

log "Kernel build and packaging completed successfully."
log "Kernel artifacts are available in: $(pwd)/kernel_artifacts.tar.gz"
