#!/bin/bash

set -euo pipefail

# Define directories and variables
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Now build the absolute path to the syzkaller binary/directory
SYZKALLER_BIN_DIR="$TEST_DIR/syzkaller/syzkaller"
SYZKALLER_DIR="$TEST_DIR/syzkaller"
SYZKALLER_CONFIG="$SYZKALLER_BIN_DIR/syzkaller.cfg"
SSH_KEY="$SYZKALLER_DIR/.ssh/syzkaller_id_rsa"
SSH_USER="user"
SSH_PASS="fedora"

# Initialize KVER to an empty value
KVER=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-dir)
            # If the --kernel-dir flag is passed, store the value in KVER
            KVER="$2"
            shift 2
            ;;
        *)
            # Process other arguments (you can add more cases if needed)
            shift
            ;;
    esac
done

KERNEL_BUILD_DIR="$SYZKALLER_DIR/kernel_build/v$KVER"

# Optionally print KVER to verify it's set
echo "Kernel directory is set to: $KVER"

# Ensure workdir exists
mkdir -p "$SYZKALLER_DIR/syzkaller_workdir"

# Generate SSH key if not exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Generating SSH key pair for Syzkaller..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N ""
fi
PUBLIC_KEY=$(cat "$SSH_KEY.pub")



# Generate Syzkaller configuration
echo "Generating Syzkaller configuration..."
cat > "$SYZKALLER_CONFIG" <<EOF
{
    "name": "fedora-vm",
    "target": "linux/amd64",
    "http": ":8080",
    "workdir": "$SYZKALLER_DIR/syzkaller_workdir",
    "kernel_obj": "$KERNEL_BUILD_DIR",
    "syzkaller": "$SYZKALLER_BIN_DIR",
    "procs": 8,
    "type": "isolated",
    "sshkey": "$SSH_KEY",
    "ssh_user": "user",
    "vm": {
        "targets": ["localhost:2222"],
        "target_dir": "/tmp/syzkaller",
        "target_reboot": false
    }
}
EOF

# Start Syzkaller
echo "Starting Syzkaller..."
"$SYZKALLER_BIN_DIR/bin/syz-manager" -config "$SYZKALLER_CONFIG"
