#!/bin/bash

# Announce network to all workers - broadcasts list of all workers to everyone
# Usage: announce-network.sh

# Create Python script
PYTHON_SCRIPT=$(cat <<'EOF'
import iterm2
import json
import sys
import asyncio

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Collect all workers
        workers = []

        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        worker_name = await session.async_get_variable("user.worker_name")
                        role = await session.async_get_variable("user.role")

                        if worker_id:
                            workers.append({
                                "worker_id": worker_id,
                                "name": worker_name or "Unknown",
                                "role": role or "unknown"
                            })
                    except:
                        pass

        if not workers:
            result = {
                "success": False,
                "error": "No workers found in network"
            }
            print(json.dumps(result))
            sys.exit(1)

        # Format network announcement
        worker_list = []
        for w in workers:
            if w["role"] == "orchestrator":
                worker_list.append(f"{w['name']} (orchestrator)")
            else:
                worker_list.append(f"{w['name']} ({w['role']})")

        network_msg = f"[NETWORK] Active participants: {', '.join(worker_list)}"

        # Broadcast to all workers
        sent_count = 0
        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id:
                            await session.async_send_text(network_msg)
                            await asyncio.sleep(0.05)
                            await session.async_send_text("\r")
                            sent_count += 1
                    except:
                        pass

        result = {
            "success": True,
            "workers": workers,
            "total_workers": len(workers),
            "message": network_msg,
            "sent_to": sent_count
        }
        print(json.dumps(result))

    except Exception as e:
        error = {
            "success": False,
            "error": str(e)
        }
        print(json.dumps(error))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

# Execute Python script
echo "$PYTHON_SCRIPT" | python3 2>&1
