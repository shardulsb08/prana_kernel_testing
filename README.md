# Kernel Build and Boot Project
This project builds a custom Linux kernel and installs it in a QEMU VM.

## Current Workflow
1. Build the kernel:
   In bash:
   ./run_build_fedora.sh

Compiled image is stored in container_kernel_workspace/out/kernel_artifacts/v<version>/.

2. Launch the VM:

To launch the VM and install the kernel:
In bash:
./002_launch_vm.sh --install-kernel
To launch the VM without installing the kernel:
./002_launch_vm.sh

3. Access the VM via SSH:
ssh -p 2222 user@localhost
Fedora default credentails:
uname: user
passwd: fedora

Access VM via:
ssh -p 2222 user@localhost
