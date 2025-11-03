#!/bin/bash

# Set tab color for a worker
# Usage: set-tab-color.sh <worker_id> <color>
# Color format: "rgb(r,g,b)" or "red", "green", "blue", etc.

WORKER_ID="$1"
COLOR="$2"

if [ -z "$WORKER_ID" ] || [ -z "$COLOR" ]; then
    echo '{"error": "Missing worker_id or color"}'
    exit 1
fi

# Create Python script
PYTHON_SCRIPT=$(cat <<'PYSCRIPT'
import iterm2
import json
import sys
import re

WORKER_ID = sys.argv[1]
COLOR_INPUT = sys.argv[2]

def parse_color(color_str):
    """Parse color string to iterm2.Color"""
    # Try RGB format: rgb(r,g,b) or r,g,b
    rgb_match = re.search(r'(\d+)\s*,\s*(\d+)\s*,\s*(\d+)', color_str)
    if rgb_match:
        r, g, b = map(int, rgb_match.groups())
        return iterm2.Color(r, g, b)

    # Predefined colors
    colors = {
        'red': iterm2.Color(255, 0, 0),
        'green': iterm2.Color(0, 255, 0),
        'blue': iterm2.Color(0, 0, 255),
        'yellow': iterm2.Color(255, 255, 0),
        'cyan': iterm2.Color(0, 255, 255),
        'magenta': iterm2.Color(255, 0, 255),
        'orange': iterm2.Color(255, 165, 0),
        'purple': iterm2.Color(128, 0, 128),
        'pink': iterm2.Color(255, 192, 203),
        'gray': iterm2.Color(128, 128, 128),
        'white': iterm2.Color(255, 255, 255),
        'black': iterm2.Color(0, 0, 0),
    }

    color_lower = color_str.lower().strip()
    if color_lower in colors:
        return colors[color_lower]

    # Default to green if unknown
    return iterm2.Color(0, 255, 0)

async def main(connection):
    try:
        app = await iterm2.async_get_app(connection)

        # Find tab by worker_id
        target_tab = None
        for window in app.windows:
            for tab in window.tabs:
                for session in tab.sessions:
                    try:
                        worker_id = await session.async_get_variable("user.worker_id")
                        if worker_id == WORKER_ID:
                            target_tab = tab
                            break
                    except:
                        pass
                if target_tab:
                    break
            if target_tab:
                break

        if not target_tab:
            print(json.dumps({"error": f"Worker {WORKER_ID} not found"}))
            sys.exit(1)

        # Parse and set color
        color = parse_color(COLOR_INPUT)

        # Get current profile
        session = target_tab.current_session
        profile = await session.async_get_profile()

        # Set tab color
        await profile.async_set_tab_color(color)
        await profile.async_set_use_tab_color(True)

        result = {
            "success": True,
            "worker_id": WORKER_ID,
            "color": COLOR_INPUT,
            "tab_id": target_tab.tab_id
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
PYSCRIPT
)

# Execute Python script with arguments
echo "$PYTHON_SCRIPT" | python3 - "$WORKER_ID" "$COLOR" 2>&1
