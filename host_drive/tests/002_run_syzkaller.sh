#!/bin/bash

set -euo pipefail

# Define directories and variables
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Now build the absolute path to the syzkaller binary/directory
SYZKALLER_BIN_DIR="$TEST_DIR/syzkaller/syzkaller"
SYZKALLER_DIR="$TEST_DIR/syzkaller"
SYZKALLER_CONFIG="$SYZKALLER_BIN_DIR/syzkaller.cfg"
KERNEL_BUILD_DIR="$SYZKALLER_DIR/kernel_build"
SSH_KEY="$SYZKALLER_DIR/.ssh/syzkaller_id_rsa"
SSH_USER="user"
SSH_PASS="fedora"

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
    "type": "ssh",
    "ssh": {
        "addr": "localhost:2222",
        "user": "$SSH_USER",
        "key": "$SSH_KEY"
    }
}
EOF

# Start Syzkaller
echo "Starting Syzkaller..."
"$SYZKALLER_BIN_DIR/bin/syz-manager" -config "$SYZKALLER_CONFIG"
