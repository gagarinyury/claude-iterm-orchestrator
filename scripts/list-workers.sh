#!/bin/bash

# List all active workers
# Usage: list-workers.sh

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        workers = []
        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id:
                            worker_name = await session.async_get_variable("user.worker_name") or "Unknown"
                            status = await session.async_get_variable("user.status") or "unknown"
                            task = await session.async_get_variable("user.task") or "No task"
                            created_at = await session.async_get_variable("user.created_at") or "0"

                            workers.append({
                                "worker_id": worker_id,
                                "name": worker_name,
                                "status": status,
                                "task": task,
                                "created_at": created_at,
                                "session_id": session.session_id
                            })
                    except:
                        pass

        result = {
            "success": True,
            "count": len(workers),
            "workers": workers
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute
echo "$PYTHON_SCRIPT" | python3 2>&1
