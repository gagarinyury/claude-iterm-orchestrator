#!/bin/bash

# Get role and instructions for current Claude instance
# Usage: get-role-instructions.sh <my_worker_id>

MY_WORKER_ID="$1"

if [ -z "$MY_WORKER_ID" ]; then
    echo '{"error": "Missing my_worker_id"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

MY_WORKER_ID = sys.argv[1]

ORCHESTRATOR_INSTRUCTIONS = """
🎭 You are the ORCHESTRATOR

Your role:
- Create and manage workers using create_worker(name, task)
- Assign tasks using assign_task(worker_id, task_id, description)
- Monitor workers using list_workers()
- Communicate with workers (they will send you messages)
- Broadcast to all workers using broadcast(message)

Network status: You are the first instance. No other workers yet.

Available commands:
- create_worker, list_workers, assign_task, complete_task
- send_to_claude, read_from_worker, broadcast
- set_tab_color, monitor_variable, set_variable, get_variable

Your worker_id: {worker_id}
"""

WORKER_INSTRUCTIONS = """
🤖 You are a WORKER

Your role:
- Execute tasks assigned to you
- Ask orchestrator questions using ask_orchestrator(question)
- Report task completion using complete_task(task_id, result)
- Check your current task using get_variable(self, "current_task_id")

Your orchestrator: {orchestrator_name} (ID: {orchestrator_id})
Your worker_id: {worker_id}

Available commands:
- ask_orchestrator, complete_task, get_variable, set_variable
- read_from_worker (to read your own output)

Network:
{network_info}
"""

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Get all workers
        workers = []
        orchestrator = None

        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id:
                            worker_name = await session.async_get_variable("user.worker_name") or "Unknown"
                            role = await session.async_get_variable("user.role") or None

                            worker_info = {
                                "worker_id": worker_id,
                                "name": worker_name,
                                "role": role
                            }

                            workers.append(worker_info)

                            if role == "orchestrator":
                                orchestrator = worker_info
                    except:
                        pass

        # Determine role for current worker
        if len(workers) == 0 or orchestrator is None:
            # First worker = orchestrator
            role = "orchestrator"
            instructions = ORCHESTRATOR_INSTRUCTIONS.format(worker_id=MY_WORKER_ID)

            # Register current session as orchestrator
            import time
            current_session = app.current_terminal_window.current_tab.current_session

            # Check if worker_id already exists
            existing_wid = None
            try:
                existing_wid = await current_session.async_get_variable("user.worker_id")
            except:
                pass

            # If no worker_id exists, set MY_WORKER_ID
            if not existing_wid:
                await current_session.async_set_variable("user.worker_id", MY_WORKER_ID)
                await current_session.async_set_variable("user.worker_name", "Orchestrator")
                await current_session.async_set_variable("user.created_at", str(int(time.time())))

            # Set orchestrator role and status
            await current_session.async_set_variable("user.role", "orchestrator")
            await current_session.async_set_variable("user.status", "active")

            result = {
                "success": True,
                "role": "orchestrator",
                "worker_id": MY_WORKER_ID,
                "instructions": instructions,
                "network": {
                    "total_workers": 1,
                    "workers": []
                }
            }
        else:
            # Not first = worker
            role = "worker"
            parent_id = orchestrator["worker_id"]
            parent_name = orchestrator["name"]

            # Build network info
            network_info = f"- Orchestrator: {parent_name}\n"
            network_info += f"- Total workers: {len(workers)}\n"
            for w in workers:
                if w["role"] != "orchestrator":
                    network_info += f"- Peer: {w['name']} ({w['worker_id']})\n"

            instructions = WORKER_INSTRUCTIONS.format(
                orchestrator_name=parent_name,
                orchestrator_id=parent_id,
                worker_id=MY_WORKER_ID,
                network_info=network_info
            )

            # Set role and parent_id for self
            for window in app.windows:
                for tab in window.tabs:
                    for session in tab.sessions:
                        try:
                            wid = await session.async_get_variable("user.worker_id")
                            if wid == MY_WORKER_ID:
                                await session.async_set_variable("user.role", "worker")
                                await session.async_set_variable("user.parent_id", parent_id)
                                break
                        except:
                            pass

            result = {
                "success": True,
                "role": "worker",
                "worker_id": MY_WORKER_ID,
                "parent_id": parent_id,
                "instructions": instructions,
                "network": {
                    "orchestrator": orchestrator,
                    "total_workers": len(workers),
                    "workers": [w for w in workers if w["role"] != "orchestrator"]
                }
            }

        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute Python script with arguments
echo "$PYTHON_SCRIPT" | python3 - "$MY_WORKER_ID" 2>&1
