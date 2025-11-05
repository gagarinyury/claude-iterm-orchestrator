#!/bin/bash

# Smart Restart Worker
# Gracefully restarts worker with context preservation
# Usage: smart-restart.sh <worker_id> [reason]

WORKER_ID="${1:-}"
REASON="${2:-manual_restart}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "worker_id is required"}'
    exit 1
fi

RESTART_LOG="/tmp/claude-restarts/$WORKER_ID.log"
mkdir -p "/tmp/claude-restarts"

# Log restart
echo "$(date +%s)|$REASON" >> "$RESTART_LOG"

# Count restarts in last hour
COUNT_LAST_HOUR=$(awk -v cutoff="$(($(date +%s) - 3600))" '$1 > cutoff' "$RESTART_LOG" 2>/dev/null | wc -l | tr -d ' ')

# If too many restarts, fail
if [ "$COUNT_LAST_HOUR" -gt 5 ]; then
    cat <<EOF
{
  "error": "Too many restarts in last hour ($COUNT_LAST_HOUR). Worker may be unstable.",
  "worker_id": "$WORKER_ID",
  "restart_count": $COUNT_LAST_HOUR,
  "suggestion": "Check worker logs or manually investigate"
}
EOF
    exit 1
fi

# Step 1: Save context
echo "Saving context..." >&2
SAVE_RESULT=$("$SCRIPT_DIR/save-context.sh" "$WORKER_ID")
SAVE_SUCCESS=$(echo "$SAVE_RESULT" | jq -r '.saved // false')

if [ "$SAVE_SUCCESS" != "true" ]; then
    cat <<EOF
{
  "error": "Failed to save context",
  "worker_id": "$WORKER_ID",
  "save_error": $(echo "$SAVE_RESULT" | jq -c '.')
}
EOF
    exit 1
fi

# Step 2: Restart iTerm session
PYTHON_SCRIPT=$(cat <<EOF
import iterm2
import json
import sys
import asyncio

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Find worker session
        target_session = None
        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id == "$WORKER_ID":
                            target_session = session
                            break
                    except:
                        pass
                if target_session:
                    break
            if target_session:
                break

        if not target_session:
            print(json.dumps({"error": "Worker not found"}))
            sys.exit(1)

        # Restart session
        await target_session.async_restart()

        # Wait for shell to be ready
        await asyncio.sleep(2)

        result = {
            "success": True,
            "worker_id": "$WORKER_ID",
            "action": "restarted",
            "reason": "$REASON"
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

echo "Restarting session..." >&2
RESTART_RESULT=$(echo "$PYTHON_SCRIPT" | python3 2>&1)
RESTART_SUCCESS=$(echo "$RESTART_RESULT" | jq -r '.success // false')

if [ "$RESTART_SUCCESS" != "true" ]; then
    cat <<EOF
{
  "error": "Failed to restart session",
  "worker_id": "$WORKER_ID",
  "restart_error": $(echo "$RESTART_RESULT" | jq -c '.')
}
EOF
    exit 1
fi

# Step 3: Wait for shell to be ready
sleep 2

# Step 4: Restore context
echo "Restoring context..." >&2
RESTORE_RESULT=$("$SCRIPT_DIR/restore-context.sh" "$WORKER_ID")
RESTORE_SUCCESS=$(echo "$RESTORE_RESULT" | jq -r '.success // false')

if [ "$RESTORE_SUCCESS" != "true" ]; then
    cat <<EOF
{
  "warning": "Worker restarted but context restoration failed",
  "worker_id": "$WORKER_ID",
  "restore_error": $(echo "$RESTORE_RESULT" | jq -c '.')
}
EOF
    exit 0
fi

# Success
cat <<EOF
{
  "success": true,
  "worker_id": "$WORKER_ID",
  "reason": "$REASON",
  "restart_count_last_hour": $COUNT_LAST_HOUR,
  "context_restored": true,
  "message": "Worker gracefully restarted with context preserved"
}
EOF
