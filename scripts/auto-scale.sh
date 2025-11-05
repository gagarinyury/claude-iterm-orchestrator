#!/bin/bash

# Auto-Scaling Logic
# Automatically scales workers based on load
# Usage: auto-scale.sh evaluate
#        auto-scale.sh enable
#        auto-scale.sh disable
#        auto-scale.sh status

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.claude-orchestrator"
CONFIG_FILE="$CONFIG_DIR/config.json"
STATE_FILE="$CONFIG_DIR/autoscale-state.json"

# Create config dir
mkdir -p "$CONFIG_DIR"

# Initialize config if not exists (use example as default)
if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f "$(dirname "$SCRIPT_DIR")/config.example.json" ]; then
        cp "$(dirname "$SCRIPT_DIR")/config.example.json" "$CONFIG_FILE"
    else
        cat > "$CONFIG_FILE" <<EOF
{
  "auto_scaling": {
    "enabled": false,
    "min_workers": 1,
    "max_workers": 10,
    "scale_up_threshold": 0.8,
    "scale_down_threshold": 0.3,
    "idle_timeout_seconds": 600,
    "cooldown_seconds": 120
  }
}
EOF
    fi
fi

# Initialize state if not exists
if [ ! -f "$STATE_FILE" ]; then
    cat > "$STATE_FILE" <<EOF
{
  "last_scale_action": 0,
  "scale_up_count": 0,
  "scale_down_count": 0,
  "last_evaluation": 0
}
EOF
fi

ACTION="${1:-status}"

# Check if enabled
is_enabled() {
    local ENABLED=$(jq -r '.auto_scaling.enabled // false' "$CONFIG_FILE")
    echo "$ENABLED"
}

