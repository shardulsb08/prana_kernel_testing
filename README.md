# Kernel Build and Test Framework

This project provides a comprehensive framework for building custom Linux kernels, testing them in QEMU VMs, and running various test suites including Syzkaller.

## Quick Start

1. **Build the Kernel**:
```bash
./001_run_build_fedora.sh
```
This will:
- Set up Docker if not installed
- Build the kernel in a containerized environment
- Store artifacts in `container_kernel_workspace/out/kernel_artifacts/v<version>/`

2. **Launch and Test**:
```bash
# To launch VM, install kernel, and run tests:
./002_launch_vm.sh --install-kernel --run-tests

# To only launch VM and install kernel:
./002_launch_vm.sh --install-kernel

# To just launch the VM:
./002_launch_vm.sh
```

3. **Access the VM**:
```bash
ssh -p 2222 user@localhost  # For local testing
ssh -p 10021 user@127.0.0.1  # For SyzGen++ testing
```
Default credentials:
- Username: user
- Password: fedora

## Project Structure

### Build System
- `001_run_build_fedora.sh`: Docker setup and build orchestration
- `build_kernel_fedora.sh`: Main kernel build script
- `build_input/`: Directory for kernel configurations

### VM Management
- `002_launch_vm.sh`: VM creation and management
- `common.sh`: Shared functions and network configuration
- `cloud_init_checksums.txt`: Cloud-init configuration tracking

### Testing Framework
- `host_drive/tests/`: Test scripts and configurations
  - `test_config.txt`: Test suite configuration
  - `002_run_syzkaller.sh`: Syzkaller test integration
  - Other test scripts
- `003_run_tests.sh`: Test execution orchestration

## Directory Mapping
The `host_drive/` directory is mapped inside the VM:
- Host: `./host_drive/`
- VM: `/home/user/host_drive/`

Use this for sharing files between host and VM:
- Test configurations
- Test scripts
- Logs and results
- Patches and other files

## Network Configuration
Two network configurations are supported:
1. Local Testing:
   - SSH Port: 2222
   - Host: localhost

2. SyzGen++ Testing:
   - SSH Port: 10021
   - Host: 127.0.0.1

Configuration is managed through `SYZKALLER_SETUP` in `common.sh`.

## Test Configuration
1. Add test definitions to `host_drive/tests/test_config.txt`
2. Place test scripts in `host_drive/tests/`
3. Configure test hooks in `003_run_tests.sh`

Available test types:
- Basic smoke tests
- Syzkaller fuzzing
- Custom test suites

## Contributing
1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## Troubleshooting
Common issues and solutions:
1. VM SSH access issues:
   - Check VM status with `ps aux | grep qemu`
   - Verify port availability with `netstat -tulpn`
2. Kernel build failures:
   - Check Docker logs
   - Verify kernel config in `build_input/`
3. Test failures:
   - Check VM logs in `vm_*.log`
   - Review test logs in respective directories
