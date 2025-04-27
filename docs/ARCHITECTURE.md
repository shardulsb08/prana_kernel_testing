# Project Architecture

This document describes the high-level architecture of the kernel testing framework.

## Overview

The project is organized into several key components:

1. Kernel Building and Configuration
   - Located in `configs/kernel/`
   - Handles kernel build configuration and customization
   - Manages kernel feature flags and options

2. VM Management
   - Located in `configs/vm/`
   - Handles VM creation and lifecycle
   - Manages VM networking and storage

3. Test Infrastructure
   - Located in `tools/`
   - Common utilities and helper functions
   - Test runners and frameworks

4. SyzKaller Integration
   - Located in `tools/syzkaller/`
   - Integration with syzkaller fuzzing framework
   - Custom syscall descriptions and configurations

5. SyzGen++ Integration
   - Located in `tools/syzgen/`
   - Integration with SyzGen++ for automated syscall discovery
   - Custom configurations and utilities

## Key Components

### Kernel Building

The kernel building process is managed through scripts in the root directory:
- `build_kernel.sh`: Main kernel build script
- `build_kernel_fedora.sh`: Fedora-specific kernel build
- `clear_kernel_out.sh`: Cleanup script

### VM Management

VM management is handled through:
- `002_launch_vm.sh`: VM launch and initialization
- Infrastructure in `infrastructure/vm-management/`

### Testing Framework

The testing framework consists of:
- Test runners in `tools/common/`
- Configuration management in `tools/*/config/`
- Utility functions in `tools/*/utils/`

### Container Management

Container lifecycle is managed through:
- `001_exec_container.sh`: Container execution
- `001_run_persistent_container.sh`: Long-running container management
- `001_reload_container.sh`: Container reload/restart

## Directory Structure

```
prana_kernel_testing/
├── configs/               # Configuration files
│   ├── kernel/           # Kernel configs
│   └── vm/               # VM configs
├── tools/                # Testing tools
│   ├── common/          # Shared utilities
│   ├── syzgen/          # SyzGen++ integration
│   └── syzkaller/       # Syzkaller integration
├── infrastructure/       # Infrastructure management
└── docs/                # Documentation
```

## Build Process

The build process follows these steps:

1. Configure kernel build environment
2. Build kernel with custom configurations
3. Create VM images
4. Deploy test environment
5. Execute tests

## Testing Flow

The testing process includes:

1. Environment setup
2. Kernel building
3. VM provisioning
4. Test execution
5. Result collection and analysis

## Future Improvements

Planned improvements include:

1. Enhanced automation
2. Better test coverage
3. Improved result analysis
4. More efficient resource usage 