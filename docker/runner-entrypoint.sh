#!/bin/sh
set -e

# Function to handle signals
cleanup() {
    echo "Received termination signal, shutting down..."
    if [ -n "$DOCKERD_PID" ]; then
        kill -TERM "$DOCKERD_PID" 2>/dev/null || true
        wait "$DOCKERD_PID" 2>/dev/null || true
    fi
    if [ -n "$RUNNER_PID" ]; then
        kill -TERM "$RUNNER_PID" 2>/dev/null || true
        wait "$RUNNER_PID" 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap cleanup TERM INT

# Start dockerd in background
echo "Starting dockerd..."
dockerd &
DOCKERD_PID=$!

# Wait for dockerd to be ready
echo "Waiting for dockerd to be ready..."
timeout=30
while [ $timeout -gt 0 ]; do
    if docker info >/dev/null 2>&1; then
        echo "dockerd is ready"
        break
    fi
    sleep 1
    timeout=$((timeout - 1))
done

if [ $timeout -eq 0 ]; then
    echo "dockerd failed to start within 30 seconds"
    exit 1
fi

# Start spacedock-runner
echo "Starting spacedock-runner..."
spacedock-runner &
RUNNER_PID=$!

# Wait for both processes to finish
wait $DOCKERD_PID $RUNNER_PID

# If we get here, one of the processes exited, so we should exit too
echo "One of the processes exited, shutting down..."
cleanup
