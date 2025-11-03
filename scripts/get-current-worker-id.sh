#!/bin/bash

# Get worker_id of current iTerm session
# Usage: get-current-worker-id.sh

python3 <<'EOF'
import iterm2
import json
import sys

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)
        session = app.current_terminal_window.current_tab.current_session

        worker_id = await session.async_get_variable("user.worker_id")

        result = {
            "success": True,
            "worker_id": worker_id if worker_id else None,
            "session_id": session.session_id
        }
        print(json.dumps(result))

    except Exception as e:
        error = {"error": str(e), "worker_id": None}
        print(json.dumps(error))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
