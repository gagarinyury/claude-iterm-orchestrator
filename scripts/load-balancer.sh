#!/bin/bash

# Load Balancer - Smart task distribution
# Distributes tasks across workers using round-robin or priority
# Usage: load-balancer.sh assign <task> [priority] [mode]
#        load-balancer.sh process
#        load-balancer.sh status
#        load-balancer.sh config <max_concurrent>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LB_DIR="/tmp/claude-load-balancer"
CONFIG_FILE="$LB_DIR/config.json"
STATE_FILE="$LB_DIR/state.json"
WORKERS_REGISTRY="/tmp/workers/registry.txt"

mkdir -p "$LB_DIR"

# Initialize config if not exists
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOF
{
  "max_concurrent_workers": 3,
  "mode": "auto",
  "distribution": "round-robin",
  "throttle_enabled": true
}
EOF
fi

# Initialize state
if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<EOF
{
  "last_assigned_worker_index": 0,
  "active_assignments": {}
}
EOF
fi

ACTION="${1:-status}"

# Get available workers
get_available_workers() {
    if [ ! -f "$WORKERS_REGISTRY" ]; then
        echo "[]"
        return
    fi

    echo '['
    local FIRST=true
    while IFS='|' read -r worker_id worker_name timestamp task type; do
        # Check if worker is still active (has session variables)
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ","
        fi
        cat <<EOF
{"worker_id": "$worker_id", "worker_name": "$worker_name", "created_at": "$timestamp"}
EOF
    done < "$WORKERS_REGISTRY"
    echo ']'
}

# Get worker count
get_worker_count() {
    if [ ! -f "$WORKERS_REGISTRY" ]; then
        echo "0"
        return
    fi
    wc -l < "$WORKERS_REGISTRY" | tr -d ' '
}

# Get next worker (round-robin)
get_next_worker() {
    local WORKERS=$(get_available_workers)
    local WORKER_COUNT=$(echo "$WORKERS" | jq 'length')

    if [ "$WORKER_COUNT" -eq 0 ]; then
        echo '{"error": "No workers available"}'
        return 1
    fi

    local LAST_INDEX=$(jq -r '.last_assigned_worker_index' "$STATE_FILE")
    local NEXT_INDEX=$(( (LAST_INDEX + 1) % WORKER_COUNT ))

    # Update state
    jq ".last_assigned_worker_index = $NEXT_INDEX" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    # Get worker at index
    echo "$WORKERS" | jq -c ".[$NEXT_INDEX]"
}

# Check if can assign more tasks
can_assign_task() {
    local MAX_CONCURRENT=$(jq -r '.max_concurrent_workers' "$CONFIG_FILE")
    local ACTIVE_COUNT=$(jq -r '.active_assignments | length' "$STATE_FILE")

    if [ "$ACTIVE_COUNT" -ge "$MAX_CONCURRENT" ]; then
        echo "false"
        return 1
    fi

    echo "true"
    return 0
}

# Assign task to worker
assign_task() {
    local TASK="${1:-}"
    local PRIORITY="${2:-medium}"
    local MODE="${3:-auto}"

    # Check if we can assign
    local CAN_ASSIGN=$(can_assign_task)

    if [ "$CAN_ASSIGN" = "false" ]; then
        # Queue the task instead
        local QUEUE_RESULT=$("$SCRIPT_DIR/task-queue.sh" enqueue "$PRIORITY" "pending" "$TASK")
        echo "$QUEUE_RESULT" | jq -c '. + {action: "queued", reason: "max_concurrent_reached"}'
        return 0
    fi

    # Get next worker
    local WORKER=$(get_next_worker)
    local WORKER_ID=$(echo "$WORKER" | jq -r '.worker_id')

    if [ "$WORKER_ID" = "null" ] || [ -z "$WORKER_ID" ]; then
        # No workers available, queue the task
        local QUEUE_RESULT=$("$SCRIPT_DIR/task-queue.sh" enqueue "$PRIORITY" "pending" "$TASK")
        echo "$QUEUE_RESULT" | jq -c '. + {action: "queued", reason: "no_workers_available"}'
        return 0
    fi

    # Assign task
    local TASK_ID="task-$(date +%s%N)"
    local TIMESTAMP=$(date +%s)

    # Update state with active assignment
    local NEW_ASSIGNMENT=$(cat <<EOF
{
  "task_id": "$TASK_ID",
  "worker_id": "$WORKER_ID",
  "task": "$TASK",
  "priority": "$PRIORITY",
  "assigned_at": $TIMESTAMP
}
EOF
)

    jq ".active_assignments[\"$TASK_ID\"] = $NEW_ASSIGNMENT" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    cat <<EOF
{
  "success": true,
  "action": "assigned",
  "task_id": "$TASK_ID",
  "worker_id": "$WORKER_ID",
  "priority": "$PRIORITY",
  "mode": "$MODE",
  "assigned_at": $TIMESTAMP
}
EOF
}

