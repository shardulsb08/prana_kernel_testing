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

## Host Directory Mapping
The `host_drive/` directory in the project root is mapped to `/home/user/host_drive` inside the VM. It currently contains:
- `tests/`: Test scripts and configurations.

To share additional data with the VM (e.g., logs, patches), place it in `host_drive/` on the host, and access it from `/home/user/host_drive` in the VM.

## Test related configurations
The tests to run using the scripts should be added here:
host_drive/tests/test_config.txt
And the script to run the tests (along with the required configurations and dependencies setup) sequentially in path:
host_drive/tests/
Run these scripts by adding them as hooks in:
003_run_tests.sh
