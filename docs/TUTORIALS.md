# Development Tutorials

This document provides step-by-step tutorials for common development tasks in the kernel testing framework.

## Table of Contents
1. [Adding a New Kernel Test](#adding-a-new-kernel-test)
2. [Modifying Kernel Configuration](#modifying-kernel-configuration)
3. [Debugging Test Failures](#debugging-test-failures)
4. [Working with Syzkaller](#working-with-syzkaller)
5. [Custom Network Configuration](#custom-network-configuration)

## Adding a New Kernel Test

### Example: Adding Memory Leak Test

1. **Create the test script**:
   ```bash
   # host_drive/tests/003_memory_leak_test.sh
   #!/bin/bash

   log() {
       echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
   }

   # Enable kernel memory leak detection
   log "Enabling kmemleak..."
   echo scan > /sys/kernel/debug/kmemleak

   # Wait for initial scan
   sleep 30

   # Check for leaks
   log "Checking for memory leaks..."
   LEAKS=$(cat /sys/kernel/debug/kmemleak)

   if [ -n "$LEAKS" ]; then
       log "Memory leaks detected:"
       echo "$LEAKS"
       exit 1
   else
       log "No memory leaks found."
       exit 0
   fi
   ```

2. **Update test configuration**:
   ```bash
   # host_drive/tests/test_config.txt
   smoke_test
   memory_leak_test
   syzkaller
   ```

3. **Add test handler in `003_run_tests.sh`**:
   ```bash
   case "$test_name" in
       memory_leak_test)
           log "Running memory leak test..."
           chmod +x $VM_TESTS_DIR/003_memory_leak_test.sh
           $VM_TESTS_DIR/003_memory_leak_test.sh
           ;;
   esac
   ```

## Modifying Kernel Configuration

### Example: Adding New Debug Features

1. **Create custom config file**:
   ```bash
   # build_input/debug_features.config
   CONFIG_DEBUG_INFO=y
   CONFIG_DEBUG_INFO_DWARF4=y
   CONFIG_GDB_SCRIPTS=y
   CONFIG_DEBUG_KERNEL=y
   CONFIG_DEBUG_PAGEALLOC=y
   CONFIG_DEBUG_OBJECTS=y
   CONFIG_DEBUG_OBJECTS_FREE=y
   CONFIG_DEBUG_OBJECTS_TIMERS=y
   ```

2. **Update build script**:
   ```bash
   # build_kernel_fedora.sh
   if [ -f /build_input/debug_features.config ]; then
       log "Applying debug features configuration..."
       apply_kernel_configs /build_input/debug_features.config
   fi
   ```

## Debugging Test Failures

### Example: Debugging Smoke Test Failures

1. **Enable verbose logging**:
   ```bash
   # host_drive/tests/001_kernel_smoke_test.sh
   export DEBUG=1

   debug_log() {
       if [ "$DEBUG" = "1" ]; then
           echo "[DEBUG] $*" >> /tmp/smoke_test_debug.log
       fi
   }

   # Add debug logs
   debug_log "Checking kernel version: $(uname -r)"
   debug_log "Kernel config: $(zcat /proc/config.gz)"
   ```

2. **Check logs in VM**:
   ```bash
   # From host
   ssh -p 2222 user@localhost 'cat /tmp/smoke_test_debug.log'

   # Or use the vm_ssh function
   vm_ssh "cat /tmp/smoke_test_debug.log"
   ```

## Working with Syzkaller

### Example: Custom Syscall Coverage

1. **Create syscall allowlist**:
   ```bash
   # host_drive/tests/syzkaller/allowlist.txt
   # Only fuzz these syscalls
   read
   write
   open
   close
   socket
   connect
   ```

2. **Update Syzkaller config**:
   ```bash
   # host_drive/tests/002_run_syzkaller.sh
   cat > "$SYZKALLER_CONFIG" <<EOF
   {
       "target": "linux/amd64",
       "http": ":$HTTP_PORT",
       "workdir": "$SYZKALLER_DIR/syzkaller_workdir",
       "kernel_obj": "$KERNEL_BUILD_DIR",
       "syzkaller": "$SYZKALLER_BIN_DIR",
       "enable_syscalls": [
           $(tr '\n' ',' < "$SYZKALLER_DIR/allowlist.txt" | sed 's/,$//')
       ],
       "procs": 8,
       "type": "isolated",
       "vm": {
           "targets": ["localhost:2222"],
           "target_dir": "/tmp/syzkaller"
       }
   }
   EOF
   ```

3. **Monitor specific syscalls**:
   ```bash
   # Watch coverage for specific syscalls
   watch -n 5 'curl -s http://localhost:$HTTP_PORT/cover | grep -A 5 "read\|write"'
   ```

## Custom Network Configuration

### Example: Adding New Network Mode

1. **Update common.sh**:
   ```bash
   # common.sh
   CUSTOM_MODE_VM_PORT=2025
   CUSTOM_MODE_SSH_HOST="192.168.1.100"
   CUSTOM_MODE_VM_HOSTFWD="tcp::2025-:22"

   # Update VM_SSH_PORT calculation
   case "$SYZKALLER_SETUP" in
       "SYZKALLER_LOCAL")
           VM_SSH_PORT=$SYZKALLER_LOCAL_VM_PORT
           ;;
       "SYZKALLER_SYZGEN")
           VM_SSH_PORT=$SYZKALLER_SYZGEN_VM_PORT
           ;;
       "CUSTOM_MODE")
           VM_SSH_PORT=$CUSTOM_MODE_VM_PORT
           ;;
   esac
   ```

2. **Use in VM launch**:
   ```bash
   # 002_launch_vm.sh
   export SYZKALLER_SETUP="CUSTOM_MODE"
   ./002_launch_vm.sh --install-kernel
   ```

## Tips and Best Practices

1. **Test Development**:
   - Always add debug logging
   - Include cleanup in case of failures
   - Add timeouts for hanging operations
   - Validate prerequisites before test

2. **Kernel Configuration**:
   - Keep configs modular
   - Document dependencies
   - Test configs in isolation
   - Use `make nconfig` for exploration

3. **Network Setup**:
   - Test connectivity both ways
   - Add timeout to connection attempts
   - Log network operations
   - Handle connection failures gracefully