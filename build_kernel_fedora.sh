#!/bin/bash
set -euo pipefail
trap 'echo "Error at line ${LINENO}" >&2' ERR

# Source the logging module
source /build_scripts/infrastructure/kernel/logging.sh

# Initialize logging
init_kernel_logging

# Function to apply kernel configurations from a file
apply_kernel_configs() {
    local config_file=$1
    log_build_step "CONFIG" "Applying configurations from $config_file"
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
                log_command scripts/config --file .config --enable "$config"
                ;;
            "m")
                log_command scripts/config --file .config --module "$config"
                ;;
            "n")
                log_command scripts/config --file .config --disable "$config"
                ;;
            *)
                if [[ "$value" =~ ^[0-9]+$ ]]; then
                    # Handle numeric values
                    log_command scripts/config --file .config --set-val "$config" "$value"
                elif [[ "$value" =~ ^\".*\"$ ]]; then
                    # Handle string values (remove quotes)
                    val="${value:1:-1}"
                    log_command scripts/config --file .config --set-str "$config" "$val"
                else
                    log_warning "Unknown value '$value' for $config in $config_file"
                fi
                ;;
        esac
    done < "$config_file"
}

# Function to update a specific kernel configuration value
update_config() {
    local input_config="$1"
    local new_value="$2"
    # Note: Using ".config" as the file path is correct because this function
    # is called when the current directory is 'linux'.
    local config_file=".config"

    log_build_step "CONFIG_UPDATE" "Updating $input_config to '$new_value' in $config_file"

    # Use grep with Extended Regex to check if the config exists in any form.
    if grep -q -E "^${input_config}=|# ${input_config} is not set" "$config_file"; then
        # Use two separate, simpler sed commands for maximum compatibility.
        # This avoids complex regex and is safer across different sed versions.

        # 1. Replace the commented-out version, if it exists.
        sed -i "s|^# ${input_config} is not set|${input_config}=${new_value}|" "$config_file"

        # 2. Replace the version that already has a value. This will also match
        #    the line that was just modified by the command above, which is safe.
        sed -i "s|^${input_config}=.*|${input_config}=${new_value}|" "$config_file"

        log_info "Successfully updated $input_config to '$new_value'."
    else
        # If the config is not found in the .config file at all
        log_warning "$input_config not found in existing .config, if you want it, add it to an appropriate config file"
    fi
}

# Create output directory for artifacts
OUT_DIR="/build/out/kernel_artifacts"
log_build_step "SETUP" "Creating output directory: $OUT_DIR"
mkdir -p "$OUT_DIR"

# 1. Clone the upstream kernel source if not already present
if [ ! -d "linux" ]; then
    log_build_step "GIT" "Cloning upstream kernel source"
    attempt=0
    max_attempts=3
    until [ $attempt -ge $max_attempts ]; do
        if log_command git clone git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git; then
            break
        else
            attempt=$((attempt+1))
            log_warning "git clone attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        fi
    done
    if [ $attempt -eq $max_attempts ]; then
        log_error "Failed to clone kernel source after $max_attempts attempts."
        exit 1
    fi
fi

cd linux

# Add the stable kernel remote if not already present
log_build_step "GIT" "Adding stable kernel remote"
log_command git remote add stable git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git || true

# Fetch all tags from both remotes
log_build_step "GIT" "Fetching tags from origin remote"
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    if log_command git fetch --tags origin; then
        break
    else
        attempt=$((attempt+1))
        log_warning "git fetch origin attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log_error "Failed to fetch tags from origin after $max_attempts attempts."
    exit 1
fi

log_build_step "GIT" "Fetching tags from stable remote"
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    if log_command git fetch --tags stable; then
        break
    else
        attempt=$((attempt+1))
        log_warning "git fetch stable attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log_error "Failed to fetch tags from stable after $max_attempts attempts."
    exit 1
fi

# Get the latest stable version from kernel.org
log_build_step "VERSION" "Fetching latest stable kernel version"
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    LATEST_STABLE=$(curl -s https://www.kernel.org/finger_banner | grep "latest stable version" | awk '{print $NF}')
    LATEST_STABLE=6.6.94
    if [ -n "$LATEST_STABLE" ]; then
        break
    else
        attempt=$((attempt+1))
        log_warning "curl attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log_error "Failed to fetch kernel version after $max_attempts attempts."
    exit 1
fi

# Check out the corresponding tag
log_build_step "GIT" "Checking out kernel tag v${LATEST_STABLE}"
if ! log_command git checkout "v${LATEST_STABLE}"; then
    log_error "Failed to check out tag v${LATEST_STABLE}. It may not exist or tags are outdated."
    exit 1
fi

cd ..

# 2. Fetch a valid Fedora Rawhide kernel configuration
if [ ! -d "fedora_kernel" ]; then
    log_build_step "FEDORA" "Cloning Fedora kernel repository"
    attempt=0
    max_attempts=3
    until [ $attempt -ge $max_attempts ]; do
        if log_command fedpkg clone -a kernel fedora_kernel; then
            break
        else
            attempt=$((attempt+1))
            log_warning "fedpkg clone attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        fi
    done
    if [ $attempt -eq $max_attempts ]; then
        log_error "fedpkg clone failed after $max_attempts attempts."
        exit 1
    fi
else
    log_build_step "FEDORA" "Updating existing Fedora kernel repository"
    cd fedora_kernel
    log_command git checkout rawhide
    attempt=0
    max_attempts=3
    until [ $attempt -ge $max_attempts ]; do
        if log_command git pull; then
            break
        else
            attempt=$((attempt+1))
            log_warning "git pull attempt $attempt failed. Retrying in 5 seconds..."
            sleep 5
        fi
    done
    if [ $attempt -eq $max_attempts ]; then
        log_error "Failed to pull updates for fedora_kernel after $max_attempts attempts."
        exit 1
    fi
    cd ..
fi

# Copy the generated configuration for x86_64 from fedora_kernel into the Linux source
if [ ! -f "linux/.config" ]; then
    log_build_step "CONFIG" "Generating Fedora Rawhide configuration"
    cd fedora_kernel
    if [ ! -f ./generate_all_configs.sh ]; then
        log_error "generate_all_configs.sh not found in fedora_kernel directory"
        exit 1
    fi
    
    if [ ! -x ./generate_all_configs.sh ]; then
        log_build_step "CONFIG" "Setting execute permission on generate_all_configs.sh"
        if ! log_command chmod +x ./generate_all_configs.sh; then
            log_error "Failed to set execute permission on generate_all_configs.sh"
            exit 1
        fi
    fi

    if ! log_command ./generate_all_configs.sh; then
        log_warning "generate_all_configs.sh exited with a non-zero status"
    fi
    
    if [ ! -f kernel-x86_64-fedora.config ]; then
        log_error "Configuration file kernel-x86_64-fedora.config was not generated"
        exit 1
    fi

    log_command cp kernel-x86_64-fedora.config ../linux/.config
    cd ..
fi

cd linux

# Fetch all tags to ensure we have the latest
log_build_step "GIT" "Fetching all git tags"
attempt=0
max_attempts=3
until [ $attempt -ge $max_attempts ]; do
    if log_command git fetch --tags; then
        break
    else
        attempt=$((attempt+1))
        log_warning "git fetch attempt $attempt failed. Retrying in 5 seconds..."
        sleep 5
    fi
done
if [ $attempt -eq $max_attempts ]; then
    log_error "Failed to fetch tags after $max_attempts attempts."
    exit 1
fi

# Embed the config in the kernel image
log_build_step "CONFIG" "Enabling config embedding"
log_command scripts/config --file .config --enable CONFIG_IKCONFIG
log_command scripts/config --file .config --enable CONFIG_IKCONFIG_PROC

# 3. Update configuration
log_build_step "CONFIG" "Updating kernel configuration"
log_command make olddefconfig

# Determine the full kernel version
log_build_step "VERSION" "Determining full kernel version"
FULL_KVER=$(log_command make kernelrelease)
log_info "Full kernel version: $FULL_KVER"

# Check for test configurations and apply them
if [ -f /build_input/test_config.txt ]; then
    if grep -q '^syzkaller\b' /build_input/test_config.txt; then
        if [ -f /build_input/kernel_syskaller.config ]; then
            apply_kernel_configs /build_input/kernel_syskaller.config
        else
            log_error "/build_input/kernel_syskaller.config not found"
            exit 1
        fi
#        if [ -f /build_input/fuzz_config_untouched_only.config ]; then
#            apply_kernel_configs /build_input/fuzz_config_untouched_only.config
#        else
#            log_error "/build_input/fuzz_config_untouched_only.config not found"
#            exit 1
#        fi
    elif grep -q '^syzgen_config_raw\b' /build_input/test_config.txt; then
        if [ -f /build_input/kernel_syzgen_raw.config ]; then
            apply_kernel_configs /build_input/kernel_syzgen_raw.config
        else
            log_error "/build_input/kernel_syzgen_raw.config not found"
            exit 1
        fi
    elif grep -q '^syzgen_config_fuzz\b' /build_input/test_config.txt; then
        if [ -f /build_input/kernel_syzgen_fuzz.config ]; then
            apply_kernel_configs /build_input/kernel_syzgen_fuzz.config
        else
            log_error "/build_input/kernel_syzgen_fuzz.config not found"
            exit 1
        fi
    fi
else
    log_warning "/build_input/test_config.txt not found"
fi

# ======================================================================================
# EXAMPLE USAGE of update_config function
# You can call the new function here, after all base configs are set.
#
# update_config CONFIG_LOCK_TORTURE_TEST m
# update_config CONFIG_LOCALVERSION '"-custombuild"'
# update_config CONFIG_DEBUG_INFO y
# update_config CONFIG_RANDOM_STRUCT_PLUGIN n
# ======================================================================================
# update_config CONFIG_LOCK_TORTURE_TEST n
# update_config CONFIG_RCU_TORTURE_TEST n
# Embed the config in the kernel image
log_build_step "CONFIG" "Enabling config embedding"
log_command scripts/config --file .config --enable CONFIG_IKCONFIG
log_command scripts/config --file .config --enable CONFIG_IKCONFIG_PROC

# update_config CONFIG_RCU_SCALE_TEST n
# update_config CONFIG_RCU_REF_SCALE_TEST n
# update_config CONFIG_TEST_XARRAY n
update_config CONFIG_PROVE_RCU n
# update_config CONFIG_WW_MUTEX_SELFTEST n
# update_config CONFIG_TORTURE_TEST n
update_config CONFIG_LOCALVERSION '"-custombuild"'

# Embed the config in the kernel image
log_build_step "CONFIG" "Enabling config embedding"
log_command scripts/config --file .config --enable CONFIG_IKCONFIG
log_command scripts/config --file .config --enable CONFIG_IKCONFIG_PROC

# Enable REF_TRACKER by enabling network device refcount tracking
# This automatically selects CONFIG_REF_TRACKER without creating test modules
log_build_step "CONFIG" "Enabling REF_TRACKER infrastructure via network debugging"
log_command scripts/config --file .config --enable CONFIG_NET_DEV_REFCNT_TRACKER
log_info "CONFIG_NET_DEV_REFCNT_TRACKER enabled (which automatically enables CONFIG_REF_TRACKER)"
log_command scripts/config --file .config --enable CONFIG_NET_NS_REFCNT_TRACKER

# Verify the configuration
log_build_step "CONFIG" "Verifying REF_TRACKER configuration"
if grep -q "CONFIG_REF_TRACKER=y" .config; then
    log_info "CONFIG_REF_TRACKER is properly enabled"
else
    log_warning "CONFIG_REF_TRACKER not found in .config after enabling NET_DEV_REFCNT_TRACKER"
fi

# Patch Makefile.package to allow building kernel-devel RPM with binrpm-pkg
log_build_step "PATCH" "Removing --without devel from scripts/Makefile.package"
#sed -i 's/--without devel//g' scripts/Makefile.package
git config --global user.email "shardulsb08@gmail.com"
git config --global user.name "Shardul Bankar"

git am ../kernel_patches/0001-devel-package-Overwrite-rpmbuild-to-generate-devel-p.patch
# git am --abort
# export EXTRAVERSION=""
# echo '' > localversion-reset
# git checkout  v6.6.94-fuzz
export LOCALVERSION=""

# Build kernel-devel RPM using the kernel's built-in packaging
log_build_step "BUILD" "Building kernel-devel RPM"
cd ..
yes "" | make -C linux -j"$(nproc)" binrpm-pkg RPMOPTS="${RPMOPTS:+$RPMOPTS }--with devel"
log_info "Build complete"
cd linux

# Find and copy the resulting RPMs to the artifact output directory
OUT_DIR="/build/out/kernel_artifacts/v${FULL_KVER}"
log_build_step "ARTIFACTS" "Copying kernel RPMs to $OUT_DIR"
mkdir -p ${OUT_DIR}
RPM_DIR="rpmbuild/RPMS/x86_64"
if [ -d "$RPM_DIR" ]; then
    log_command cp $RPM_DIR/kernel-*.rpm "$OUT_DIR/" || log_warning "No kernel RPMs found in $RPM_DIR"
else
    log_warning "RPM directory $RPM_DIR not found; skipping RPM copy."
fi

# Log build completion
log_build_complete 0
