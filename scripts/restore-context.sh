#!/bin/bash

# Restore Worker Context
# Restores worker's state from saved context
# Usage: restore-context.sh <worker_id>

WORKER_ID="${1:-}"
CONTEXT_DIR="/tmp/claude-contexts"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "worker_id is required"}'
    exit 1
fi

CONTEXT_FILE="$CONTEXT_DIR/$WORKER_ID.json"

if [ ! -f "$CONTEXT_FILE" ]; then
    echo '{"error": "No saved context found for this worker"}'
    exit 1
fi

# Read context
CONTEXT=$(cat "$CONTEXT_FILE")

# Extract variables
WORKER_NAME=$(echo "$CONTEXT" | jq -r '.variables.worker_name // "Unknown"')
STATUS=$(echo "$CONTEXT" | jq -r '.variables.status // "idle"')
TASK=$(echo "$CONTEXT" | jq -r '.variables.task // "No task"')
ROLE=$(echo "$CONTEXT" | jq -r '.variables.role // "worker"')
PARENT_ID=$(echo "$CONTEXT" | jq -r '.variables.parent_id // ""')

# Create Python script to restore variables
PYTHON_SCRIPT=$(cat <<EOF
import iterm2
import json
import sys

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

        # Restore variables
        await target_session.async_set_variable("user.worker_id", "$WORKER_ID")
        await target_session.async_set_variable("user.worker_name", "$WORKER_NAME")
        await target_session.async_set_variable("user.status", "$STATUS")
        await target_session.async_set_variable("user.task", "$TASK")
        await target_session.async_set_variable("user.role", "$ROLE")
        if "$PARENT_ID":
            await target_session.async_set_variable("user.parent_id", "$PARENT_ID")

        result = {
            "success": True,
            "worker_id": "$WORKER_ID",
            "restored_variables": {
                "worker_name": "$WORKER_NAME",
                "status": "$STATUS",
                "task": "$TASK",
                "role": "$ROLE"
            }
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

# Execute restore
echo "$PYTHON_SCRIPT" | python3 2>&1
