#!/bin/bash

# Common configuration variables
SSH_USER="user"
SSH_PASS="fedora"    # Default password (set in cloud-init)
VM_SSH_PORT=2222
SSH_HOST="localhost"

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
