#!/bin/bash

# Read output from a worker
# Usage: read-output.sh <worker_id> [lines]

WORKER_ID="$1"
LINES="${2:-20}"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "Missing worker_id"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys

WORKER_ID = sys.argv[1]
LINES = int(sys.argv[2])

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Find session
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

        # Get screen contents
        screen = await target_session.async_get_screen_contents()

        # Extract lines
        all_lines = []
        for i in range(screen.number_of_lines):
            line = screen.line(i)
            line_text = line.string.rstrip()
            if line_text:
                all_lines.append(line_text)

        # Get last N lines
        output_lines = all_lines[-LINES:] if len(all_lines) > LINES else all_lines

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "output": "\n".join(output_lines),
            "total_lines": len(all_lines),
            "returned_lines": len(output_lines)
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$LINES" 2>&1
