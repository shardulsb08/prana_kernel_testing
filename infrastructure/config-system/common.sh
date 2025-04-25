#!/bin/bash

# =============================================================================
# Common Configuration Module
# =============================================================================
#
# This module provides common utilities and settings used across all
# infrastructure modules.
#
# Usage:
#   source infrastructure/config-system/common.sh
#
# Features:
# - Common utility functions
# - Shared configuration settings
# - Error handling utilities
# =============================================================================

# Enable strict error checking
set -euo pipefail

# Prevent multiple inclusion
: "${__COMMON_CONFIG_SH:=}"
[[ -n $__COMMON_CONFIG_SH ]] && return
__COMMON_CONFIG_SH=1

# Determine script directory for consistent paths
TMP_SCRIPT_DIR=$SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." &>/dev/null && pwd)"
SCRIPT_DIR=$TMP_SCRIPT_DIR

# Common configuration settings
readonly CONFIG_MODES=(LOCAL SYZKALLER SYZGEN)
readonly DEFAULT_MODE="LOCAL"

# Color definitions for output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_NC='\033[0m'

# Logging functions
log() {
    echo -e "${COLOR_GREEN}[$(date +"%Y-%m-%d %H:%M:%S")] $*${COLOR_NC}"
}

log_error() {
    echo -e "${COLOR_RED}[ERROR] $*${COLOR_NC}" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}[WARNING] $*${COLOR_NC}" >&2
}

log_info() {
    echo -e "${COLOR_BLUE}[INFO] $*${COLOR_NC}"
}

# Error handling
handle_error() {
    local line_no=$1
    local error_code=$2
    log_error "Error occurred in script at line: ${line_no}"
    log_error "Exit code: ${error_code}"
    exit "${error_code}"
}

# Set up error trap
trap 'handle_error ${LINENO} $?' ERR

# Function to validate mode
validate_mode() {
    local mode=$1
    for valid_mode in "${CONFIG_MODES[@]}"; do
        if [[ "$mode" == "$valid_mode" ]]; then
            return 0
        fi
    done
    log_error "Invalid mode: $mode"
    log_error "Valid modes: ${CONFIG_MODES[*]}"
    return 1
}

# Function to check if running in quiet mode
is_quiet() {
    [[ -n "${QUIET:-}" ]]
}

# Function to get configuration directory
get_config_dir() {
    local module=$1
    echo "$PROJECT_ROOT/configs/$module"
}

# Export common variables
export PROJECT_ROOT
export CONFIG_MODES
export DEFAULT_MODE 
