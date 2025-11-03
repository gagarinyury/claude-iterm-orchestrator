#!/bin/bash

# Mark a task as completed for a worker
# Usage: complete-task.sh <worker_id> <task_id> [result]

WORKER_ID="$1"
TASK_ID="$2"
RESULT="${3:-Task completed successfully}"

if [ -z "$WORKER_ID" ] || [ -z "$TASK_ID" ]; then
    echo '{"error": "Missing worker_id or task_id"}'
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
RESULT = sys.argv[3]

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

        # Get current task
        try:
            current_task_id = await target_session.async_get_variable("user.current_task_id")
        except:
            current_task_id = None

        if current_task_id != TASK_ID:
            print(json.dumps({
                "error": f"Task ID mismatch. Current: {current_task_id}, Requested: {TASK_ID}"
            }))
            sys.exit(1)

        # Get task data
        try:
            task_data_str = await target_session.async_get_variable("user.task_data")
            task_data = json.loads(task_data_str) if task_data_str else {}
        except:
            task_data = {}

        # Update task status
        timestamp = int(time.time())
        task_data["status"] = "completed"
        task_data["completed_at"] = timestamp
        task_data["result"] = RESULT

        # Calculate duration if assigned_at exists
        if "assigned_at" in task_data:
            task_data["duration_seconds"] = timestamp - task_data["assigned_at"]

        # Update variables
        await target_session.async_set_variable("user.current_task_status", "completed")
        await target_session.async_set_variable("user.current_task_completed_at", str(timestamp))
        await target_session.async_set_variable("user.current_task_result", RESULT)
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
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$TASK_ID" "$RESULT" 2>&1
