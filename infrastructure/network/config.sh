#!/bin/bash

# =============================================================================
# Network Configuration Module
# =============================================================================
#
# This module provides a centralized configuration for all network-related
# settings across different testing modes (Local, Syzkaller, SyzGen++).
#
# Usage:
#   source infrastructure/network/config.sh
#   setup_network_config "SYZKALLER"
#
# Features:
# - Modular network configuration
# - Support for multiple testing modes
# - Consistent network settings across the project
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Prevent multiple inclusion
: "${__NETWORK_CONFIG_SH:=}"
[[ -n $__NETWORK_CONFIG_SH ]] && return
__NETWORK_CONFIG_SH=1

# Source common configuration if not already sourced
if [[ -z "${__COMMON_CONFIG_SH:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/../config-system/common.sh"
fi

# Network mode configurations
declare -A NETWORK_MODES=(
    [LOCAL]="default development mode"
    [SYZKALLER]="syzkaller testing mode"
    [SYZGEN]="syzgen++ testing mode"
)

# Port configurations
declare -A VM_PORTS=(
    [LOCAL]=2222
    [SYZKALLER]=2222
    [SYZGEN]=10021
)

# Host configurations
declare -A SSH_HOSTS=(
    [LOCAL]="localhost"
    [SYZKALLER]="localhost"
    [SYZGEN]="127.0.0.1"
)

# Port forwarding configurations
declare -A VM_HOSTFWD=(
    [LOCAL]="tcp::2222-:22"
    [SYZKALLER]="tcp::2222-:22"
    [SYZGEN]="tcp:127.0.0.1:10021-:22"
)

# Function to validate network mode
validate_network_mode() {
    local mode=$1
    if [[ -z "${NETWORK_MODES[$mode]:-}" ]]; then
        log_error "Invalid network mode '$mode'"
        log_error "Valid modes: ${!NETWORK_MODES[@]}"
        return 1
    fi
    return 0
}

# Function to setup network configuration
setup_network_config() {
    local mode=${1:-LOCAL}
    
    # Validate mode
    validate_network_mode "$mode" || return 1
    
    # Export network configuration
    export NETWORK_MODE="$mode"
    export VM_SSH_PORT="${VM_PORTS[$mode]}"
    export SSH_HOST="${SSH_HOSTS[$mode]}"
    export VM_HOSTFWD="${VM_HOSTFWD[$mode]}"
    
    # Log configuration (if not in quiet mode)
    if ! is_quiet; then
        log_info "Network Configuration:"
        log_info "  Mode: $mode (${NETWORK_MODES[$mode]})"
        log_info "  SSH Port: $VM_SSH_PORT"
        log_info "  SSH Host: $SSH_HOST"
        log_info "  Host Forwarding: $VM_HOSTFWD"
    fi
}

# Function to get current network configuration
get_network_config() {
    cat <<EOF
Current Network Configuration:
  Mode: ${NETWORK_MODE:-Not Set}
  SSH Port: ${VM_SSH_PORT:-Not Set}
  SSH Host: ${SSH_HOST:-Not Set}
  Host Forwarding: ${VM_HOSTFWD:-Not Set}
EOF
}

# Function to list available network modes
list_network_modes() {
    echo "Available Network Modes:"
    for mode in "${!NETWORK_MODES[@]}"; do
        echo "  $mode: ${NETWORK_MODES[$mode]}"
    done
}

# Function to get current network mode
get_current_network_mode() {
    local mode="${NETWORK_MODE:-LOCAL}"
    # Validate the mode exists
    if ! validate_network_mode "$mode" 2>/dev/null; then
        log_error "Current network mode '$mode' is invalid"
        return 1
    fi
    echo "$mode"
}

# Set default configuration if not already set
if [[ -z "${NETWORK_MODE:-}" ]]; then
    setup_network_config "LOCAL"
fi 