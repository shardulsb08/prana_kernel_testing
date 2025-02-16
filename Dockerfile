# Use the minimal Fedora image as base
FROM fedora:latest

# Update system and install dependencies required for kernel build
RUN dnf -y update && \
    dnf -y install \
        gcc \
        make \
        ncurses-devel \
        bison \
        flex \
        openssl-devel \
        elfutils-libelf-devel \
        wget \
        curl \
        jq \
        xz && \
    dnf clean all

# Set working directory
WORKDIR /build

# Copy the kernel build script into the container and make it executable
COPY build_kernel.sh /usr/local/bin/build_kernel.sh
RUN chmod +x /usr/local/bin/build_kernel.sh

# Declare a volume for output artifacts.
# To have the host receive the output, run the container with a bind mount:
#   docker run --rm -v $(pwd)/out:/build/out kernel-builder
VOLUME ["/build/out"]

# Use the build script as the container entrypoint
ENTRYPOINT ["/usr/local/bin/build_kernel.sh"]
