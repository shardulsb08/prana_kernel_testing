docker build -t kernel-builder-fedora .
#docker run -it -v kernel_workspace:/build kernel-builder-fedora
docker run -it -v "$(pwd)/container_kernel_workspace":/build kernel-builder-fedora

#docker run -it -v "$(pwd)/out":/build/out --name kernel_builder_container kernel-builder-fedora
