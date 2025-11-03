#!/bin/bash

# Get detailed information about a worker
# Usage: get-worker-info.sh <worker_id>

WORKER_ID="$1"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "Missing worker_id"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

WORKER_ID = sys.argv[1]

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Find session
        target_session = None
        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id == WORKER_ID:
                            target_session = session
                            break
                    except:
                        pass
                if target_session:
                    break
            if target_session:
                break

        if not target_session:
            print(json.dumps({"error": f"Worker {WORKER_ID} not found"}))
            sys.exit(1)

        # Get all information
        info = {
            "success": True,
            "worker_id": WORKER_ID,
            "name": await target_session.async_get_variable("user.worker_name") or "Unknown",
            "status": await target_session.async_get_variable("user.status") or "unknown",
            "task": await target_session.async_get_variable("user.task") or "No task",
            "created_at": await target_session.async_get_variable("user.created_at") or "0",
            "parent_id": await target_session.async_get_variable("user.parent_id") or None,
            "last_activity": await target_session.async_get_variable("user.last_activity") or None,

            # Session info from iTerm2
            "foreground_job": await target_session.async_get_variable("session.foregroundJob") or "None",
            "working_directory": await target_session.async_get_variable("session.path") or "Unknown",
            "at_shell_prompt": await target_session.async_get_variable("session.isAtShellPrompt") or "unknown",
            "session_id": target_session.session_id
        }

        print(json.dumps(info))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" 2>&1
