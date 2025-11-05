#!/bin/bash

# Set Worker Priority
# Set priority for a worker (affects load balancer decisions)
# Usage: set-worker-priority.sh <worker_id> <priority>
#        priority: high, medium, low

WORKER_ID="${1:-}"
PRIORITY="${2:-medium}"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "worker_id is required"}'
    exit 1
fi

# Validate priority
case "$PRIORITY" in
    high|medium|low)
        ;;
    *)
        echo '{"error": "Invalid priority. Use: high, medium, low"}'
        exit 1
        ;;
esac

# Create Python script to set priority variable
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

        # Set priority variable
        await target_session.async_set_variable("user.priority", "$PRIORITY")

        result = {
            "success": True,
            "worker_id": "$WORKER_ID",
            "priority": "$PRIORITY",
            "message": "Worker priority set to $PRIORITY"
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
