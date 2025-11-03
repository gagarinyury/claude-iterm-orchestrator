#!/bin/bash

# Assign a task to a worker
# Usage: assign-task.sh <worker_id> <task_id> <task_description>

WORKER_ID="$1"
TASK_ID="$2"
TASK_DESCRIPTION="$3"

if [ -z "$WORKER_ID" ] || [ -z "$TASK_ID" ] || [ -z "$TASK_DESCRIPTION" ]; then
    echo '{"error": "Missing worker_id, task_id, or task_description"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys
import time

WORKER_ID = sys.argv[1]
TASK_ID = sys.argv[2]
TASK_DESCRIPTION = sys.argv[3]

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

        # Create task object
        timestamp = int(time.time())
        task_data = {
            "task_id": TASK_ID,
            "description": TASK_DESCRIPTION,
            "status": "assigned",
            "assigned_at": timestamp,
            "worker_id": WORKER_ID
        }

        # Set task variables
        await target_session.async_set_variable("user.current_task_id", TASK_ID)
        await target_session.async_set_variable("user.current_task_description", TASK_DESCRIPTION)
        await target_session.async_set_variable("user.current_task_status", "assigned")
        await target_session.async_set_variable("user.current_task_assigned_at", str(timestamp))

        # Store full task data as JSON
        await target_session.async_set_variable("user.task_data", json.dumps(task_data))

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "task": task_data
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute Python script with arguments
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$TASK_ID" "$TASK_DESCRIPTION" 2>&1
