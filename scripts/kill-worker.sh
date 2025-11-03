#!/bin/bash

# Kill a worker (close its iTerm tab)
# Usage: kill-worker.sh <worker_id>

WORKER_ID="$1"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "Missing worker_id"}'
    exit 1
fi

# Create Python script to kill worker
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

WORKER_ID = sys.argv[1]

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Find session by worker_id
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

        # Close the session (this closes the tab)
        await target_session.async_close(force=True)

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "action": "killed"
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" 2>&1
