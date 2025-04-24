#!/bin/bash

# Common configuration variables

# Determine the script's directory for consistent file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

SSH_USER="user"
SSH_PASS="fedora"    # Default password (set in cloud-init)


SYZKALLER_SETUP="SYZKALLER_SYZGEN"
SYZKALLER_DEFAULT="SYZKALLER_LOCAL"
SYZKALLER_LOCAL_VM_PORT=2222
SYZKALLER_SYZGEN_VM_PORT=10021

# Calculate VM_SSH_PORT
TMP_SSH_PORT="${SYZKALLER_SETUP}_VM_PORT"
VM_SSH_PORT=${!TMP_SSH_PORT}

# Export VM_SSH_PORT if you need it to persist in the environment
export VM_SSH_PORT

# Clean up temporary variables
unset SYZKALLER_LOCAL_VM_PORT
unset SYZKALLER_SYZGEN_VM_PORT
unset TMP_SSH_PORT

# Optional: Verify the result
echo "VM_SSH_PORT is set to: $VM_SSH_PORT"

SYZKALLER_LOCAL_SSH_HOST="localhost"
SYZKALLER_SYZGEN_SSH_HOST="127.0.0.1"
# Calculate VM_HOST
TMP_SSH_HOST="${SYZKALLER_SETUP}_SSH_HOST"
SSH_HOST=${!TMP_SSH_HOST}

# SSH_HOST="127.0.0.1"
# Clean up temporary variables
unset SYZKALLER_LOCAL_SSH_HOST
unset SYZKALLER_SYZGEN_SSH_HOST
unset TMP_SSH_HOST

# Optional: Verify the result
echo "SSH_HOST is set to: $SSH_HOST"

SYZKALLER_LOCAL_VM_HOSTFWD="tcp::2222-:22"
SYZKALLER_SYZGEN_VM_HOSTFWD="tcp:127.0.0.1:10021-:22"
# Calculate VM_HOSTFWD
TMP_VM_HOSTFWD="${SYZKALLER_SETUP}_VM_HOSTFWD"
VM_HOSTFWD=${!TMP_VM_HOSTFWD}

# SSH_HOST="127.0.0.1"
# Clean up temporary variables
unset SYZKALLER_LOCAL_SSH_HOST
unset SYZKALLER_SYZGEN_SSH_HOST
unset TMP_SSH_HOST

# Optional: Verify the result
# echo "VM_HOSTFWD is set to: $VM_HOSTFWD"

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
