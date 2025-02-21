#docker start -ai kernel_builder_container

docker run -it --entrypoint /bin/bash -v "$(pwd)/container_kernel_workspace":/build kernel-builder-fedora
