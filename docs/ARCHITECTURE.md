# Kernel Testing Framework Architecture

This document provides a comprehensive overview of the kernel testing framework's architecture, components, and workflows.

## Overview

The framework consists of three main phases:
1. Build Phase (Kernel Compilation)
2. VM Phase (Environment Setup)
3. Test Phase (Validation & Fuzzing)

## Components

### 1. Build Phase
- **Entry Point**: `001_run_build_fedora.sh`
- **Environment**: Docker container (Fedora-based)
- **Key Features**:
  - Automated latest stable kernel fetch
  - Fedora Rawhide base configuration
  - Debug and test-specific options
  - Artifact management

### 2. VM Phase
- **Entry Point**: `002_launch_vm.sh`
- **Environment**: QEMU VM
- **Key Features**:
  - Cloud-init automation
  - Shared directory mounting
  - Dual network mode support
  - Kernel installation and boot

### 3. Test Phase
- **Entry Point**: `003_run_tests.sh`
- **Components**:
  - Smoke Tests (VM-safe)
  - Syzkaller Fuzzing (Host-based)
- **Features**:
  - Phased test execution
  - Automated validation
  - Real-time monitoring

## Directory Structure

```
/ (root)
├── Scripts/
│   ├── 001_run_build_fedora.sh
│   ├── 002_launch_vm.sh
│   └── 003_run_tests.sh
├── Configuration/
│   ├── common.sh
│   ├── Dockerfile
│   └── test_config.txt
├── Shared Directories/
│   ├── host_drive/
│   │   └── tests/
│   └── container_kernel_workspace/
└── VM Resources/
    ├── seed.iso
    └── fedora_vm.qcow2
```

## Network Configuration

Two operational modes:
1. **Local Development**
   - Port: 2222
   - Host: localhost
   - Use: Development and testing

2. **SyzGen++ Integration**
   - Port: 10021
   - Host: 127.0.0.1
   - Use: Advanced testing

## Test Configuration

### Smoke Tests
- Kernel version validation
- Driver availability check
- Network connectivity
- Disk I/O operations
- Memory validation
- Stress testing

### Syzkaller Tests
- Kernel fuzzing
- Dynamic port allocation
- Web interface monitoring
- Automated crash detection
- Log management

## Usage Workflows

1. **Build Workflow**
   ```bash
   ./001_run_build_fedora.sh
   ```
   - Builds kernel in container
   - Generates artifacts
   - Prepares test environment

2. **VM Workflow**
   ```bash
   ./002_launch_vm.sh --install-kernel
   ```
   - Launches QEMU VM
   - Installs custom kernel
   - Configures networking

3. **Test Workflow**
   ```bash
   ./003_run_tests.sh
   ```
   - Executes smoke tests
   - Runs syzkaller fuzzing
   - Collects results

## Development Guidelines

1. **Adding New Tests**
   - Add test script to `host_drive/tests/`
   - Update `test_config.txt`
   - Implement in appropriate phase (VM/Host)

2. **Modifying Build Configuration**
   - Edit kernel configs in `build_input/`
   - Update `build_kernel_fedora.sh`
   - Test in isolated environment

3. **Network Configuration**
   - Modify `common.sh` for new modes
   - Update VM launch parameters
   - Test connectivity thoroughly

## Troubleshooting

Common issues and solutions:

1. **Build Failures**
   - Check Docker logs
   - Verify network connectivity
   - Validate kernel config

2. **VM Issues**
   - Verify QEMU installation
   - Check port availability
   - Validate cloud-init config

3. **Test Failures**
   - Check test logs
   - Verify kernel installation
   - Monitor system resources 