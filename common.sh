#!/bin/bash

# Common configuration variables

# Determine the script's directory for consistent file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

SSH_USER="user"
SSH_PASS="fedora"    # Default password (set in cloud-init)
VM_SSH_PORT=2222
SSH_HOST="localhost"

OUT_DIR="$SCRIPT_DIR/container_kernel_workspace/out"  # Directory with kernel artifacts

# Helper function for logging
log() {
    echo -e "\n\e[32m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

# Custom SSH function to handle both single commands and multi-line scripts
vm_ssh() {
    if [ "$1" == "--script" ]; then
        # Handle multi-line script (heredoc)
        sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${VM_SSH_PORT}" "${SSH_USER}@${SSH_HOST}" /bin/bash
    else
        # Handle single command
        local cmd="$1"
        sshpass -p "${SSH_PASS}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "${VM_SSH_PORT}" "${SSH_USER}@${SSH_HOST}" "$cmd"
    fi
}

# Function to wait for Cloud-Init to complete
wait_cloud_init() {
        log "Waiting for Cloud-Init to complete..."
        while ! vm_ssh "test -f /var/lib/cloud/instance/boot-finished"; do
                sleep 10
                log "Waiting for Cloud-Init to complete..."
        done
        log "Cloud-Init has completed."
}
