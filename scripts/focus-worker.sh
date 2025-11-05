#!/bin/bash

# Focus Worker
# Switch focus to worker's tab and bring window to front
# Usage: focus-worker.sh <worker_id>

WORKER_ID="${1:-}"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "worker_id required"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<EOF
import iterm2
import json
import sys

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Find worker session
        target_session = None
        target_tab = None
        target_window = None

        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id == "$WORKER_ID":
                            target_session = session
                            target_tab = tab
                            target_window = window
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

        # Activate session
        await target_session.async_activate()

        # Activate window
        await target_window.async_activate()

        result = {
            "success": True,
            "worker_id": "$WORKER_ID",
            "message": "Worker brought to focus"
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

# Execute
echo "$PYTHON_SCRIPT" | python3 2>&1
