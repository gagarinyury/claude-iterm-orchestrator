#!/bin/bash

# Ask orchestrator a question from a worker
# Usage: ask-orchestrator.sh <worker_id> <question>

WORKER_ID="$1"
QUESTION="$2"

if [ -z "$WORKER_ID" ] || [ -z "$QUESTION" ]; then
    echo '{"error": "Missing worker_id or question"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

WORKER_ID = sys.argv[1]
QUESTION = sys.argv[2]

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Find worker session to get parent_id
        worker_session = None
        parent_id = None

        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id == WORKER_ID:
                            worker_session = session
                            parent_id = await session.async_get_variable("user.parent_id")
                            break
                    except:
                        pass
                if worker_session:
                    break
            if worker_session:
                break

        if not worker_session:
            print(json.dumps({"error": f"Worker {WORKER_ID} not found"}))
            sys.exit(1)

        if not parent_id:
            print(json.dumps({"error": "No parent_id found. Worker has no orchestrator assigned."}))
            sys.exit(1)

        # Find orchestrator session
        orchestrator_session = None
        orchestrator_name = None

        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id == parent_id:
                            orchestrator_session = session
                            orchestrator_name = await session.async_get_variable("user.worker_name") or "Orchestrator"
                            break
                    except:
                        pass
                if orchestrator_session:
                    break
            if orchestrator_session:
                break

        if not orchestrator_session:
            print(json.dumps({"error": f"Orchestrator {parent_id} not found"}))
            sys.exit(1)

        # Get worker name
        worker_name = await worker_session.async_get_variable("user.worker_name") or "Worker"

        # Format message
        message = f"[Question from {worker_name} ({WORKER_ID})]: {QUESTION}"

        # Send to orchestrator
        await orchestrator_session.async_send_text(message)

        # Wait a tiny bit
        import asyncio
        await asyncio.sleep(0.05)

        # Send Return
        await orchestrator_session.async_send_text("\r")

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "orchestrator_id": parent_id,
            "orchestrator_name": orchestrator_name,
            "question": QUESTION,
            "message_sent": message
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute Python script with arguments
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$QUESTION" 2>&1
