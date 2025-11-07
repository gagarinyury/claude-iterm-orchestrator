#!/bin/bash

# Broadcast message to all workers (and orchestrator)
# Usage: broadcast.sh <from_worker_id> <message>

FROM_WORKER_ID="${1:-unknown}"
MESSAGE="${2:-}"

if [ -z "$MESSAGE" ]; then
    echo '{"success": false, "error": "Message is required"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<EOF
import iterm2
import json
import sys
import asyncio

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        recipients = []
        sent_count = 0
        skipped_count = 0

        # Find all sessions with worker_id or orchestrator role
        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        role = await session.async_get_variable("user.role")
                        worker_name = await session.async_get_variable("user.worker_name") or "Unknown"

                        # Skip sender
                        if worker_id == "$FROM_WORKER_ID":
                            skipped_count += 1
                            continue

                        # Send to all sessions with worker_id (workers + orchestrator)
                        if worker_id:
                            # Format message with sender info
                            broadcast_msg = f"[BROADCAST from $FROM_WORKER_ID]: $MESSAGE"

                            # Send message
                            await session.async_send_text(broadcast_msg)
                            await asyncio.sleep(0.05)
                            await session.async_send_text("\\r")

                            recipients.append({
                                "worker_id": worker_id,
                                "worker_name": worker_name,
                                "role": role or "unknown"
                            })
                            sent_count += 1
                    except Exception as e:
                        # Skip sessions without worker_id
                        pass

        result = {
            "success": True,
            "from_worker_id": "$FROM_WORKER_ID",
            "message": "$MESSAGE",
            "sent_to": recipients,
            "sent_count": sent_count,
            "skipped_count": skipped_count
        }
        print(json.dumps(result))

    except Exception as e:
        error = {
            "success": False,
            "error": str(e),
            "from_worker_id": "$FROM_WORKER_ID"
        }
        print(json.dumps(error))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

# Execute Python script
echo "$PYTHON_SCRIPT" | python3 2>&1
