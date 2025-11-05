#!/bin/bash

# Save Worker Context
# Saves worker's current state for later restoration
# Usage: save-context.sh <worker_id>

WORKER_ID="${1:-}"
CONTEXT_DIR="/tmp/claude-contexts"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "worker_id is required"}'
    exit 1
fi

# Create context directory
mkdir -p "$CONTEXT_DIR"

CONTEXT_FILE="$CONTEXT_DIR/$WORKER_ID.json"
TIMESTAMP=$(date +%s)

# Create Python script to get worker variables
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

        # Get all variables
        variables = {}
        var_names = [
            "worker_id", "worker_name", "status", "task",
            "created_at", "role", "parent_id", "current_task_id"
        ]

        for var_name in var_names:
            try:
                value = await target_session.async_get_variable(f"user.{var_name}")
                if value:
                    variables[var_name] = value
            except:
                pass

        # Get terminal content (last 50 lines)
        contents = await target_session.async_get_screen_contents()
        lines = []
        for i in range(max(0, contents.number_of_lines - 50), contents.number_of_lines):
            line = contents.line(i)
            lines.append(line.string)

        context = {
            "worker_id": "$WORKER_ID",
            "timestamp": $TIMESTAMP,
            "variables": variables,
            "terminal_content": lines,
            "session_id": target_session.session_id,
            "tab_id": target_session.tab.tab_id
        }

        print(json.dumps(context, indent=2))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

# Execute and save
CONTEXT=$(echo "$PYTHON_SCRIPT" | python3 2>&1)

echo "$CONTEXT" > "$CONTEXT_FILE"

# Add success flag
echo "$CONTEXT" | jq '. + {saved: true, context_file: "'"$CONTEXT_FILE"'"}'
