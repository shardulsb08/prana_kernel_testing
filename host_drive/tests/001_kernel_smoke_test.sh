#!/bin/bash
log() {
    echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

EXPECTED_KVER="$1"  # Kernel version passed as an argument
if [ -n "$EXPECTED_KVER" ]; then
    log "Verifying kernel version..."
    if [ "$(uname -r)" != "$EXPECTED_KVER" ]; then
        log "Error: Expected kernel $EXPECTED_KVER, got $(uname -r)"
        exit 1
    fi
else
    log "No kernel version specified; skipping version check."
fi

log "Checking if virtio_blk is available (built-in or loaded as module)..."
if zcat /proc/config.gz | grep -q "CONFIG_VIRTIO_BLK=y"; then
    log "virtio_blk is built-in"
elif lsmod | grep -q "virtio_blk"; then
    log "virtio_blk module is loaded"
else
    log "Error: virtio_blk is neither built-in nor loaded as a module"
    exit 1
fi

#Skipping FS check for now, as it is not very useful for vulnerability analysis
#log "Verifying root filesystem..."
#mount | grep "on / type" | grep -q "ext4" || {
#    log "Error: Root filesystem not mounted as ext4"
#    exit 1
#}

log "Testing network connectivity..."
ping -c 3 8.8.8.8 > /dev/null || {
    log "Error: Network connectivity test failed"
    exit 1
}

log "Testing disk I/O..."
echo "test" > /tmp/testfile && cat /tmp/testfile | grep -q "test" || {
    log "Error: Disk I/O test failed"
    exit 1
}

log "Checking available memory..."
free -m | grep Mem | awk '{if ($2 < 1000) exit 1}' || {
    log "Error: Available memory is less than 1GB"
    exit 1
}

log "Running stress test..."
stress-ng --cpu 4 --timeout 60s || {
    log "Error: Stress test failed"
    exit 1
}

log "Kernel smoke test passed."
