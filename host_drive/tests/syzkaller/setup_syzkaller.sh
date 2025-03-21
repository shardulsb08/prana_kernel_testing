#!/bin/bash

set -euo pipefail

# Define Syzkaller installation directory
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SYZKALLER_DIR="$PROJECT_DIR/host_drive/tests/syzkaller/syzkaller"

# Install host dependencies (for Ubuntu/Debian)
echo "Installing host dependencies..."
sudo apt-get update
sudo apt-get install -y git curl

# Install Docker if not already present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo "Docker installed. Note: You may need to add your user to the 'docker' group or run this script with sudo if permission issues occur."
else
    echo "Docker is already installed."
fi

# Clone Syzkaller if not already present
if [ ! -d "$SYZKALLER_DIR" ]; then
    echo "Cloning Syzkaller repository..."
    git clone https://github.com/google/syzkaller.git "$SYZKALLER_DIR"
else
    echo "Syzkaller repository already exists at $SYZKALLER_DIR"
fi

# Build Syzkaller using syz-env
echo "Building Syzkaller with syz-env..."
cd "$SYZKALLER_DIR"
./tools/syz-env make

echo "Syzkaller installed successfully at $SYZKALLER_DIR"
