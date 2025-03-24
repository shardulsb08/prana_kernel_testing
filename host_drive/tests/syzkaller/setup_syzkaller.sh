#!/bin/bash

set -euo pipefail

# Define Syzkaller installation directory
PROJECT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
SYZKALLER_DIR="$PROJECT_DIR/host_drive/tests/syzkaller/syzkaller"

# Function to check if Syzkaller is installed and functioning
check_syzkaller() {
    if [ -d "$SYZKALLER_DIR" ] && [ -f "$SYZKALLER_DIR/bin/syz-manager" ] && [ -f "$SYZKALLER_DIR/bin/syz-execprog" ]; then
        # Check if syz-manager runs without errors (timeout after 5 seconds)
        if timeout 5 "$SYZKALLER_DIR/bin/syz-manager" --version > /dev/null 2>&1; then
            echo "Syzkaller is installed and functioning properly."
            return 0  # Success
        else
            echo "Syzkaller is installed but not functioning properly."
            return 1  # Failure
        fi
    else
        echo "Syzkaller is not installed."
        return 1  # Failure
    fi
}

# Function to install Syzkaller
install_syzkaller() {
    echo "Installing host dependencies..."
    sudo apt-get update
    sudo apt-get install -y git curl

    # Install Docker if not already present
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        echo "Docker installed. Note: You may need to add your user to the 'docker' group or run with sudo if permission issues occur."
    else
        echo "Docker is already installed."
    fi

    # Clone Syzkaller
    echo "Cloning Syzkaller repository..."
    git clone https://github.com/google/syzkaller.git "$SYZKALLER_DIR"

    # Build Syzkaller using syz-env with a pseudo-TTY
    echo "Building Syzkaller with syz-env..."
    cd "$SYZKALLER_DIR"
    script -c "./tools/syz-env make" /dev/null
}

# Main logic
if check_syzkaller; then
    echo "No action needed."
else
    if [ -d "$SYZKALLER_DIR" ]; then
        read -p "Syzkaller is not functioning properly. Do you want to reinstall? (y/n): " choice
        if [ "$choice" = "y" ]; then
            echo "Removing existing Syzkaller directory..."
            rm -rf "$SYZKALLER_DIR"
            install_syzkaller
        else
            echo "Skipping Syzkaller installation."
        fi
    else
        install_syzkaller
    fi
fi

echo "Syzkaller setup complete."
