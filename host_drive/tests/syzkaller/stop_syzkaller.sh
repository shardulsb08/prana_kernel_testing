#!/bin/bash
SYZKALLER_PID=$(pgrep -f "syz-manager")
if [ -n "$SYZKALLER_PID" ]; then
    echo "Stopping Syzkaller (PID $SYZKALLER_PID)..."
    kill $SYZKALLER_PID
    sleep 1  # Give it a moment to shut down
    if pgrep -f "syz-manager" > /dev/null; then
        echo "Syzkaller didn’t stop gracefully, forcing termination..."
        kill -9 $SYZKALLER_PID
    else
        echo "Syzkaller stopped successfully."
    fi
else
    echo "No running Syzkaller instance found."
fi
