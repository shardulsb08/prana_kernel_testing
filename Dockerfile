FROM fedora:latest

# Install Fedora kernel build dependencies and additional tools
RUN dnf -y update && \
    dnf -y install \
        fedpkg \
        rpm-build \
        ncurses-devel \
        pesign \
        gcc \
        make \
        flex \
        bison \
        openssl \
        openssl-devel \
        openssl-devel-engine \
        elfutils-libelf-devel \
	elfutils-devel \
        wget \
        curl \
        jq \
        xz \
        bc \
        perl \
        openssl \
        dracut \
        ccache \
        rsync  \
        hostname \
        dwarves \
        git && \
    dnf clean all

WORKDIR /build

# Create infrastructure directory structure
RUN mkdir -p /build_scripts/infrastructure/kernel

# Copy the build script and logging script into the image
COPY build_kernel_fedora.sh /usr/local/bin/build_kernel_fedora.sh
COPY infrastructure/kernel/logging.sh /build_scripts/infrastructure/kernel/logging.sh
RUN chmod +x /usr/local/bin/build_kernel_fedora.sh

# Create a volume for output artifacts (kernel image, modules)
VOLUME ["/build"]

# Use the build script as the container entrypoint
ENTRYPOINT ["/usr/local/bin/build_kernel_fedora.sh"]
