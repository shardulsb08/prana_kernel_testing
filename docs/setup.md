Current Project Setup Documentation

This document provides a detailed snapshot of the current setup for building, installing, and running a custom Linux kernel on a Fedora Linux 38 (Cloud Edition) virtual machine (VM) using QEMU. It’s intended to serve as a reference for replication, troubleshooting, and future development. No custom patches have been applied yet, and the setup follows the processes outlined in your existing scripts.
1. Kernel Details

    Version: 6.13.4
    Build Environment: Docker container based on Fedora Rawhide
    Build Script: build_kernel_fedora.sh (located in the project root)
    Configuration:
        Based on Fedora Rawhide’s default kernel configuration
        Updated with make olddefconfig
        No custom tweaks applied
    Patches: None applied

2. Build Process

The kernel is built using the build_kernel_fedora.sh script. Here’s how it works:

    Steps:
        Clone the Linux kernel source from the stable branch (version 6.13.4).
        Fetch the Fedora Rawhide kernel configuration.
        Update the configuration using make olddefconfig.
        Compile the kernel with make bzImage and make modules.
        Install the compiled kernel image and modules into /build/out/kernel_artifacts.
    Output:
        Kernel image: bzImage
        Modules: Stored in a directory structure suitable for installation

3. VM Configuration

    Base Image: Fedora Cloud Base 38 (Fedora-Cloud-Base-38-1.6.x86_64.qcow2)
    Disk Image: fedora_vm.qcow2
        Size: 35GB
        Format: qcow2 with backing file linked to the base image
    Resources:
        RAM: 20GB
        vCPUs: 16
    Cloud-Init Configuration:
        Username: user
        Password: fedora
        SSH access enabled
    Filesystem:
        Root Filesystem: Btrfs on /dev/vda5
        Subvolume: root
        Mount Points: /boot, /home, /boot/efi

4. Custom Kernel Installation

The custom kernel is installed onto the VM using the load_kernel.sh script (located in the project root). Here’s the process:

    Steps:
        Copy the kernel image (bzImage-custom) and modules from /build/out/kernel_artifacts to the VM.
        Install the modules into /lib/modules/6.13.4 on the VM.
        Generate an initramfs using dracut for kernel version 6.13.4.
        Add a GRUB entry for the custom kernel using grubby, specifying rootflags=subvol=root in the boot parameters.
        Set the custom kernel as the default boot option and reboot the VM.

5. Verification

After installation, the setup was verified as follows:

    Kernel Version: Checked with uname -r (returns 6.13.4)
    Boot Parameters: Confirmed with cat /proc/cmdline
        Note: A duplicate root= entry appears but is ignored by the kernel
    Modules: Verified with lsmod (e.g., virtio_blk, e1000 loaded correctly)
    Logs: Reviewed with dmesg and journalctl
        Minor errors (e.g., floppy drive, PC speaker) observed but deemed ignorable
    Stress Test: Ran stress-ng --cpu 4 --timeout 60s successfully

6. Known Issues (Minor)

    Duplicate root= in Boot Parameters: Appears in /proc/cmdline but doesn’t affect functionality.
    Floppy Drive Errors: Related to emulated hardware, harmless.
    PC Speaker Driver Error: Non-critical, can be ignored.
    SSH Transient Errors: Likely from testing, not persistent.
