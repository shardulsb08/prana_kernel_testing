#!/bin/bash

# =============================================================================
# Syzkaller Kernel Configuration Module
# =============================================================================
#
# This module provides Syzkaller-specific kernel configuration settings.
#
# Usage:
#   source infrastructure/kernel/syzkaller.sh
#   setup_syzkaller_kernel
#
# Features:
# - Syzkaller-specific kernel configuration
# - Integration with base kernel config
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Prevent multiple inclusion
: "${__KERNEL_SYZKALLER_SH:=}"
[[ -n $__KERNEL_SYZKALLER_SH ]] && return
__KERNEL_SYZKALLER_SH=1

# Source base configuration if not already sourced
if [[ -z "${__KERNEL_CONFIG_SH:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# Syzkaller-specific kernel settings
SYZKALLER_KERNEL_ARGS="console=ttyS0 earlyprintk=serial"
SYZKALLER_DEBUG_OPTIONS="debug=1 ftrace=1"

# Function to setup Syzkaller kernel configuration
setup_syzkaller_kernel() {
    # Switch to Syzkaller mode
    setup_kernel_config "SYZKALLER"
    
    # Export Syzkaller-specific settings
    export KERNEL_CMDLINE="$SYZKALLER_KERNEL_ARGS $SYZKALLER_DEBUG_OPTIONS"
    
    # Log configuration (if not in quiet mode)
    if [[ -z "${QUIET:-}" ]]; then
        echo "Syzkaller Kernel Configuration:"
        echo "  Kernel Command Line: $KERNEL_CMDLINE"
    fi
}

# Function to get current Syzkaller kernel configuration
get_syzkaller_kernel_config() {
    get_kernel_config
    echo "Syzkaller-specific Configuration:"
    echo "  Kernel Command Line: ${KERNEL_CMDLINE:-Not Set}"
}

# Function to verify if we're in Syzkaller kernel mode
is_syzkaller_kernel_mode() {
    [[ "$(get_current_kernel_mode)" == "SYZKALLER" ]]
} 