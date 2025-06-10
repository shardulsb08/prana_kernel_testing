#!/bin/bash

# =============================================================================
# Kernel Build Logging Module
# =============================================================================
#
# This module provides comprehensive logging functionality for kernel builds.
# It handles log file creation, command output logging, and build summaries.
#
# Usage:
#   source infrastructure/kernel/logging.sh
#   init_kernel_logging
# =============================================================================

# Prevent multiple inclusion
: "${__KERNEL_LOGGING_SH:=}"
[[ -n $__KERNEL_LOGGING_SH ]] && return
__KERNEL_LOGGING_SH=1

# Default log directory
KERNEL_LOG_DIR="${KERNEL_LOG_DIR:-${PWD}/container_kernel_workspace/logs}"
BUILD_LOG_FILE="${KERNEL_LOG_DIR}/kernel_build.log"
ERROR_LOG_FILE="${KERNEL_LOG_DIR}/kernel_build_errors.log"
SUMMARY_LOG_FILE="${KERNEL_LOG_DIR}/kernel_build_summary.log"

# Color definitions for terminal output
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_NC='\033[0m'

# Initialize logging system
init_kernel_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$KERNEL_LOG_DIR"
    
    # Clear previous log files
    > "$BUILD_LOG_FILE"
    > "$ERROR_LOG_FILE"
    > "$SUMMARY_LOG_FILE"
    
    # Log initialization
    log_info "Kernel build logging initialized"
    log_info "Build log: $BUILD_LOG_FILE"
    log_info "Error log: $ERROR_LOG_FILE"
    log_info "ERROR_LOG_FILE:  $ERROR_LOG_FILE"
    ls $ERROR_LOG_FILE
    log_info "KERNEL_LOG_DIR: ${KERNEL_LOG_DIR}"
    ls $KERNEL_LOG_DIR
    log_info "Summary log: $SUMMARY_LOG_FILE"
}

# Log levels
log_info() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${COLOR_GREEN}[$timestamp] INFO: $*${COLOR_NC}"
    echo "[$timestamp] INFO: $*" >> "$BUILD_LOG_FILE"
}

log_warning() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${COLOR_YELLOW}[$timestamp] WARNING: $*${COLOR_NC}"
    echo "[$timestamp] WARNING: $*" >> "$BUILD_LOG_FILE"
    echo "[$timestamp] WARNING: $*" >> "$ERROR_LOG_FILE"
}

log_error() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${COLOR_RED}[$timestamp] ERROR: $*${COLOR_NC}"
    echo "[$timestamp] ERROR: $*" >> "$BUILD_LOG_FILE"
    echo "[$timestamp] ERROR: $*" >> "$ERROR_LOG_FILE"
}

log_command() {
    local cmd="$*"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${COLOR_BLUE}[$timestamp] EXECUTING: $cmd${COLOR_NC}"
    echo "[$timestamp] EXECUTING: $cmd" >> "$BUILD_LOG_FILE"
    
    # Execute command and capture output
    local output
    if output=$($cmd 2>&1); then
        echo "[$timestamp] SUCCESS: $cmd" >> "$BUILD_LOG_FILE"
        echo "$output" | while IFS= read -r line; do
            echo "[$timestamp] OUTPUT: $line" >> "$BUILD_LOG_FILE"
        done
        return 0
    else
        local status=$?
        echo "[$timestamp] FAILED: $cmd (exit code: $status)" >> "$BUILD_LOG_FILE"
        echo "[$timestamp] FAILED: $cmd (exit code: $status)" >> "$ERROR_LOG_FILE"
        echo "$output" | while IFS= read -r line; do
            echo "[$timestamp] ERROR OUTPUT: $line" >> "$BUILD_LOG_FILE"
            echo "[$timestamp] ERROR OUTPUT: $line" >> "$ERROR_LOG_FILE"
        done
        return $status
    fi
}

# Log build step
log_build_step() {
    local step="$1"
    local description="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${COLOR_BLUE}[$timestamp] BUILD STEP: $step - $description${COLOR_NC}"
    echo "[$timestamp] BUILD STEP: $step - $description" >> "$BUILD_LOG_FILE"
    echo "[$timestamp] BUILD STEP: $step - $description" >> "$SUMMARY_LOG_FILE"
}

# Log build completion
log_build_complete() {
    local status="$1"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    if [ "$status" -eq 0 ]; then
        echo -e "${COLOR_GREEN}[$timestamp] BUILD COMPLETE: Success${COLOR_NC}"
        echo "[$timestamp] BUILD COMPLETE: Success" >> "$BUILD_LOG_FILE"
        echo "[$timestamp] BUILD COMPLETE: Success" >> "$SUMMARY_LOG_FILE"
    else
        echo -e "${COLOR_RED}[$timestamp] BUILD COMPLETE: Failed (exit code: $status)${COLOR_NC}"
        echo "[$timestamp] BUILD COMPLETE: Failed (exit code: $status)" >> "$BUILD_LOG_FILE"
        echo "[$timestamp] BUILD COMPLETE: Failed (exit code: $status)" >> "$SUMMARY_LOG_FILE"
    fi
}

# Export functions
export -f init_kernel_logging
export -f log_info
export -f log_warning
export -f log_error
export -f log_command
export -f log_build_step
export -f log_build_complete 
