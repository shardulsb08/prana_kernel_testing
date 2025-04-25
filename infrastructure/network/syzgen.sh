#!/bin/bash

# =============================================================================
# SyzGen Network Configuration
# =============================================================================
#
# SyzGen-specific network settings and utilities.
# This module extends the base network configuration with SyzGen-specific
# functionality.
#
# Usage:
#   source infrastructure/network/syzgen.sh
#   setup_syzgen_network
# =============================================================================

# Source base network configuration
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# SyzGen-specific network setup
setup_syzgen_network() {
    # Configure network for SyzGen mode
    setup_network_config "SYZGEN"
    
    # Additional SyzGen-specific network setup
    export SYZGEN_DEBUG_PORT=$(find_free_port)
    export SYZGEN_MONITOR_PORT=$(find_free_port)
}

# Find a free port for SyzGen services
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

# Validate SyzGen network configuration
validate_syzgen_network() {
    local errors=0
    
    # Check if ports are set
    [[ -z "$SYZGEN_DEBUG_PORT" ]] && { echo "Error: SYZGEN_DEBUG_PORT not set"; errors=$((errors + 1)); }
    [[ -z "$SYZGEN_MONITOR_PORT" ]] && { echo "Error: SYZGEN_MONITOR_PORT not set"; errors=$((errors + 1)); }
    
    # Check if ports are available
    for port in "$SYZGEN_DEBUG_PORT" "$SYZGEN_MONITOR_PORT"; do
        if netstat -tuln | grep -q ":$port "; then
            echo "Error: Port $port is already in use"
            errors=$((errors + 1))
        fi
    done
    
    return $errors
}

# Function to setup additional network interfaces for SyzGen
setup_syzgen_interfaces() {
    # Add any SyzGen-specific network interface setup here
    # For example, setting up tap interfaces for kernel debugging
    :
} 