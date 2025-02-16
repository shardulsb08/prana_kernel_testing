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
        openssl-devel \
        elfutils-libelf-devel \
        wget \
        curl \
        jq \
        xz \
        bc \
        perl \
        openssl \
        git && \
    dnf clean all

WORKDIR /build

# Copy the build script into the image
COPY build_kernel_fedora.sh /usr/local/bin/build_kernel_fedora.sh
RUN chmod +x /usr/local/bin/build_kernel_fedora.sh

# Create a volume for output artifacts (kernel image, modules)
VOLUME ["/build/out"]

# Use the build script as the container entrypoint
ENTRYPOINT ["/usr/local/bin/build_kernel_fedora.sh"]