# Process queued tasks
process_queue() {
    local PROCESSED=0

    while true; do
        # Check if we can assign more
        local CAN_ASSIGN=$(can_assign_task)
        if [ "$CAN_ASSIGN" = "false" ]; then
            break
        fi

        # Dequeue next task
        local TASK_DATA=$("$SCRIPT_DIR/task-queue.sh" dequeue)
        local SUCCESS=$(echo "$TASK_DATA" | jq -r '.success')

        if [ "$SUCCESS" != "true" ]; then
            break
        fi

        local TASK=$(echo "$TASK_DATA" | jq -r '.task')
        local PRIORITY=$(echo "$TASK_DATA" | jq -r '.priority')

        # Assign it
        assign_task "$TASK" "$PRIORITY" "auto"
        PROCESSED=$((PROCESSED + 1))
    done

    cat <<EOF
{
  "success": true,
  "processed": $PROCESSED,
  "message": "Processed $PROCESSED tasks from queue"
}
EOF
}

# Complete task
complete_task() {
    local TASK_ID="${1:-}"

    if [ -z "$TASK_ID" ]; then
        echo '{"error": "task_id required"}'
        return 1
    fi

    # Remove from active assignments
    jq "del(.active_assignments[\"$TASK_ID\"])" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    # Try to process queue
    process_queue > /dev/null

    cat <<EOF
{
  "success": true,
  "task_id": "$TASK_ID",
  "message": "Task marked as complete"
}
EOF
}

# Get status
get_status() {
    local WORKER_COUNT=$(get_worker_count)
    local MAX_CONCURRENT=$(jq -r '.max_concurrent_workers' "$CONFIG_FILE")
    local ACTIVE_COUNT=$(jq -r '.active_assignments | length' "$STATE_FILE")
    local MODE=$(jq -r '.mode' "$CONFIG_FILE")
    local DISTRIBUTION=$(jq -r '.distribution' "$CONFIG_FILE")

    local QUEUE_STATUS=$("$SCRIPT_DIR/task-queue.sh" status)
    local QUEUE_SIZE=$(echo "$QUEUE_STATUS" | jq -r '.task_queue_status.total_tasks')

    local UTILIZATION=0
    if [ "$MAX_CONCURRENT" -gt 0 ]; then
        UTILIZATION=$(echo "scale=1; $ACTIVE_COUNT * 100 / $MAX_CONCURRENT" | bc)
    fi

    cat <<EOF
{
  "load_balancer_status": {
    "available_workers": $WORKER_COUNT,
    "max_concurrent": $MAX_CONCURRENT,
    "active_assignments": $ACTIVE_COUNT,
    "utilization_percent": $UTILIZATION,
    "queued_tasks": $QUEUE_SIZE,
    "mode": "$MODE",
    "distribution": "$DISTRIBUTION",
    "status": "$([ "$ACTIVE_COUNT" -ge "$MAX_CONCURRENT" ] && echo "at_capacity" || echo "ok")"
  }
}
EOF
}

# Update config
update_config() {
    local MAX_CONCURRENT="${1:-3}"

    jq ".max_concurrent_workers = $MAX_CONCURRENT" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    cat <<EOF
{
  "success": true,
  "max_concurrent_workers": $MAX_CONCURRENT,
  "message": "Configuration updated"
}
EOF
}

# Main logic
case "$ACTION" in
    assign)
        TASK="${2:-}"
        PRIORITY="${3:-medium}"
        MODE="${4:-auto}"
        assign_task "$TASK" "$PRIORITY" "$MODE"
        ;;
    process)
        process_queue
        ;;
    complete)
        TASK_ID="${2:-}"
        complete_task "$TASK_ID"
        ;;
    status)
        get_status
        ;;
    config)
        MAX_CONCURRENT="${2:-3}"
        update_config "$MAX_CONCURRENT"
        ;;
    *)
        echo "{\"error\": \"Unknown action: $ACTION. Use: assign, process, complete, status, config\"}"
        exit 1
        ;;
esac
