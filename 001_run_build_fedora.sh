#!/bin/bash
# Build the Docker image and run a persistent container for kernel compilation
docker build -t kernel-builder-fedora .
docker run -it -v "$(pwd)/container_kernel_workspace":/build --name kernel-builder-fedora-container kernel-builder-fedora
