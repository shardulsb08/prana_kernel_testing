#!/bin/bash

# Function to install Docker if not installed
install_docker() {
    echo "Docker is not installed. Installing Docker..."

    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg

    # Add Docker's official GPG key
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up the repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update

    # Install Docker Engine, CLI, containerd
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "Docker installed successfully."

    echo "Setting up post-installation for non-root user access"

    sudo groupadd docker
    sudo usermod -aG docker $USER
    newgrp docker
}

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    install_docker
else
    echo "Docker is already installed."
fi

# Prepare build input directory and copy test configuration files
mkdir -p "$(pwd)/container_kernel_workspace"
mkdir -p "$(pwd)/build_input"
cp host_drive/tests/test_config.txt "$(pwd)/build_input/"
cp host_drive/tests/syzkaller/kernel_syskaller.config "$(pwd)/build_input/"

# Build the Docker image and run the container
docker build -t kernel-builder-fedora .
docker run -it -v "$(pwd)/container_kernel_workspace":/build -v "$(pwd)/build_input":/build_input --name kernel-builder-fedora-container kernel-builder-fedora
