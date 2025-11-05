#!/bin/bash

# Show Alert Dialog
# Display modal alert to user (iTerm2)
# Usage: show-alert.sh <title> <message> [buttons]
#        buttons: comma-separated list, e.g. "Yes,No,Cancel"

TITLE="${1:-Alert}"
MESSAGE="${2:-}"
BUTTONS="${3:-OK}"

if [ -z "$MESSAGE" ]; then
    echo '{"error": "message required"}'
    exit 1
fi

# Convert comma-separated buttons to array
IFS=',' read -ra BUTTON_ARRAY <<< "$BUTTONS"

# Create Python script
PYTHON_SCRIPT=$(cat <<EOF
import iterm2
import json
import sys

async def main(connection):
    try:
        alert = iterm2.Alert("$TITLE", "$MESSAGE")

        # Add buttons
EOF
)

# Add buttons dynamically
for BUTTON in "${BUTTON_ARRAY[@]}"; do
    PYTHON_SCRIPT+="
        alert.add_button(\"$BUTTON\")"
done

PYTHON_SCRIPT+=$(cat <<'EOF'

        # Show alert and wait for response
        selection = await alert.async_run(connection)

        result = {
            "success": True,
            "button_pressed": selection,
            "title": "$TITLE",
            "message": "$MESSAGE"
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
