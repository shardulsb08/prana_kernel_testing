#!/bin/bash
set -euo pipefail
trap 'echo "Error at line ${LINENO}" >&2' ERR

# Helper logging function
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $*"
}

# Function to update a specific kernel configuration value
update_config() {
    local input_config="$1"
    local new_value="$2"
    # Note: Using ".config" as the file path is correct because this function
    # is called when the current directory is 'linux'.
    local config_file=".config"

    log "Updating $input_config to '$new_value' in $config_file"

    # Use grep with Extended Regex to check if the config exists in any form.
    if grep -q -E "^${input_config}=|# ${input_config} is not set" "$config_file"; then
        # Use two separate, simpler sed commands for maximum compatibility.
        # This avoids complex regex and is safer across different sed versions.

        # 1. Replace the commented-out version, if it exists.
        sed -i "s|^# ${input_config} is not set|${input_config}=${new_value}|" "$config_file"

        # 2. Replace the version that already has a value. This will also match
        #    the line that was just modified by the command above, which is safe.
        sed -i "s|^${input_config}=.*|${input_config}=${new_value}|" "$config_file"

        log "Successfully updated $input_config to '$new_value'."
    else
        # If the config is not found in the .config file at all
        log "$input_config not found in existing .config, if you want it, add it to an appropriate config file"
    fi
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
#	update_config "$config" "$value"
        case "$value" in
            "y")
                scripts/config --file .config --enable "$config"
		update_config "$config" y
                ;;
            "m")
                scripts/config --file .config --module "$config"
		update_config "$config" m
                ;;
            "n")
                scripts/config --file .config --disable "$config"
		update_config "$config" n
                ;;
            *)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    # Handle numeric values
                    scripts/config --file .config --set-val "$config" "$value"
		    update_config "$config" "$value"
                elif [[ "$value" =~ ^\".*\"$ ]]; then
                    # Handle string values (remove quotes)
                    val="${value:1:-1}"
                    scripts/config --file .config --set-str "$config" "$val"
		    update_config "$config" "$val"
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
if [ ! -d "linux_net_next" ]; then
    log "Cloning net-next kernel source..."
    attempt=0
    max_attempts=3
    until [ $attempt -ge $max_attempts ]; do
        if git clone https://git.kernel.org/pub/scm/linux/kernel/git/netdev/net-next.git linux_net_next; then
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

cd linux_net_next
git pull
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
if [ ! -f "linux_net_next/.config" ]; then
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
    cp kernel-x86_64-fedora.config ../linux_net_next/.config
    cd ..
fi

cd linux_net_next

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
# make olddefconfig

# Check for test configurations and apply them
if [ -f /build_input/test_config.txt ]; then
    if grep -q '^syzkaller\b' /build_input/test_config.txt; then
        if [ -f /build_input/kernel_syskaller.config ]; then
            apply_kernel_configs /build_input/kernel_syskaller.config
        else
            log "Error: /build_input/kernel_syskaller.config not found"
            exit 1
        fi
        if [ -f /build_input/fuzz_config_untouched_only.config ]; then
		apply_kernel_configs /build_input/fuzz_config_untouched_only.config
	else
		log_error "/build_input/fuzz_config_untouched_only.config not found"
		exit 1
	fi
        if [ -f /build_input/kernel_brf.config ]; then
		apply_kernel_configs /build_input/kernel_brf.config
	else
		log_error "/build_input/kernel_brf.config not found"
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
# make olddefconfig
#update_config CONFIG_LOCALVERSION '"_custombuild"'

  scripts/config --file .config --disable CONFIG_LOCK_TORTURE_TEST
  scripts/config --file .config --disable CONFIG_RCU_TORTURE_TEST
  update_config CONFIG_LOCK_TORTURE_TEST n
  update_config CONFIG_RCU_TORTURE_TEST n
  scripts/config --file .config --enable CONFIG_KASAN
  scripts/config --file .config --enable CONFIG_KASAN_INLINE
  scripts/config --file .config --disable CONFIG_PROVE_RCU
  scripts/config --file .config --disable CONFIG_WW_MUTEX_SELFTEST
  scripts/config --file .config --disable CONFIG_TORTURE_TEST
  scripts/config --file .config --disable CONFIG_TEST_VMALLOC
  scripts/config --file .config --disable CONFIG_REED_SOLOMON_TEST
  scripts/config --file .config --enable CONFIG_ASYNC_RAID6_TEST
  scripts/config --file .config --disable CONFIG_DMABUF_SELFTESTS
  scripts/config --file .config --disable CONFIG_FIPS_SIGNATURE_SELFTEST
  scripts/config --file .config --disable CONFIG_FIPS_SIGNATURE_SELFTEST_RSA
  scripts/config --file .config --disable CONFIG_FIPS_SIGNATURE_SELFTEST_ECDSA
  scripts/config --file .config --disable CONFIG_GLOB_SELFTEST
  scripts/config --file .config --disable CONFIG_DEBUG_LOCKING_API_SELFTESTS
  scripts/config --file .config --disable CONFIG_SCF_TORTURE_TEST
  scripts/config --file .config --disable CONFIG_X86_DECODER_SELFTEST
  scripts/config --file .config --disable CONFIG_BACKTRACE_SELF_TEST
  scripts/config --file .config --disable CONFIG_KALLSYMS_SELFTEST
  scripts/config --file .config --disable CONFIG_DEBUG_OBJECTS_SELFTEST
  scripts/config --file .config --disable CONFIG_BINFMT_ELF_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_DAMON_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_DAMON_SYSFS_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_DAMON_VADDR_KUNIT_TEST
  # scripts/config --file .config --disable
  scripts/config --file .config --disable CONFIG_DEBUG_RODATA_TEST
  scripts/config --file .config --disable CONFIG_DMAPOOL_TEST
  scripts/config --file .config --disable CONFIG_DRM_SCHED_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_DRM_VKMS_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_EFI_TEST #m
  scripts/config --file .config --disable CONFIG_EXEC_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_FPGA_KUNIT_TESTS
  scripts/config --file .config --disable CONFIG_GUP_TEST
  scripts/config --file .config --disable CONFIG_HW_BREAKPOINT_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_INITRAMFS_TEST
  scripts/config --file .config --disable CONFIG_INTERVAL_TREE_TEST
  scripts/config --file .config --disable CONFIG_KPROBE_EVENT_GEN_TEST
  scripts/config --file .config --disable CONFIG_LEDS_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_MAILBOX_TEST
  scripts/config --file .config --disable CONFIG_MCTP_TEST
  scripts/config --file .config --disable CONFIG_NITRO_ENCLAVES_MISC_DEV_TEST
  scripts/config --file .config --disable CONFIG_OF_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_OF_OVERLAY_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_OF_UNITTEST
  scripts/config --file .config --disable CONFIG_PCI_ENDPOINT_TEST
  scripts/config --file .config --disable CONFIG_PERCPU_TEST
  scripts/config --file .config --disable CONFIG_PKCS7_TEST_KEY
  scripts/config --file .config --disable CONFIG_PM_QOS_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_PREEMPTIRQ_DELAY_TEST
  scripts/config --file .config --disable CONFIG_RANDSTRUCT_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_RBTREE_TEST
  scripts/config --file .config --disable CONFIG_RCU_REF_SCALE_TEST
  scripts/config --file .config --disable CONFIG_RCU_SCALE_TEST
  scripts/config --file .config --disable CONFIG_RTC_DRV_TEST
  scripts/config --file .config --disable CONFIG_SECURITY_APPARMOR_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_SECURITY_IPE_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_SECURITY_LANDLOCK_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_TEST_ASYNC_DRIVER_PROBE
  scripts/config --file .config --disable CONFIG_TEST_BITMAP
  scripts/config --file .config --disable CONFIG_TEST_BITOPS
  scripts/config --file .config --disable CONFIG_TEST_DHRY
  scripts/config --file .config --disable CONFIG_TEST_DIV64
  scripts/config --file .config --disable CONFIG_TEST_FIRMWARE
  scripts/config --file .config --disable CONFIG_TEST_FREE_PAGES
  scripts/config --file .config --disable CONFIG_TEST_HEXDUMP
  scripts/config --file .config --disable CONFIG_TEST_HMM #m
  scripts/config --file .config --disable CONFIG_TEST_IDA
  scripts/config --file .config --disable CONFIG_TEST_KMOD
  scripts/config --file .config --disable CONFIG_TEST_LKM
  scripts/config --file .config --disable CONFIG_TEST_MAPLE_TREE
  scripts/config --file .config --disable CONFIG_TEST_MEMCAT_P
  scripts/config --file .config --disable CONFIG_TEST_MEMINIT
  scripts/config --file .config --disable CONFIG_TEST_MIN_HEAP
  scripts/config --file .config --disable CONFIG_TEST_REF_TRACKER
  scripts/config --file .config --disable CONFIG_TEST_RHASHTABLE
  scripts/config --file .config --disable CONFIG_TEST_STATIC_KEYS
  scripts/config --file .config --disable CONFIG_TEST_SYSCTL
  scripts/config --file .config --disable CONFIG_TEST_UBSAN
  scripts/config --file .config --disable CONFIG_TEST_UDELAY
  scripts/config --file .config --disable CONFIG_TEST_UUID
  scripts/config --file .config --disable CONFIG_TEST_XARRAY
  scripts/config --file .config --disable CONFIG_USB4_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_VCAP_KUNIT_TEST
  scripts/config --file .config --disable CONFIG_XZ_DEC_TEST
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  # scripts/config --file .config --disable
  update_config CONFIG_PROVE_RCU n
  update_config CONFIG_WW_MUTEX_SELFTEST n
  update_config CONFIG_TORTURE_TEST n
  update_config CONFIG_TEST_VMALLOC n
  update_config CONFIG_REED_SOLOMON_TEST n
  update_config CONFIG_ASYNC_RAID6_TEST m
  update_config CONFIG_DMABUF_SELFTESTS n
  update_config CONFIG_FIPS_SIGNATURE_SELFTEST n
  update_config CONFIG_FIPS_SIGNATURE_SELFTEST_RSA n
  update_config CONFIG_FIPS_SIGNATURE_SELFTEST_ECDSA n
  update_config CONFIG_GLOB_SELFTEST n
  update_config CONFIG_DEBUG_LOCKING_API_SELFTESTS n
  update_config CONFIG_SCF_TORTURE_TEST n
  update_config CONFIG_X86_DECODER_SELFTEST n
  update_config CONFIG_BACKTRACE_SELF_TEST n
  update_config CONFIG_KALLSYMS_SELFTEST n
  update_config CONFIG_DEBUG_OBJECTS_SELFTEST n
  update_config CONFIG_BINFMT_ELF_KUNIT_TEST n
  update_config CONFIG_DAMON_KUNIT_TEST n
  update_config CONFIG_DAMON_SYSFS_KUNIT_TEST n
  update_config CONFIG_DAMON_VADDR_KUNIT_TEST n
  # update_config  n
  update_config CONFIG_DEBUG_RODATA_TEST n
  update_config CONFIG_DMAPOOL_TEST n
  update_config CONFIG_DRM_SCHED_KUNIT_TEST n
  update_config CONFIG_DRM_VKMS_KUNIT_TEST n
  update_config CONFIG_EFI_TEST m
  update_config CONFIG_EXEC_KUNIT_TEST n
  update_config CONFIG_FPGA_KUNIT_TESTS n
  update_config CONFIG_GUP_TEST n
  update_config CONFIG_HW_BREAKPOINT_KUNIT_TEST n
  update_config CONFIG_INITRAMFS_TEST n
  update_config CONFIG_INTERVAL_TREE_TEST n
  update_config CONFIG_KPROBE_EVENT_GEN_TEST n
  update_config CONFIG_LEDS_KUNIT_TEST n
  update_config CONFIG_MAILBOX_TEST n
  update_config CONFIG_MCTP_TEST n
  update_config CONFIG_NITRO_ENCLAVES_MISC_DEV_TEST n
  update_config CONFIG_OF_KUNIT_TEST n
  update_config CONFIG_OF_OVERLAY_KUNIT_TEST n
  update_config CONFIG_OF_UNITTEST n
  update_config CONFIG_PCI_ENDPOINT_TEST n
  update_config CONFIG_PERCPU_TEST n
  update_config CONFIG_PKCS7_TEST_KEY n
  update_config CONFIG_PM_QOS_KUNIT_TEST n
  update_config CONFIG_PREEMPTIRQ_DELAY_TEST n
  update_config CONFIG_RANDSTRUCT_KUNIT_TEST n
  update_config CONFIG_RBTREE_TEST n
  update_config CONFIG_RCU_REF_SCALE_TEST n
  update_config CONFIG_RCU_SCALE_TEST n
  update_config CONFIG_RTC_DRV_TEST n
  update_config CONFIG_SECURITY_APPARMOR_KUNIT_TEST n
  update_config CONFIG_SECURITY_IPE_KUNIT_TEST n
  update_config CONFIG_SECURITY_LANDLOCK_KUNIT_TEST n
  update_config CONFIG_TEST_ASYNC_DRIVER_PROBE n
  update_config CONFIG_TEST_BITMAP n
  update_config CONFIG_TEST_BITOPS n
  update_config CONFIG_TEST_DHRY n
  update_config CONFIG_TEST_DIV64 n
  update_config CONFIG_TEST_FIRMWARE n
  update_config CONFIG_TEST_FREE_PAGES n
  update_config CONFIG_TEST_HEXDUMP n
  update_config CONFIG_TEST_HMM m
  update_config CONFIG_TEST_IDA n
  update_config CONFIG_TEST_KMOD n
  update_config CONFIG_TEST_LKM n
  update_config CONFIG_TEST_MAPLE_TREE n
  update_config CONFIG_TEST_MEMCAT_P n
  update_config CONFIG_TEST_MEMINIT n
  update_config CONFIG_TEST_MIN_HEAP n
  update_config CONFIG_TEST_REF_TRACKER n
  update_config CONFIG_TEST_RHASHTABLE n
  update_config CONFIG_TEST_STATIC_KEYS n
  update_config CONFIG_TEST_SYSCTL n
  update_config CONFIG_TEST_UBSAN n
  update_config CONFIG_TEST_UDELAY n
  update_config CONFIG_TEST_UUID n
  update_config CONFIG_TEST_XARRAY n
  update_config CONFIG_USB4_KUNIT_TEST n
  update_config CONFIG_VCAP_KUNIT_TEST n
  update_config CONFIG_XZ_DEC_TEST n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n
# update_config  n


scripts/config --file .config --enable CONFIG_NET_9P
scripts/config --file .config --enable CONFIG_NET_9P_VIRTIO
scripts/config --file .config --enable CONFIG_9P_FS
update_config CONFIG_NET_9P y
update_config CONFIG_NET_9P_VIRTIO y
update_config CONFIG_9P_FS y

# Increase memory pool for kmemleak
update_config CONFIG_DEBUG_KMEMLEAK_MEM_POOL_SIZE 64000

export EXTRAVERSION=""
git config --global user.email "shardulsb08@gmail.com"
git config --global user.name "Shardul Bankar"
# git am ../kernel_patches/v6.1.74/0001*
# git am ../kernel_patches/v6.1.99/0001*
git am ../kernel_patches/ebpf/selftests/deps/0001*
git am ../kernel_patches/ebpf/selftests/deps/0002*
#git am ../kernel_patches/ebpf/brf/kcov_for_bpf/0001-bpf-Add-BRF-coverage-collection-*.patch
git am ../kernel_patches/ebpf/brf/kcov_for_bpf/v03/0001*.patch
git am ../kernel_patches/ebpf/brf/kcov_for_bpf/v03/0002*.patch
git am ../kernel_patches/ebpf/brf/kcov_for_bpf/v03/0003*.patch

export LOCALVERSION="_net_next_$(date +%y_%m_%d_%H%M)"
# 4. Build the kernel image and modules with ccache
log "Building kernel bzImage..."
make CC="ccache gcc" -j"$(nproc)" bzImage

log "Building kernel modules..."
make CC="ccache gcc" -j"$(nproc)" modules

# 5. Copy artifacts

# Determine the full kernel version
log "Determining full kernel version..."
FULL_KVER=$(make kernelrelease)
log "Full kernel version: $FULL_KVER"

OUT_DIR="/build/out/kernel_artifacts/v${FULL_KVER}"
mkdir -p "$OUT_DIR"
log "Copying kernel image (bzImage) to ${OUT_DIR}/vmlinuz-${FULL_KVER}..."
cp arch/x86/boot/bzImage "$OUT_DIR/vmlinuz-${FULL_KVER}"
cp .config "$OUT_DIR/config-${FULL_KVER}"

# Install modules
log "Installing kernel modules into ${OUT_DIR}..."
make modules_install INSTALL_MOD_PATH="$OUT_DIR"
make headers_install INSTALL_MOD_PATH="$OUT_DIR"

log "Kernel build complete. Artifacts are available in ${OUT_DIR}."
