#!/bin/bash

set -euo pipefail

# Define directories and variables
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Now build the absolute path to the syzkaller binary/directory
SYZKALLER_BIN_DIR="$TEST_DIR/syzkaller/syzkaller"
SYZKALLER_DIR="$TEST_DIR/syzkaller"
SYZKALLER_CONFIG="$SYZKALLER_BIN_DIR/syzkaller.cfg"
SSH_KEY="$SYZKALLER_DIR/.ssh/syzkaller_id_rsa"
SSH_USER="root"
SSH_PASS="fedora"

# Initialize KVER to an empty value
KVER=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-dir)
            # If the --kernel-dir flag is passed, store the value in KVER
            KVER="$2"
            shift 2
            ;;
        *)
            # Process other arguments (you can add more cases if needed)
            shift
            ;;
    esac
done

KERNEL_BUILD_DIR="$SYZKALLER_DIR/kernel_build/v$KVER"

find_free_port() {
    while true; do
        PORT=$(( ( RANDOM % 10000 ) + 10000 ))  # Ports 10000-19999
        if ! nc -z localhost $PORT 2>/dev/null; then
            echo $PORT
            break
        fi
    done
}

# Optionally print KVER to verify it's set
echo "Kernel directory is set to: $KVER"

# Ensure workdir exists
mkdir -p "$SYZKALLER_DIR/syzkaller_workdir"

# Generate SSH key if not exists
if [ ! -f "$SSH_KEY" ]; then
    echo "Generating SSH key pair for Syzkaller..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY" -N ""
fi
PUBLIC_KEY=$(cat "$SSH_KEY.pub")


HTTP_PORT=$(find_free_port)
HTTP_PORT=8080
# Generate Syzkaller configuration
echo "Generating Syzkaller configuration..."
cat > "$SYZKALLER_CONFIG" <<EOF
{
    "name": "fedora-vm",
    "target": "linux/amd64",
    "http": ":$HTTP_PORT",
    "workdir": "$SYZKALLER_DIR/syzkaller_workdir",
    "kernel_obj": "$KERNEL_BUILD_DIR",
    "syzkaller": "$SYZKALLER_BIN_DIR",
    "procs": 8,
    "type": "isolated",
    "sshkey": "$SSH_KEY",
    "ssh_user": "root",
    "vm": {
        "targets": ["localhost:2222"],
        "target_dir": "/tmp/syzkaller",
        "target_reboot": false
    }
}
EOF

# Start Syzkaller
echo "Starting Syzkaller..."

# Check for existing instances
if pgrep -f "syz-manager"; then
    echo -e "\n\033[1;31mWarning: Another syz-manager instance is running!\033[0m"
    echo "Occupied ports:"
    sudo netstat -tulpn | grep "syz-manager" || echo "No ports detected."
    echo "Consider stopping it with './host_drive/tests/syzkaller/stop_syzkaller.sh'."
    read -p "Press Enter to continue anyway, or Ctrl+C to abort."
fi

# Start Syzkaller in background
echo "Starting Syzkaller in the background..."
echo "SYZKALLER_BIN_DIR: $SYZKALLER_BIN_DIR"
echo "SYZKALLER_CONFIG: $SYZKALLER_CONFIG"
echo "SYZKALLER_DIR: $SYZKALLER_DIR"
"$SYZKALLER_BIN_DIR/bin/syz-manager" -config "$SYZKALLER_CONFIG" -debug > "$SYZKALLER_DIR/syzkaller.log" 2>&1 &
SYZKALLER_PID=$!
echo "Syzkaller PID: $SYZKALLER_PID"
echo "Logs are being written to $SYZKALLER_DIR/syzkaller.log"

# Trap Ctrl+C and exit to stop Syzkaller
#trap 'echo "Stopping Syzkaller..."; kill $SYZKALLER_PID; wait $SYZKALLER_PID 2>/dev/null; echo "Syzkaller stopped."' INT TERM EXIT

# Periodically display fixed messages in the script's output
while true; do
    if ! kill -0 $SYZKALLER_PID 2>/dev/null; then
        echo "Syzkaller process $SYZKALLER_PID has stopped. Exiting loop."
        break
    fi
    clear  # Optional: clears the screen for a cleaner display
    echo -e "\033[1;33mSyzkaller web interface: http://localhost:$HTTP_PORT\033[0m"
    echo -e "\033[1;31mStop with: "kill $SYZKALLER_PID" or ./host_drive/tests/syzkaller/stop_syzkaller.sh\033[0m"
    echo "Occupied ports:"
    sudo netstat -tulpn | grep 'syz-manager' || echo "None"
    # Inform the user how to monitor logs
    echo "To view continuous Syzkaller logs, open a new terminal and run:"
    echo "  tail -f $SYZKALLER_DIR/syzkaller.log"
    echo "___________________________________________________________________________________"
    sleep 10  # Adjust interval as needed (e.g., every 30 seconds)
done &


## Basic colored output
#echo -e "\n\033[1;33mSyzkaller web interface is available at http://localhost:$HTTP_PORT\033[0m\n"
#echo -e "\033[1;31mTo stop Syzkaller, run: kill $SYZKALLER_PID or ./host_drive/tests/syzkaller/stop_syzkaller.sh (Kill all Syzkaller instances)\033[0m\n"
#
## Optional tmux split-screen
#if command -v tmux >/dev/null 2>&1; then
#    echo "Launching tmux for persistent display..."
#    tmux new-session -d -s syzkaller_display
#    tmux send-keys -t syzkaller_display "clear; while true; do echo -e '\033[1;33mSyzkaller web interface: http://localhost:$HTTP_PORT\033[0m'; echo -e '\033[1;31mStop with: kill $SYZKALLER_PID or ./host_drive/tests/syzkaller/stop_syzkaller.sh\033[0m'; echo 'Occupied ports:'; netstat -tulpn | grep 'syz-manager' || echo 'None'; sleep 5; done" C-m
#    tmux split-window -v -t syzkaller_display
#    tmux send-keys -t syzkaller_display "tail -f $SYZKALLER_DIR/syzkaller.log" C-m
#    tmux attach -t syzkaller_display
#else
#    echo "tmux not found. Install it for a split-screen display (e.g., 'sudo apt-get install tmux')."
#    echo "For now, monitor logs manually with: tail -f $SYZKALLER_DIR/syzkaller.log"
#fi