# Evaluate and scale
evaluate_and_scale() {
    local ENABLED=$(is_enabled)

    if [ "$ENABLED" != "true" ]; then
        echo '{"message": "Auto-scaling is disabled", "enabled": false}'
        return 0
    fi

    local NOW=$(date +%s)
    local LAST_ACTION=$(jq -r '.last_scale_action' "$STATE_FILE")
    local COOLDOWN=$(jq -r '.auto_scaling.cooldown_seconds // 120' "$CONFIG_FILE")

    # Check cooldown
    if [ $((NOW - LAST_ACTION)) -lt "$COOLDOWN" ]; then
        local WAIT_TIME=$((COOLDOWN - (NOW - LAST_ACTION)))
        echo "{\"message\": \"In cooldown period\", \"wait_seconds\": $WAIT_TIME}"
        return 0
    fi

    # Get current metrics
    local LB_STATUS=$("$SCRIPT_DIR/load-balancer.sh" status)
    local AVAILABLE_WORKERS=$(echo "$LB_STATUS" | jq -r '.load_balancer_status.available_workers')
    local ACTIVE_ASSIGNMENTS=$(echo "$LB_STATUS" | jq -r '.load_balancer_status.active_assignments')
    local MAX_CONCURRENT=$(echo "$LB_STATUS" | jq -r '.load_balancer_status.max_concurrent')
    local QUEUED_TASKS=$(echo "$LB_STATUS" | jq -r '.load_balancer_status.queued_tasks')

    # Get config thresholds
    local MIN_WORKERS=$(jq -r '.auto_scaling.min_workers // 1' "$CONFIG_FILE")
    local MAX_WORKERS=$(jq -r '.auto_scaling.max_workers // 10' "$CONFIG_FILE")
    local SCALE_UP_THRESHOLD=$(jq -r '.auto_scaling.scale_up_threshold // 0.8' "$CONFIG_FILE")
    local SCALE_DOWN_THRESHOLD=$(jq -r '.auto_scaling.scale_down_threshold // 0.3' "$CONFIG_FILE")

    # Calculate utilization
    local UTILIZATION=0
    if [ "$MAX_CONCURRENT" -gt 0 ]; then
        UTILIZATION=$(echo "scale=2; $ACTIVE_ASSIGNMENTS / $MAX_CONCURRENT" | bc)
    fi

    local DECISION="none"
    local REASON=""

    # Decide if we need to scale up
    if [ "$AVAILABLE_WORKERS" -lt "$MAX_WORKERS" ]; then
        # Check if utilization is high or there's a queue
        local SHOULD_SCALE_UP=$(echo "$UTILIZATION >= $SCALE_UP_THRESHOLD" | bc)

        if [ "$SHOULD_SCALE_UP" -eq 1 ] || [ "$QUEUED_TASKS" -gt 5 ]; then
            DECISION="scale_up"
            REASON="High utilization ($UTILIZATION) or queue backlog ($QUEUED_TASKS tasks)"

            # Scale up
            local SCALE_RESULT=$("$SCRIPT_DIR/scale-up.sh" "AutoWorker" "Auto-scaled")
            local SCALE_SUCCESS=$(echo "$SCALE_RESULT" | jq -r '.success // false')

            if [ "$SCALE_SUCCESS" = "true" ]; then
                # Update state
                jq ".last_scale_action = $NOW | .scale_up_count += 1 | .last_evaluation = $NOW" "$STATE_FILE" > "$STATE_FILE.tmp"
                mv "$STATE_FILE.tmp" "$STATE_FILE"

                cat <<EOF
{
  "action": "scale_up",
  "success": true,
  "reason": "$REASON",
  "utilization": $UTILIZATION,
  "workers_before": $AVAILABLE_WORKERS,
  "workers_after": $((AVAILABLE_WORKERS + 1)),
  "queued_tasks": $QUEUED_TASKS
}
EOF
                return 0
            fi
        fi
    fi

    # Decide if we need to scale down
    if [ "$AVAILABLE_WORKERS" -gt "$MIN_WORKERS" ]; then
        local SHOULD_SCALE_DOWN=$(echo "$UTILIZATION <= $SCALE_DOWN_THRESHOLD" | bc)

        if [ "$SHOULD_SCALE_DOWN" -eq 1 ] && [ "$QUEUED_TASKS" -eq 0 ]; then
            DECISION="scale_down"
            REASON="Low utilization ($UTILIZATION) and no queued tasks"

            # Find idle worker to remove
            # For now, just report the decision (actual implementation would need to find idle worker)

            cat <<EOF
{
  "action": "scale_down_candidate",
  "recommendation": true,
  "reason": "$REASON",
  "utilization": $UTILIZATION,
  "current_workers": $AVAILABLE_WORKERS,
  "min_workers": $MIN_WORKERS,
  "message": "Would scale down if idle worker found"
}
EOF
            return 0
        fi
    fi

    # Update evaluation time
    jq ".last_evaluation = $NOW" "$STATE_FILE" > "$STATE_FILE.tmp"
    mv "$STATE_FILE.tmp" "$STATE_FILE"

    cat <<EOF
{
  "action": "no_action",
  "utilization": $UTILIZATION,
  "current_workers": $AVAILABLE_WORKERS,
  "queued_tasks": $QUEUED_TASKS,
  "min_workers": $MIN_WORKERS,
  "max_workers": $MAX_WORKERS,
  "reason": "Metrics within normal range"
}
EOF
}

# Enable auto-scaling
enable_autoscale() {
    jq '.auto_scaling.enabled = true' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    echo '{"success": true, "message": "Auto-scaling enabled"}'
}

# Disable auto-scaling
disable_autoscale() {
    jq '.auto_scaling.enabled = false' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

    echo '{"success": true, "message": "Auto-scaling disabled"}'
}

# Get status
get_status() {
    local ENABLED=$(is_enabled)
    local CONFIG=$(jq '.auto_scaling' "$CONFIG_FILE")
    local STATE=$(cat "$STATE_FILE")

    cat <<EOF
{
  "auto_scaling_status": {
    "enabled": $ENABLED,
    "config": $CONFIG,
    "state": $STATE
  }
}
EOF
}

# Main logic
case "$ACTION" in
    evaluate)
        evaluate_and_scale
        ;;
    enable)
        enable_autoscale
        ;;
    disable)
        disable_autoscale
        ;;
    status)
        get_status
        ;;
    *)
        echo "{\"error\": \"Unknown action: $ACTION. Use: evaluate, enable, disable, status\"}"
        exit 1
        ;;
esac
