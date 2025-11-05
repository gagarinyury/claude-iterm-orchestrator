#!/bin/bash

# Stream Monitor
# Real-time monitoring of worker output with visualization
# Usage: stream-monitor.sh <worker_id> [interval_seconds]

WORKER_ID="${1:-}"
INTERVAL="${2:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$WORKER_ID" ]; then
    echo '{"error": "worker_id required"}'
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Clear screen
clear

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          📡 WORKER OUTPUT STREAM MONITOR                 ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Worker ID: ${NC}$WORKER_ID"
echo -e "${YELLOW}Refresh interval: ${NC}${INTERVAL}s"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Store last output hash to detect changes
LAST_HASH=""
CHANGE_COUNT=0

while true; do
    # Read current output
    OUTPUT=$("$SCRIPT_DIR/read-output.sh" "$WORKER_ID" 30 2>/dev/null)

    if [ $? -eq 0 ]; then
        # Calculate hash
        CURRENT_HASH=$(echo "$OUTPUT" | md5sum | cut -d' ' -f1)

        if [ "$CURRENT_HASH" != "$LAST_HASH" ]; then
            CHANGE_COUNT=$((CHANGE_COUNT + 1))
            LAST_HASH="$CURRENT_HASH"

            # Clear previous output (move cursor up and clear)
            tput cuu 30 2>/dev/null || true
            tput ed 2>/dev/null || true

            # Show timestamp
            echo -e "${MAGENTA}[$(date '+%H:%M:%S')] Update #$CHANGE_COUNT${NC}"
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

            # Show output
            echo "$OUTPUT" | jq -r '.output // "No output"' 2>/dev/null || echo "$OUTPUT"

            echo ""
            echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        else
            # No change, just update timestamp
            echo -e -n "\r${GREEN}[$(date '+%H:%M:%S')] Monitoring... (no changes)${NC}  "
        fi
    else
        echo -e "\r${YELLOW}[$(date '+%H:%M:%S')] Waiting for worker...${NC}         "
    fi

    sleep "$INTERVAL"
done
