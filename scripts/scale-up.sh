#!/bin/bash

# Scale Up - Create new worker
# Usage: scale-up.sh [worker_name] [task]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKER_NAME="${1:-AutoScaled-Worker}"
TASK="${2:-Auto-scaled worker}"

# Add timestamp to make unique
WORKER_NAME="$WORKER_NAME-$(date +%s)"

# Create worker with Claude
RESULT=$("$SCRIPT_DIR/create-worker-claude.sh" "$WORKER_NAME" "$TASK" "claude+")

# Check if successful
SUCCESS=$(echo "$RESULT" | jq -r '.success // false')

if [ "$SUCCESS" = "true" ]; then
    WORKER_ID=$(echo "$RESULT" | jq -r '.worker_id')

    cat <<EOF
{
  "success": true,
  "action": "scale_up",
  "worker_id": "$WORKER_ID",
  "worker_name": "$WORKER_NAME",
  "reason": "auto_scaling",
  "message": "Worker created successfully"
}
EOF
else
    cat <<EOF
{
  "success": false,
  "action": "scale_up",
  "error": "Failed to create worker",
  "details": $(echo "$RESULT" | jq -c '.')
}
EOF
    exit 1
fi
