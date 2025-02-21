#!/bin/bash
docker build -t kernel-builder-fedora .
docker run -it -v "$(pwd)/container_kernel_workspace":/build --name kernel-builder-fedora-container kernel-builder-fedora
