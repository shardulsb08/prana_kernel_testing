FROM fedora:latest

# Install Fedora kernel build dependencies plus additional tools
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
        perl && \
    dnf clean all

WORKDIR /build

# Copy our kernel build script into the image
COPY build_kernel_rpm.sh /usr/local/bin/build_kernel_rpm.sh
RUN chmod +x /usr/local/bin/build_kernel_rpm.sh

# Create a volume for output RPMs
VOLUME ["/build/out"]

# Use our script as the container entrypoint
ENTRYPOINT ["/usr/local/bin/build_kernel_rpm.sh"]
