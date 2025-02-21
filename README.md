# Kernel Build and Boot Project
This project builds a custom Linux kernel and installs it in a QEMU VM.

## Current Workflow
1. Build the kernel:
   ```bash
   ./run_build_fedora.sh

Compiled image is stored in out/ directory.

The ./load_kernel.sh script tries to isntall the kernel in QEMU VM.
Fedora default credentails:
uname: user
passwd: fedora

Access it via:
ssh -p 2222 user@localhost
