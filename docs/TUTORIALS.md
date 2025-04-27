# Tutorials

This document provides step-by-step tutorials for common tasks in the kernel testing framework.

## Table of Contents

1. [Setting Up the Environment](#setting-up-the-environment)
2. [Building a Custom Kernel](#building-a-custom-kernel)
3. [Running Tests](#running-tests)
4. [Using SyzGen++](#using-syzgen)
5. [Using Syzkaller](#using-syzkaller)
6. [Debugging Issues](#debugging-issues)

## Setting Up the Environment

### Prerequisites
```bash
# Install required packages
sudo apt-get update
sudo apt-get install -y \
    qemu-system-x86 \
    docker.io \
    python3-pip \
    git

# Clone the repository
git clone https://github.com/your-org/prana_kernel_testing.git
cd prana_kernel_testing

# Setup configuration
cp config.example config
```

### Container Setup
```bash
# Build the container
./001_run_build_fedora.sh --build-only

# Start persistent container
./001_run_persistent_container.sh
```

## Building a Custom Kernel

### Basic Build
```bash
# Configure kernel
./build_kernel_fedora.sh --configure

# Build kernel
./build_kernel_fedora.sh --build

# Clean build artifacts
./clear_kernel_out.sh
```

### Custom Configuration
```bash
# Edit kernel config
vim configs/kernel/config-base

# Apply custom patches
cp your-patch.diff lockdep.diff
./build_kernel_fedora.sh --patch

# Build with custom config
./build_kernel_fedora.sh --config custom_config
```

## Running Tests

### Basic Testing
```bash
# Launch VM
./002_launch_vm.sh

# Run basic tests
./003_run_tests.sh --basic

# Run all tests
./003_run_tests.sh --all
```

### Custom Test Suite
```bash
# Create test directory
mkdir -p host_drive/tests/custom_suite

# Add test files
cp your_tests/* host_drive/tests/custom_suite/

# Run custom suite
./003_run_tests.sh --suite custom_suite
```

## Using SyzGen++

### Setup
```bash
# Initialize SyzGen++
cd SyzGenPlusPlus
./setup.sh

# Configure target
vim config/target.json

# Build tools
make tools
```

### Running Analysis
```bash
# Start analysis
./syzgen analyze --target linux

# Generate syscall descriptions
./syzgen generate --output descriptions

# Validate descriptions
./syzgen validate --input descriptions
```

## Using Syzkaller

### Configuration
```bash
# Setup syzkaller config
cp tools/syzkaller/config/config.example config/syzkaller.cfg

# Edit configuration
vim config/syzkaller.cfg

# Verify setup
./tools/syzkaller/check_setup.sh
```

### Running Fuzzer
```bash
# Start fuzzing
./tools/syzkaller/run.sh --config config/syzkaller.cfg

# Monitor progress
./tools/syzkaller/monitor.sh

# Collect results
./tools/syzkaller/collect_crashes.sh
```

## Debugging Issues

### VM Issues
```bash
# Check VM logs
tail -f vm_*.log

# Debug VM boot
./002_launch_vm.sh --debug

# Check network
./tools/common/utils/check_network.sh
```

### Kernel Issues
```bash
# Enable kernel debug
./build_kernel_fedora.sh --debug

# Analyze crash dumps
./tools/common/utils/analyze_crash.sh dumps/crash.log

# Check kernel logs
./tools/common/utils/fetch_kernel_logs.sh
```

### Container Issues
```bash
# Check container logs
docker logs kernel-build-container

# Enter container shell
./001_exec_container.sh

# Rebuild container
./001_run_build_fedora.sh --rebuild
```

## Tips and Tricks

### Performance Optimization
```bash
# Parallel kernel build
./build_kernel_fedora.sh --jobs $(nproc)

# Optimize VM memory
./002_launch_vm.sh --memory 4G

# Cache build artifacts
export CCACHE_DIR=/path/to/cache
```

### Development Workflow
```bash
# Quick test cycle
./tools/common/utils/quick_test.sh

# Development environment
./001_exec_container.sh --dev

# Clean environment
./tools/common/utils/clean_all.sh
```

### Troubleshooting
```bash
# Check system requirements
./tools/common/utils/check_requirements.sh

# Verify configurations
./tools/common/utils/verify_config.sh

# Generate debug info
./tools/common/utils/collect_debug_info.sh
```