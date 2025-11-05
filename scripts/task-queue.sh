#!/bin/bash

# Task Queue with Priority Support
# FIFO queue with high/medium/low priorities
# Usage: task-queue.sh enqueue <priority> <worker_id> <task>
#        task-queue.sh dequeue [priority]
#        task-queue.sh status
#        task-queue.sh clear

QUEUE_DIR="/tmp/claude-task-queue"
HIGH_QUEUE="$QUEUE_DIR/high.jsonl"
MEDIUM_QUEUE="$QUEUE_DIR/medium.jsonl"
LOW_QUEUE="$QUEUE_DIR/low.jsonl"

# Create directories and files
mkdir -p "$QUEUE_DIR"
touch "$HIGH_QUEUE" "$MEDIUM_QUEUE" "$LOW_QUEUE"

ACTION="${1:-status}"

# Get queue file by priority
get_queue_file() {
    case "$1" in
        high)
            echo "$HIGH_QUEUE"
            ;;
        medium)
            echo "$MEDIUM_QUEUE"
            ;;
        low)
            echo "$LOW_QUEUE"
            ;;
        *)
            echo "$MEDIUM_QUEUE"
            ;;
    esac
}

# Enqueue a task
enqueue_task() {
    local PRIORITY="${1:-medium}"
    local WORKER_ID="${2:-unknown}"
    local TASK="${3:-}"
    local TIMESTAMP=$(date +%s)
    local TASK_ID="task-$(date +%s%N)"

    local QUEUE_FILE=$(get_queue_file "$PRIORITY")

    local ENTRY=$(cat <<EOF
{"task_id": "$TASK_ID", "priority": "$PRIORITY", "worker_id": "$WORKER_ID", "task": "$TASK", "timestamp": $TIMESTAMP, "status": "queued"}
EOF
)

    echo "$ENTRY" >> "$QUEUE_FILE"

    local POSITION=$(wc -l < "$QUEUE_FILE" | tr -d ' ')

    cat <<EOF
{
  "success": true,
  "task_id": "$TASK_ID",
  "priority": "$PRIORITY",
  "position": $POSITION,
  "queue": "$PRIORITY",
  "message": "Task queued in $PRIORITY priority (position: $POSITION)"
}
EOF
}

# Dequeue next task (highest priority first)
dequeue_task() {
    local REQUESTED_PRIORITY="${1:-any}"

    # Priority order: high -> medium -> low
    local QUEUES=()

    if [ "$REQUESTED_PRIORITY" = "any" ]; then
        QUEUES=("$HIGH_QUEUE" "$MEDIUM_QUEUE" "$LOW_QUEUE")
    else
        QUEUES=($(get_queue_file "$REQUESTED_PRIORITY"))
    fi

    for QUEUE_FILE in "${QUEUES[@]}"; do
        if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
            # Get first line
            local FIRST_LINE=$(head -n 1 "$QUEUE_FILE")

            # Remove first line
            tail -n +2 "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
            mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"

            # Return the task
            echo "$FIRST_LINE" | jq -c '. + {success: true, action: "dequeued"}'
            return 0
        fi
    done

    echo '{"success": false, "message": "All queues are empty"}'
    return 1
}

# Get queue status
get_status() {
    local HIGH_SIZE=0
    local MEDIUM_SIZE=0
    local LOW_SIZE=0

    if [ -f "$HIGH_QUEUE" ]; then
        HIGH_SIZE=$(wc -l < "$HIGH_QUEUE" | tr -d ' ')
    fi
    if [ -f "$MEDIUM_QUEUE" ]; then
        MEDIUM_SIZE=$(wc -l < "$MEDIUM_QUEUE" | tr -d ' ')
    fi
    if [ -f "$LOW_QUEUE" ]; then
        LOW_SIZE=$(wc -l < "$LOW_QUEUE" | tr -d ' ')
    fi

    local TOTAL_SIZE=$((HIGH_SIZE + MEDIUM_SIZE + LOW_SIZE))

    # Get oldest task wait time
    local OLDEST_TIMESTAMP="null"
    for QUEUE_FILE in "$HIGH_QUEUE" "$MEDIUM_QUEUE" "$LOW_QUEUE"; do
        if [ -f "$QUEUE_FILE" ] && [ -s "$QUEUE_FILE" ]; then
            local TS=$(head -n 1 "$QUEUE_FILE" | jq -r '.timestamp')
            if [ "$TS" != "null" ]; then
                if [ "$OLDEST_TIMESTAMP" = "null" ] || [ "$TS" -lt "$OLDEST_TIMESTAMP" ]; then
                    OLDEST_TIMESTAMP=$TS
                fi
            fi
        fi
    done

    local WAIT_TIME=0
    if [ "$OLDEST_TIMESTAMP" != "null" ]; then
        local NOW=$(date +%s)
        WAIT_TIME=$((NOW - OLDEST_TIMESTAMP))
    fi

    cat <<EOF
{
  "task_queue_status": {
    "total_tasks": $TOTAL_SIZE,
    "by_priority": {
      "high": $HIGH_SIZE,
      "medium": $MEDIUM_SIZE,
      "low": $LOW_SIZE
    },
    "oldest_wait_seconds": $WAIT_TIME,
    "status": "$([ "$TOTAL_SIZE" -gt 20 ] && echo "high_load" || echo "ok")"
  }
}
EOF
}

# Clear all queues
clear_queues() {
    rm -f "$HIGH_QUEUE" "$MEDIUM_QUEUE" "$LOW_QUEUE"
    touch "$HIGH_QUEUE" "$MEDIUM_QUEUE" "$LOW_QUEUE"
    echo '{"success": true, "message": "All task queues cleared"}'
}

# List all tasks
list_tasks() {
    echo '{"tasks": {'

    echo '"high": ['
    local FIRST=true
    if [ -f "$HIGH_QUEUE" ] && [ -s "$HIGH_QUEUE" ]; then
        while IFS= read -r line; do
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ","
            fi
            echo "$line"
        done < "$HIGH_QUEUE"
    fi
    echo '],'

    echo '"medium": ['
    FIRST=true
    if [ -f "$MEDIUM_QUEUE" ] && [ -s "$MEDIUM_QUEUE" ]; then
        while IFS= read -r line; do
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ","
            fi
            echo "$line"
        done < "$MEDIUM_QUEUE"
    fi
    echo '],'

    echo '"low": ['
    FIRST=true
    if [ -f "$LOW_QUEUE" ] && [ -s "$LOW_QUEUE" ]; then
        while IFS= read -r line; do
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                echo ","
            fi
            echo "$line"
        done < "$LOW_QUEUE"
    fi
    echo ']'

    echo '}}'
}

# Main logic
case "$ACTION" in
    enqueue)
        PRIORITY="${2:-medium}"
        WORKER_ID="${3:-unknown}"
        TASK="${4:-}"
        enqueue_task "$PRIORITY" "$WORKER_ID" "$TASK"
        ;;
    dequeue)
        PRIORITY="${2:-any}"
        dequeue_task "$PRIORITY"
        ;;
    status)
        get_status
        ;;
    clear)
        clear_queues
        ;;
    list)
        list_tasks
        ;;
    *)
        echo "{\"error\": \"Unknown action: $ACTION. Use: enqueue, dequeue, status, clear, list\"}"
        exit 1
        ;;
esac
