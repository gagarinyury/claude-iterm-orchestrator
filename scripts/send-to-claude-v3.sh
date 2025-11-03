#!/bin/bash

# Send message to Claude CLI - Version 3: Press Return key explicitly
# Usage: send-to-claude-v3.sh <worker_id> <message>

WORKER_ID="$1"
MESSAGE="$2"

if [ -z "$WORKER_ID" ] || [ -z "$MESSAGE" ]; then
    echo '{"error": "Missing worker_id or message"}'
    exit 1
fi

# Try 3: Send text + press Return key code explicitly
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

WORKER_ID = sys.argv[1]
MESSAGE = sys.argv[2]

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

        # Send text
        await target_session.async_send_text(MESSAGE)

        # Wait a tiny bit
        import asyncio
        await asyncio.sleep(0.05)

        # Send Return keycode (0x0d)
        await target_session.async_send_text("\r")

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "message_sent": MESSAGE,
            "method": "return_key"
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$MESSAGE" 2>&1
