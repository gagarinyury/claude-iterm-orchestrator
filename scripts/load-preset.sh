#!/bin/bash

# Load Preset Configuration
# Creates workers and applies config from preset
# Usage: load-preset.sh <preset_name>
#        preset_name: web-dev, data-analysis, content-creation

PRESET_NAME="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PRESETS_DIR="$PROJECT_ROOT/presets"

if [ -z "$PRESET_NAME" ]; then
    echo '{"error": "preset_name required. Available: web-dev, data-analysis, content-creation"}'
    exit 1
fi

PRESET_FILE="$PRESETS_DIR/$PRESET_NAME.json"

if [ ! -f "$PRESET_FILE" ]; then
    echo "{\"error\": \"Preset not found: $PRESET_NAME\", \"file\": \"$PRESET_FILE\"}"
    exit 1
fi

# Read preset
PRESET=$(cat "$PRESET_FILE")
PRESET_DISPLAY_NAME=$(echo "$PRESET" | jq -r '.name')
DESCRIPTION=$(echo "$PRESET" | jq -r '.description')
WORKER_COUNT=$(echo "$PRESET" | jq '.workers | length')

echo "Loading preset: $PRESET_DISPLAY_NAME" >&2
echo "Description: $DESCRIPTION" >&2
echo "Workers to create: $WORKER_COUNT" >&2
echo "" >&2

# Create workers
CREATED_WORKERS=()
WORKER_INDEX=0

while [ "$WORKER_INDEX" -lt "$WORKER_COUNT" ]; do
    WORKER=$(echo "$PRESET" | jq -c ".workers[$WORKER_INDEX]")

    WORKER_NAME=$(echo "$WORKER" | jq -r '.name')
    TASK=$(echo "$WORKER" | jq -r '.task')
    PRIORITY=$(echo "$WORKER" | jq -r '.priority // "medium"')
    AUTO_START=$(echo "$WORKER" | jq -r '.auto_start_claude // true')

    echo "Creating worker $((WORKER_INDEX + 1))/$WORKER_COUNT: $WORKER_NAME..." >&2

    # Create worker
    if [ "$AUTO_START" = "true" ]; then
        RESULT=$("$SCRIPT_DIR/create-worker-claude.sh" "$WORKER_NAME" "$TASK" "claude+")
    else
        RESULT=$("$SCRIPT_DIR/create-worker.sh" "$WORKER_NAME" "$TASK")
    fi

    SUCCESS=$(echo "$RESULT" | jq -r '.success // false')

    if [ "$SUCCESS" = "true" ]; then
        WORKER_ID=$(echo "$RESULT" | jq -r '.worker_id')

        # Set priority
        if [ "$PRIORITY" != "medium" ]; then
            "$SCRIPT_DIR/set-worker-priority.sh" "$WORKER_ID" "$PRIORITY" > /dev/null 2>&1
        fi

        CREATED_WORKERS+=("$WORKER_ID")
        echo "  ✓ Created: $WORKER_ID" >&2
    else
        echo "  ✗ Failed to create $WORKER_NAME" >&2
    fi

    WORKER_INDEX=$((WORKER_INDEX + 1))
    sleep 1  # Small delay between workers
done

echo "" >&2

# Apply config
echo "Applying configuration..." >&2

# Load balancer config
MAX_CONCURRENT=$(echo "$PRESET" | jq -r '.config.load_balancer.max_concurrent_workers // 3')
"$SCRIPT_DIR/load-balancer.sh" config "$MAX_CONCURRENT" > /dev/null 2>&1

# Auto-scaling config
AUTO_SCALE_ENABLED=$(echo "$PRESET" | jq -r '.config.auto_scaling.enabled // false')
if [ "$AUTO_SCALE_ENABLED" = "true" ]; then
    "$SCRIPT_DIR/auto-scale.sh" enable > /dev/null 2>&1
    echo "  ✓ Auto-scaling enabled" >&2
fi

echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "✅ Preset loaded successfully!" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2

# Output JSON
cat <<EOF
{
  "success": true,
  "preset": "$PRESET_NAME",
  "preset_name": "$PRESET_DISPLAY_NAME",
  "workers_created": ${#CREATED_WORKERS[@]},
  "worker_ids": $(printf '%s\n' "${CREATED_WORKERS[@]}" | jq -R . | jq -s .),
  "config_applied": {
    "max_concurrent": $MAX_CONCURRENT,
    "auto_scaling": $AUTO_SCALE_ENABLED
  }
}
EOF
