#!/bin/bash

# Monitor a variable for changes in a worker
# Usage: monitor-variable.sh <worker_id> <key> [duration_seconds]
# Returns current value and monitors for changes

WORKER_ID="$1"
KEY="$2"
DURATION="${3:-10}"  # Default 10 seconds

if [ -z "$WORKER_ID" ] || [ -z "$KEY" ]; then
    echo '{"error": "Missing worker_id or key"}'
    exit 1
fi

# Ensure key starts with "user."
if [[ ! "$KEY" =~ ^user\. ]]; then
    KEY="user.$KEY"
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys
import asyncio

WORKER_ID = sys.argv[1]
KEY = sys.argv[2]
DURATION = int(sys.argv[3])

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

        # Get initial value
        try:
            initial_value = await target_session.async_get_variable(KEY)
        except:
            initial_value = None

        changes = []
        changes.append({
            "timestamp": "initial",
            "value": initial_value
        })

        # Monitor for changes
        async def monitor_callback(update):
            new_value = update.new_value
            changes.append({
                "timestamp": str(asyncio.get_event_loop().time()),
                "value": new_value
            })

        # Create monitor
        monitor = iterm2.VariableMonitor(
            connection,
            iterm2.VariableScopes.SESSION,
            KEY,
            target_session.session_id
        )

        # Start monitoring
        await monitor.async_set_callback(monitor_callback)

        # Wait for specified duration
        await asyncio.sleep(DURATION)

        # Get final value
        try:
            final_value = await target_session.async_get_variable(KEY)
        except:
            final_value = None

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "key": KEY,
            "duration_seconds": DURATION,
            "initial_value": initial_value,
            "final_value": final_value,
            "changes": changes,
            "change_count": len(changes) - 1
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute Python script with arguments
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$KEY" "$DURATION" 2>&1
