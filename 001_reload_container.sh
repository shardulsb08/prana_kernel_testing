#!/bin/bash
CONTAINER_NAME="kernel_builder_container"
IMAGE_NAME="kernel-builder-fedora"

if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    echo "Container is already running."
elif [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    docker start -ai $CONTAINER_NAME
else
    docker run -it --name $CONTAINER_NAME -v "$(pwd)/container_kernel_workspace":/build $IMAGE_NAME
fi
