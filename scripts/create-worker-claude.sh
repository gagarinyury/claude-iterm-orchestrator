#!/bin/bash

# Create a new worker in iTerm2 and auto-start Claude CLI
# Usage: create-worker-claude.sh <name> [task] [claude_command]

WORKER_NAME="${1:-Worker}"
TASK="${2:-No task}"
CLAUDE_CMD="${3:-claude}"  # Default: "claude", can use "claude+" for bypass
WORKER_ID="worker-$(date +%s)-$(openssl rand -hex 3)"

# Create Python script
PYTHON_SCRIPT=$(cat <<EOF
import iterm2
import json
import sys
import asyncio

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Use first window or create new one
        if len(app.terminal_windows) == 0:
            window = await iterm2.Window.async_create(connection)
            tab = window.current_tab
            session = tab.current_session
        else:
            window = app.terminal_windows[0]
            tab = await window.async_create_tab()
            session = tab.current_session

        # Find orchestrator
        orchestrator_id = None
        for win in app.windows:
            for t in win.tabs:
                for s in t.sessions:
                    try:
                        role = await s.async_get_variable("user.role")
                        if role == "orchestrator":
                            orchestrator_id = await s.async_get_variable("user.worker_id")
                            break
                    except:
                        pass
                if orchestrator_id:
                    break
            if orchestrator_id:
                break

        # Set worker variables
        await session.async_set_variable("user.worker_id", "$WORKER_ID")
        await session.async_set_variable("user.worker_name", "$WORKER_NAME")
        await session.async_set_variable("user.status", "idle")
        await session.async_set_variable("user.task", "$TASK")
        await session.async_set_variable("user.created_at", "$(date +%s)")
        await session.async_set_variable("user.role", "worker")
        if orchestrator_id:
            await session.async_set_variable("user.parent_id", orchestrator_id)

        # Set tab title
        await tab.async_set_title("$WORKER_NAME")

        # Wait for shell to be ready
        await asyncio.sleep(1)

        # Send Claude command
        await session.async_send_text("$CLAUDE_CMD")
        await asyncio.sleep(0.1)
        await session.async_send_text("\r")

        result = {
            "success": True,
            "worker_id": "$WORKER_ID",
            "worker_name": "$WORKER_NAME",
            "session_id": session.session_id,
            "tab_id": tab.tab_id,
            "claude_command": "$CLAUDE_CMD"
        }
        print(json.dumps(result))

    except Exception as e:
        error = {
            "error": str(e),
            "worker_id": "$WORKER_ID"
        }
        print(json.dumps(error))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

# Execute Python script
echo "$PYTHON_SCRIPT" | python3 2>&1

# Store worker info in a tracking file
if [ $? -eq 0 ]; then
    mkdir -p /tmp/workers
    echo "$WORKER_ID|$WORKER_NAME|$(date +%s)|$TASK|claude" >> /tmp/workers/registry.txt
fi
