#!/bin/bash

# Inject Output
# Inject text into worker's terminal as if it were program output
# Usage: inject-output.sh <worker_id> <text>

WORKER_ID="${1:-}"
TEXT="${2:-}"

if [ -z "$WORKER_ID" ] || [ -z "$TEXT" ]; then
    echo '{"error": "worker_id and text required"}'
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

        # Inject text as output (not input)
        await target_session.async_inject("$TEXT".encode())

        result = {
            "success": True,
            "worker_id": "$WORKER_ID",
            "injected_length": len("$TEXT"),
            "message": "Text injected successfully"
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
