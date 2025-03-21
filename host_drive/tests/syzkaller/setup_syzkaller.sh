#!/bin/bash

set -euo pipefail

# Define Syzkaller installation directory
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SYZKALLER_DIR="$PROJECT_DIR/host_drive/tests/syzkaller/syzkaller"

# Install dependencies (adjust for your OS; this is for Ubuntu/Debian)
echo "Installing dependencies..."
sudo apt-get update
sudo apt-get install -y golang git make

# Clone Syzkaller if not already present
if [ ! -d "$SYZKALLER_DIR" ]; then
    echo "Cloning Syzkaller repository..."
    git clone https://github.com/google/syzkaller.git "$SYZKALLER_DIR"
else
    echo "Syzkaller repository already exists at $SYZKALLER_DIR"
fi

# Build Syzkaller
echo "Building Syzkaller..."
cd "$SYZKALLER_DIR"
make

echo "Syzkaller installed successfully at $SYZKALLER_DIR"
