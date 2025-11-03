#!/bin/bash

# Send command to a worker
# Usage: send-command.sh <worker_id> <message>

WORKER_ID="$1"
MESSAGE="$2"

if [ -z "$WORKER_ID" ] || [ -z "$MESSAGE" ]; then
    echo '{"error": "Missing worker_id or message"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

WORKER_ID = sys.argv[1]
MESSAGE = sys.argv[2]

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

        # Send message as-is
        await target_session.async_send_text(MESSAGE)

        # Update last activity
        import time
        await target_session.async_set_variable("user.last_activity", str(int(time.time())))

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "message_sent": MESSAGE
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute Python script with arguments
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$MESSAGE" 2>&1
