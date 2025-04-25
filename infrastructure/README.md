# Infrastructure

This directory contains the core infrastructure modules for the kernel testing framework.

## Directory Structure

```
infrastructure/
├── config-system/    # Configuration system utilities
├── kernel/          # Kernel-related configuration and utilities
│   ├── config/     # Kernel configuration files
│   ├── build/      # Kernel build utilities
│   └── test/       # Kernel test utilities
├── network/        # Network configuration and utilities
│   ├── config.sh   # Base network configuration
│   ├── syzkaller.sh # Syzkaller-specific network config
│   └── syzgen.sh   # SyzGen-specific network config
└── vm/            # VM management utilities
    ├── modes/     # VM operation modes
    └── config/    # VM configurations
```

## Modules

### Network Configuration
- Centralized network configuration for all testing modes
- Support for LOCAL, SYZKALLER, and SYZGEN modes
- Consistent network settings across the project

### Kernel Configuration
- Modular kernel configuration system
- Mode-specific kernel settings
- Build and test utilities

### VM Management
- VM lifecycle management
- Resource allocation
- Test environment setup

## Usage

Each module provides a set of shell functions that can be sourced and used in scripts:

```bash
# Source configuration modules
source infrastructure/network/config.sh
source infrastructure/kernel/config.sh

# Setup configurations
setup_network_config "SYZKALLER"
setup_kernel_config "SYZKALLER"
```

## Testing

Each module includes its own test suite:

```bash
# Run network configuration tests
./infrastructure/network/test_network.sh

# Run kernel configuration tests
./infrastructure/kernel/test_kernel.sh
``` 