#!/bin/bash

# =============================================================================
# Kernel Configuration Module
# =============================================================================
#
# This module provides a centralized configuration for all kernel-related
# settings across different testing modes (Local, Syzkaller, SyzGen++).
#
# Usage:
#   source infrastructure/kernel/config.sh
#   setup_kernel_config "SYZKALLER"
#
# Features:
# - Modular kernel configuration
# - Support for multiple testing modes
# - Consistent kernel settings across the project
# - Easy to extend for new modes
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Prevent multiple inclusion
: "${__KERNEL_CONFIG_SH:=}"
[[ -n $__KERNEL_CONFIG_SH ]] && return
__KERNEL_CONFIG_SH=1

# Default paths
KERNEL_ROOT="${KERNEL_ROOT:-${PWD}/container_kernel_workspace/linux}"
KERNEL_OUT="${KERNEL_OUT:-${PWD}/container_kernel_workspace/out/kernel_artifacts}"
KERNEL_CONFIG_DIR="${KERNEL_CONFIG_DIR:-${PWD}/configs/kernel}"

# Kernel mode configurations
declare -A KERNEL_MODES=(
    [LOCAL]="default development mode"
    [SYZKALLER]="syzkaller testing mode"
    [SYZGEN]="syzgen++ testing mode"
)

# Kernel configuration files
declare -A KERNEL_CONFIGS=(
    [LOCAL]="base/config-base"
    [SYZKALLER]="syzkaller/config-syzkaller"
    [SYZGEN]="syzgen/config-syzgen"
)

# Kernel build targets
declare -A KERNEL_TARGETS=(
    [LOCAL]="bzImage"
    [SYZKALLER]="bzImage"
    [SYZGEN]="bzImage"
)

# Function to validate kernel mode
validate_kernel_mode() {
    local mode=$1
    if [[ -z "${KERNEL_MODES[$mode]:-}" ]]; then
        echo "Error: Invalid kernel mode '$mode'" >&2
        echo "Valid modes: ${!KERNEL_MODES[@]}" >&2
        return 1
    fi
    return 0
}

# Function to setup kernel configuration
setup_kernel_config() {
    local mode=${1:-LOCAL}
    
    # Validate mode
    validate_kernel_mode "$mode" || return 1
    
    # Export kernel configuration
    export KERNEL_MODE="$mode"
    export KERNEL_CONFIG_FILE="${KERNEL_CONFIGS[$mode]}"
    export KERNEL_BUILD_TARGET="${KERNEL_TARGETS[$mode]}"
    
    # Create output directory if it doesn't exist
    mkdir -p "$KERNEL_OUT"
    
    # Log configuration (if not in quiet mode)
    if [[ -z "${QUIET:-}" ]]; then
        echo "Kernel Configuration:"
        echo "  Mode: $mode (${KERNEL_MODES[$mode]})"
        echo "  Config File: $KERNEL_CONFIG_FILE"
        echo "  Build Target: $KERNEL_BUILD_TARGET"
        echo "  Output Directory: $KERNEL_OUT"
    fi
}

# Function to get current kernel configuration
get_kernel_config() {
    cat <<EOF
Current Kernel Configuration:
  Mode: ${KERNEL_MODE:-Not Set}
  Config File: ${KERNEL_CONFIG_FILE:-Not Set}
  Build Target: ${KERNEL_BUILD_TARGET:-Not Set}
  Output Directory: ${KERNEL_OUT:-Not Set}
EOF
}

# Function to list available kernel modes
list_kernel_modes() {
    echo "Available Kernel Modes:"
    for mode in "${!KERNEL_MODES[@]}"; do
        echo "  $mode: ${KERNEL_MODES[$mode]}"
    done
}

# Function to get current kernel mode
get_current_kernel_mode() {
    local mode="${KERNEL_MODE:-LOCAL}"
    # Validate the mode exists
    if ! validate_kernel_mode "$mode" 2>/dev/null; then
        echo "Error: Current kernel mode '$mode' is invalid" >&2
        return 1
    fi
    echo "$mode"
}

# Set default configuration if not already set
if [[ -z "${KERNEL_MODE:-}" ]]; then
    setup_kernel_config "LOCAL"
fi 