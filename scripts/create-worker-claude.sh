#!/bin/bash

# Create a new worker in iTerm2 and auto-start Claude CLI
# Usage: create-worker-claude.sh <name> [task] [claude_command] [parent_id] [role]

WORKER_NAME="${1:-Worker}"
TASK="${2:-No task}"
CLAUDE_CMD="${3:-claude+}"  # Default: "claude+" (bypass mode), can use "claude" for normal
PARENT_ID="${4:-}"  # Optional: parent orchestrator ID
ROLE="${5:-}"  # Optional: role (researcher, coder, tester, etc.)
WORKER_ID="worker-$(date +%s)-$(openssl rand -hex 3)"

# Get script directory to find roles/prompts.json
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROMPTS_FILE="$PROJECT_DIR/roles/prompts.json"

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

        # First, check if parent_id was provided
        if "$PARENT_ID":
            orchestrator_id = "$PARENT_ID"
        else:
            # Search for orchestrator in iTerm sessions
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

        # Always set parent_id if found
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

        # Wait for Claude to start
        await asyncio.sleep(2)

        # If role is specified, auto-send role prompt
        role_applied = False
        if "$ROLE":
            try:
                # Load role prompt from JSON file
                prompts_path = "$PROMPTS_FILE"
                with open(prompts_path, 'r') as f:
                    prompts = json.load(f)
                    role_prompt = prompts.get("$ROLE", "")

                if role_prompt:
                    # Send role prompt to Claude
                    await session.async_send_text(role_prompt)
                    await asyncio.sleep(0.1)
                    await session.async_send_text("\r")
                    role_applied = True
            except Exception as e:
                # If role prompt fails, continue anyway
                pass

        result = {
            "success": True,
            "worker_id": "$WORKER_ID",
            "worker_name": "$WORKER_NAME",
            "session_id": session.session_id,
            "tab_id": tab.tab_id,
            "claude_command": "$CLAUDE_CMD",
            "role": "$ROLE" if "$ROLE" else None,
            "role_applied": role_applied
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
