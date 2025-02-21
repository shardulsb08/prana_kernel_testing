#!/bin/bash
# run_build.sh
# Build the Docker image and run the container using a named volume (kernel_workspace)
docker build -t kernel-builder-fedora .
docker run --rm -it -v "$(pwd)/container_kernel_workspace":/build kernel-builder-fedora

