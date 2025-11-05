#!/bin/bash

# Queue Manager for Claude requests
# Manages request queue when rate limits are approached
# Usage: queue-manager.sh enqueue <worker_id> <message>
#        queue-manager.sh dequeue
#        queue-manager.sh status
#        queue-manager.sh clear

QUEUE_DIR="/tmp/claude-queue"
QUEUE_FILE="$QUEUE_DIR/queue.jsonl"
PROCESSING_FILE="$QUEUE_DIR/processing.lock"

# Create directories
mkdir -p "$QUEUE_DIR"
touch "$QUEUE_FILE"

ACTION="${1:-status}"

# Enqueue a request
enqueue_request() {
    local WORKER_ID="$1"
    local MESSAGE="$2"
    local TIMESTAMP=$(date +%s)
    local QUEUE_ID="queue-$(date +%s%N)"

    local ENTRY=$(cat <<EOF
{"queue_id": "$QUEUE_ID", "worker_id": "$WORKER_ID", "message": "$MESSAGE", "timestamp": $TIMESTAMP, "status": "queued"}
EOF
)

    echo "$ENTRY" >> "$QUEUE_FILE"

    local POSITION=$(wc -l < "$QUEUE_FILE" | tr -d ' ')

    cat <<EOF
{
  "success": true,
  "queue_id": "$QUEUE_ID",
  "position": $POSITION,
  "message": "Request queued (position: $POSITION)"
}
EOF
}

# Dequeue next request
dequeue_request() {
    if [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ]; then
        echo '{"success": false, "message": "Queue is empty"}'
        return 1
    fi

    # Get first line (FIFO)
    local FIRST_LINE=$(head -n 1 "$QUEUE_FILE")

    # Remove first line from queue
    tail -n +2 "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
    mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

    # Return the dequeued item
    echo "$FIRST_LINE" | jq -c '. + {success: true, action: "dequeued"}'
}

# Get queue status
get_status() {
    local QUEUE_SIZE=0
    if [ -f "$QUEUE_FILE" ]; then
        QUEUE_SIZE=$(wc -l < "$QUEUE_FILE" | tr -d ' ')
    fi

    local PROCESSING=false
    if [ -f "$PROCESSING_FILE" ]; then
        PROCESSING=true
    fi

    local OLDEST_TIMESTAMP="null"
    if [ "$QUEUE_SIZE" -gt 0 ]; then
        OLDEST_TIMESTAMP=$(head -n 1 "$QUEUE_FILE" | jq -r '.timestamp')
    fi

    local WAIT_TIME=0
    if [ "$OLDEST_TIMESTAMP" != "null" ]; then
        local NOW=$(date +%s)
        WAIT_TIME=$((NOW - OLDEST_TIMESTAMP))
    fi

    cat <<EOF
{
  "queue_status": {
    "size": $QUEUE_SIZE,
    "processing": $PROCESSING,
    "oldest_wait_seconds": $WAIT_TIME,
    "status": "$([ "$QUEUE_SIZE" -gt 10 ] && echo "high_load" || echo "ok")"
  }
}
EOF
}

# Clear queue
clear_queue() {
    rm -f "$QUEUE_FILE"
    touch "$QUEUE_FILE"
    rm -f "$PROCESSING_FILE"

    echo '{"success": true, "message": "Queue cleared"}'
}

# List all queued items
list_queue() {
    if [ ! -f "$QUEUE_FILE" ] || [ ! -s "$QUEUE_FILE" ]; then
        echo '{"items": []}'
        return
    fi

    echo '{"items": ['
    local FIRST=true
    while IFS= read -r line; do
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ","
        fi
        echo "$line"
    done < "$QUEUE_FILE"
    echo ']}'
}

# Main logic
case "$ACTION" in
    enqueue)
        WORKER_ID="${2:-unknown}"
        MESSAGE="${3:-}"
        enqueue_request "$WORKER_ID" "$MESSAGE"
        ;;
    dequeue)
        dequeue_request
        ;;
    status)
        get_status
        ;;
    clear)
        clear_queue
        ;;
    list)
        list_queue
        ;;
    *)
        echo "{\"error\": \"Unknown action: $ACTION. Use: enqueue, dequeue, status, clear, list\"}"
        exit 1
        ;;
esac
