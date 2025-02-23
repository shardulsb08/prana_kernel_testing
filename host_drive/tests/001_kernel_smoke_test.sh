#!/bin/bash
log() {
    echo -e "\n\e[34m[$(date +"%Y-%m-%d %H:%M:%S")] $*\e[0m\n"
}

EXPECTED_KVER="6.13.4"  # Adjust as needed or pass as an argument
log "Verifying kernel version..."
if [ "$(uname -r)" != "$EXPECTED_KVER" ]; then
    log "Error: Expected kernel $EXPECTED_KVER, got $(uname -r)"
    exit 1
fi

log "Checking loaded modules..."
lsmod | grep -q "virtio_blk" || {
    log "Error: virtio_blk module not loaded"
    exit 1
}

log "Verifying root filesystem..."
mount | grep "on / type" | grep -q "ext4" || {
    log "Error: Root filesystem not mounted as ext4"
    exit 1
}

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
