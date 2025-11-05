#!/bin/bash

# Scale Down - Remove idle worker
# Usage: scale-down.sh <worker_id>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_ID="${1:-}"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "worker_id required"}'
    exit 1
fi

# Kill the worker
RESULT=$("$SCRIPT_DIR/kill-worker.sh" "$WORKER_ID")

# Check if successful
SUCCESS=$(echo "$RESULT" | jq -r '.success // false')

if [ "$SUCCESS" = "true" ]; then
    cat <<EOF
{
  "success": true,
  "action": "scale_down",
  "worker_id": "$WORKER_ID",
  "reason": "auto_scaling",
  "message": "Worker removed successfully"
}
EOF
else
    cat <<EOF
{
  "success": false,
  "action": "scale_down",
  "worker_id": "$WORKER_ID",
  "error": "Failed to remove worker",
  "details": $(echo "$RESULT" | jq -c '.')
}
EOF
    exit 1
fi
