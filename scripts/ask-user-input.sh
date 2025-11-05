#!/bin/bash

# Ask User Input
# Request text input from user with modal dialog
# Usage: ask-user-input.sh <title> [placeholder] [default_value]

TITLE="${1:-Enter value}"
PLACEHOLDER="${2:-}"
DEFAULT_VALUE="${3:-}"

# Create Python script
PYTHON_SCRIPT=$(cat <<EOF
import iterm2
import json
import sys

async def main(connection):
    try:
        alert = iterm2.TextInputAlert(
            "$TITLE",
            "$PLACEHOLDER",
            "$DEFAULT_VALUE"
        )

        # Show alert and wait for input
        user_input = await alert.async_run(connection)

        if user_input is None:
            result = {
                "success": False,
                "cancelled": True,
                "message": "User cancelled input"
            }
        else:
            result = {
                "success": True,
                "value": user_input,
                "title": "$TITLE"
            }

        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

iterm2.run_until_complete(main, retry=False)
EOF
)

# Execute
echo "$PYTHON_SCRIPT" | python3 2>&1
