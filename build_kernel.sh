#!/bin/bash
set -euo pipefail
trap 'echo "Error occurred at line ${LINENO}. Exiting." >&2' ERR

# Determine script directory and source configurations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$SCRIPT_DIR/infrastructure/kernel/config.sh"
source "$SCRIPT_DIR/infrastructure/kernel/syzkaller.sh"
source "$SCRIPT_DIR/infrastructure/kernel/syzgen.sh"

# Function to print messages
log() {
  echo "[`date +"%Y-%m-%d %H:%M:%S"`] $*"
}

# Parse command line arguments for build mode
BUILD_MODE="LOCAL"
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      BUILD_MODE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--mode LOCAL|SYZKALLER|SYZGEN]"
      exit 1
      ;;
  esac
done

# Setup kernel configuration based on mode
case $BUILD_MODE in
  "SYZKALLER")
    setup_syzkaller_kernel
    ;;
  "SYZGEN")
    setup_syzgen_kernel
    ;;
  "LOCAL")
    setup_kernel_config "LOCAL"
    ;;
  *)
    echo "Invalid build mode: $BUILD_MODE"
    echo "Valid modes: LOCAL, SYZKALLER, SYZGEN"
    exit 1
    ;;
esac

# 1. Fetch the latest stable Linux kernel version dynamically
log "Fetching latest stable Linux kernel version from kernel.org..."
KERNEL_RELEASES_JSON=$(curl -s https://www.kernel.org/releases.json)

# Extract the version string from the JSON using the proper key path
LATEST_VERSION=$(echo "$KERNEL_RELEASES_JSON" | jq -r '.latest_stable.version')
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

# 4. Configure the kernel based on mode
log "Configuring kernel for ${BUILD_MODE} mode..."
if [[ -f "$KERNEL_CONFIG_DIR/$KERNEL_CONFIG_FILE" ]]; then
  cp "$KERNEL_CONFIG_DIR/$KERNEL_CONFIG_FILE" .config
  make olddefconfig
else
  log "Warning: Config file not found at $KERNEL_CONFIG_DIR/$KERNEL_CONFIG_FILE"
  log "Falling back to defconfig..."
  make defconfig
fi

# 5. Compile the kernel using all available cores
log "Starting kernel compilation with $(nproc) parallel jobs..."
make -j"$(nproc)" "$KERNEL_BUILD_TARGET"

# 6. Prepare kernel artifacts for installation
KERNEL_OUT_VERSION="$KERNEL_OUT/kernel_artifacts/v$LATEST_VERSION"
mkdir -p "$KERNEL_OUT_VERSION"

# Install modules
log "Installing kernel modules to $KERNEL_OUT_VERSION..."
make modules_install INSTALL_MOD_PATH="$KERNEL_OUT_VERSION"

# Install kernel headers
log "Installing kernel headers to $KERNEL_OUT_VERSION..."
make headers_install INSTALL_HDR_PATH="$KERNEL_OUT_VERSION/usr"

# Copy additional header files needed for module building
log "Copying additional kernel headers for module building..."
mkdir -p "$KERNEL_OUT_VERSION/usr/src/linux-headers-$LATEST_VERSION"
cp -a include "$KERNEL_OUT_VERSION/usr/src/linux-headers-$LATEST_VERSION"
cp -a arch/x86/include "$KERNEL_OUT_VERSION/usr/src/linux-headers-$LATEST_VERSION/arch/x86"
cp -a scripts "$KERNEL_OUT_VERSION/usr/src/linux-headers-$LATEST_VERSION"
cp .config "$KERNEL_OUT_VERSION/usr/src/linux-headers-$LATEST_VERSION"
cp Module.symvers "$KERNEL_OUT_VERSION/usr/src/linux-headers-$LATEST_VERSION"
find . -name "Makefile*" -o -name "Kconfig*" | cpio -pd "$KERNEL_OUT_VERSION/usr/src/linux-headers-$LATEST_VERSION"

# Copy the kernel binary
if [[ -f "arch/x86/boot/$KERNEL_BUILD_TARGET" ]]; then
  log "Copying kernel image to artifacts directory..."
  cp "arch/x86/boot/$KERNEL_BUILD_TARGET" "$KERNEL_OUT_VERSION/vmlinuz-$LATEST_VERSION"
  cp .config "$KERNEL_OUT_VERSION/config-$LATEST_VERSION"
else
  log "Warning: Kernel image not found at arch/x86/boot/$KERNEL_BUILD_TARGET" >&2
fi

# Create version file
echo "$LATEST_VERSION" > "$KERNEL_OUT/kver.txt"

# Package artifacts
log "Packaging kernel artifacts..."
tar -czf "$KERNEL_OUT/kernel_artifacts.tar.gz" -C "$KERNEL_OUT" .

log "Kernel build completed successfully for ${BUILD_MODE} mode."
log "Build artifacts are available in $KERNEL_OUT"
