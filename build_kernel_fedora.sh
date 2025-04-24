#!/bin/bash
set -euo pipefail
trap 'echo "Error at line ${LINENO}" >&2' ERR

# Helper logging function
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*"
}

# Function to apply kernel configurations from a file
apply_kernel_configs() {
    local config_file=$1
    log "Applying configurations from $config_file..."
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^# ]] || [ -z "$line" ]; then
            continue
        fi
        # Extract config name and value
        config=$(echo "$line" | cut -d= -f1)
        value=$(echo "$line" | cut -d= -f2)
        case "$value" in
            "y")
                scripts/config --file .config --enable "$config"
                ;;
            "m")
                scripts/config --file .config --module "$config"
                ;;
            "n")
                scripts/config --file .config --disable "$config"
                ;;
            *)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    # Handle numeric values
                    scripts/config --file .config --set-val "$config" "$value"
                elif [[ "$value" =~ ^\".*\"$ ]]; then
                    # Handle string values (remove quotes)
                    val="${value:1:-1}"
                    scripts/config --file .config --set-str "$config" "$val"
                else
                    log "Warning: Unknown value '$value' for $config in $config_file"
                fi
                ;;
        esac
    done < "$config_file"
}

# Create output directory for artifacts
# Use an absolute path for the out directory
OUT_DIR="/build/out/kernel_artifacts"
mkdir -p "$OUT_DIR"

# 1. Clone the upstream kernel source if not already present
if [ ! -d "linux" ]; then
    log "Cloning upstream kernel source from torvalds/linux.git..."
    attempt=0
    max_attempts=3
    until [ $attempt -ge $max_attempts ]; do
        if git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git; then
            break
        else
            attempt=$((attempt+1))
            log "git clone attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        fi
    done
    if [ $attempt -eq $max_attempts ]; then
        log "Error: Failed to clone kernel source after $max_attempts attempts."
        exit 1
    fi
fi

cd linux

# Add the stable kernel remote if not already present
log "Adding stable kernel remote..."
git remote add stable git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git || true

# Fetch all tags from both remotes
log "Fetching all git tags from origin remote..."
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    if git fetch --tags origin; then
        break
    else
        attempt=$((attempt+1))
        log "git fetch origin attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log "Error: Failed to fetch tags from origin after $max_attempts attempts."
    exit 1
fi

log "Fetching all git tags from stable remote..."
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    if git fetch --tags stable; then
        break
    else
        attempt=$((attempt+1))
        log "git fetch stable attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log "Error: Failed to fetch tags from stable after $max_attempts attempts."
    exit 1
fi

# Get the latest stable version from kernel.org
log "Fetching latest stable kernel version from kernel.org..."
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    LATEST_STABLE=$(curl -s https://www.kernel.org/finger_banner | grep "latest stable version" | awk '{print $NF}')
    if [ -n "$LATEST_STABLE" ]; then
        break
    else
        attempt=$((attempt+1))
        log "curl attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log "Error: Failed to fetch kernel version after $max_attempts attempts."
    exit 1
fi

# Check out the corresponding tag (e.g., v6.13.4)
log "Checking out kernel tag v${LATEST_STABLE}..."
git checkout "v${LATEST_STABLE}" || {
    log "Error: Failed to check out tag v${LATEST_STABLE}. It may not exist or tags are outdated."
    exit 1
}

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
    attempt=0
    max_attempts=3
    until [ $attempt -ge $max_attempts ]; do
        if git pull; then
            break
        else
            attempt=$((attempt+1))
            log "git pull attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        fi
    done
    if [ $attempt -eq $max_attempts ]; then
        log "Error: Failed to pull updates for fedora_kernel after $max_attempts attempts."
        exit 1
    fi
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

    # Run the configuration generator
    # If it fails, log a warning but do not exit immediately
    if ! ./generate_all_configs.sh; then
        log "Warning: generate_all_configs.sh exited with a non-zero status. Checking for generated configuration..."
    fi
    
    # Verify that the expected configuration file exists
    if [ ! -f kernel-x86_64-fedora.config ]; then
        log "Error: Configuration file kernel-x86_64-fedora.config was not generated. Exiting."
        exit 1
    fi

    # Adjust the file name if necessary; here we assume kernel-x86_64.config is produced
    cp kernel-x86_64-fedora.config ../linux/.config
    cd ..
fi

cd linux

# Fetch all tags to ensure we have the latest
log "Fetching all git tags from origin..."
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    if git fetch --tags; then
        break
    else
        attempt=$((attempt+1))
        log "git fetch attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log "Error: Failed to fetch tags after $max_attempts attempts."
    exit 1
fi

# 3. Update configuration
log "Updating kernel configuration with 'make olddefconfig'..."
make olddefconfig

# Determine the full kernel version
log "Determining full kernel version..."
FULL_KVER=$(make kernelrelease)
log "Full kernel version: $FULL_KVER"

# Check for test configurations and apply them
if [ -f /build_input/test_config.txt ]; then
    if grep -q '^syzkaller\b' /build_input/test_config.txt; then
        if [ -f /build_input/kernel_syskaller.config ]; then
            apply_kernel_configs /build_input/kernel_syskaller.config
        else
            log "Error: /build_input/kernel_syskaller.config not found"
            exit 1
        fi
    elif grep -q '^syzgen_config_raw\b' /build_input/test_config.txt; then
        if [ -f /build_input/kernel_syzgen_raw.config ]; then
            apply_kernel_configs /build_input/kernel_syzgen_raw.config
        else
	    log "Error: /build_input/kernel_syzgen_raw.config not found"
            exit 1
        fi
    elif grep -q '^syzgen_config_fuzz\b' /build_input/test_config.txt; then
        if [ -f /build_input/kernel_syzgen_fuzz.config ]; then
            apply_kernel_configs /build_input/kernel_syzgen_fuzz.config
        else
	    log "Error: /build_input/kernel_syzgen_fuzz.config not found"
            exit 1
        fi
    fi
else
    log "Warning: /build_input/test_config.txt not found"
fi

# Embed the config in the kernel image
scripts/config --file .config --enable CONFIG_IKCONFIG
# Make the config available as /proc/config.gz
scripts/config --file .config --enable CONFIG_IKCONFIG_PROC

# Update configuration again
log "Updating kernel configuration with 'make olddefconfig'..."
make olddefconfig

# 4. Build the kernel image and modules with ccache
log "Building kernel bzImage..."
make CC="ccache gcc" -j"$(nproc)" bzImage

log "Building kernel modules..."
make CC="ccache gcc" -j"$(nproc)" modules

# 5. Copy artifacts
OUT_DIR="/build/out/kernel_artifacts/v${FULL_KVER}"
mkdir -p "$OUT_DIR"
log "Copying kernel image (bzImage) to ${OUT_DIR}/vmlinuz-${FULL_KVER}..."
cp arch/x86/boot/bzImage "$OUT_DIR/vmlinuz-${FULL_KVER}"
cp .config "$OUT_DIR/config-${FULL_KVER}"

# Install modules
log "Installing kernel modules into ${OUT_DIR}..."
make modules_install INSTALL_MOD_PATH="$OUT_DIR"
make headers_install INSTALL_HDR_PATH="$OUT_DIR"

log "Kernel build complete. Artifacts are available in ${OUT_DIR}."
#tail -f /dev/null
