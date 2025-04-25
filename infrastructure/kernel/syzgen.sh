#!/bin/bash

# =============================================================================
# SyzGen Kernel Configuration Module
# =============================================================================
#
# This module provides SyzGen-specific kernel configuration settings.
#
# Usage:
#   source infrastructure/kernel/syzgen.sh
#   setup_syzgen_kernel
#
# Features:
# - SyzGen-specific kernel configuration
# - Integration with base kernel config
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Prevent multiple inclusion
: "${__KERNEL_SYZGEN_SH:=}"
[[ -n $__KERNEL_SYZGEN_SH ]] && return
__KERNEL_SYZGEN_SH=1

# Source base configuration if not already sourced
if [[ -z "${__KERNEL_CONFIG_SH:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# SyzGen-specific kernel settings
SYZGEN_KERNEL_ARGS="console=ttyS0 earlyprintk=serial"
SYZGEN_DEBUG_OPTIONS="debug=1 kasan=1 lockdep=1"

# Function to setup SyzGen kernel configuration
setup_syzgen_kernel() {
    # Switch to SyzGen mode
    setup_kernel_config "SYZGEN"
    
    # Export SyzGen-specific settings
    export KERNEL_CMDLINE="$SYZGEN_KERNEL_ARGS $SYZGEN_DEBUG_OPTIONS"
    
    # Log configuration (if not in quiet mode)
    if [[ -z "${QUIET:-}" ]]; then
        echo "SyzGen Kernel Configuration:"
        echo "  Kernel Command Line: $KERNEL_CMDLINE"
    fi
}

# Function to get current SyzGen kernel configuration
get_syzgen_kernel_config() {
    get_kernel_config
    echo "SyzGen-specific Configuration:"
    echo "  Kernel Command Line: ${KERNEL_CMDLINE:-Not Set}"
} 