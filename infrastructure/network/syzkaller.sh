#!/bin/bash

# =============================================================================
# Syzkaller Network Configuration Module
# =============================================================================
#
# This module provides Syzkaller-specific network configuration settings.
#
# Usage:
#   source infrastructure/network/syzkaller.sh
#   setup_syzkaller_network
#
# Features:
# - Syzkaller-specific network configuration
# - Integration with base network config
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Prevent multiple inclusion
: "${__NETWORK_SYZKALLER_SH:=}"
[[ -n $__NETWORK_SYZKALLER_SH ]] && return
__NETWORK_SYZKALLER_SH=1

# Source base configuration if not already sourced
if [[ -z "${__NETWORK_CONFIG_SH:-}" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/config.sh"
fi

# Syzkaller-specific network settings
SYZKALLER_HTTP_PORT=56741
SYZKALLER_RPC_PORT=56742

# Function to setup Syzkaller network configuration
setup_syzkaller_network() {
    # Switch to Syzkaller mode
    setup_network_config "SYZKALLER"
    
    # Export Syzkaller-specific settings
    export SYZKALLER_HTTP_PORT
    export SYZKALLER_RPC_PORT
    
    # Log configuration (if not in quiet mode)
    if ! is_quiet; then
        log_info "Syzkaller Network Configuration:"
        log_info "  HTTP Port: $SYZKALLER_HTTP_PORT"
        log_info "  RPC Port: $SYZKALLER_RPC_PORT"
    fi
}

# Function to get current Syzkaller network configuration
get_syzkaller_network_config() {
    get_network_config
    echo "Syzkaller-specific Configuration:"
    echo "  HTTP Port: ${SYZKALLER_HTTP_PORT:-Not Set}"
    echo "  RPC Port: ${SYZKALLER_RPC_PORT:-Not Set}"
}

# Function to verify if we're in Syzkaller mode
is_syzkaller_mode() {
    [[ "$(get_current_network_mode)" == "SYZKALLER" ]]
}

# Find a free port for Syzkaller services
find_free_port() {
    local port
    while true; do
        port=$(shuf -i 10000-65000 -n 1)
        if ! netstat -tuln | grep -q ":$port "; then
            echo "$port"
            break
        fi
    done
}

# Validate Syzkaller network configuration
validate_syzkaller_network() {
    local errors=0
    
    # Check if ports are set
    [[ -z "$SYZKALLER_HTTP_PORT" ]] && { echo "Error: SYZKALLER_HTTP_PORT not set"; errors=$((errors + 1)); }
    [[ -z "$SYZKALLER_RPC_PORT" ]] && { echo "Error: SYZKALLER_RPC_PORT not set"; errors=$((errors + 1)); }
    
    # Check if ports are available
    for port in "$SYZKALLER_HTTP_PORT" "$SYZKALLER_RPC_PORT"; do
        if netstat -tuln | grep -q ":$port "; then
            echo "Error: Port $port is already in use"
            errors=$((errors + 1))
        fi
    done
    
    return $errors
} 