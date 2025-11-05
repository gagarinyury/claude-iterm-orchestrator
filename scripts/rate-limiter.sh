#!/bin/bash

# Rate Limiter for Claude API calls
# Prevents hitting Claude Pro/Max rate limits
# Usage: rate-limiter.sh check [worker_id]
#        rate-limiter.sh record [worker_id]
#        rate-limiter.sh status
#        rate-limiter.sh reset

RATE_LIMIT_DIR="/tmp/claude-rate-limiter"
REQUESTS_FILE="$RATE_LIMIT_DIR/requests.log"
CONFIG_FILE="$RATE_LIMIT_DIR/config.json"

# Create directories
mkdir -p "$RATE_LIMIT_DIR"

# Initialize config if not exists
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOF
{
  "max_requests_per_minute": 50,
  "max_requests_per_hour": 1000,
  "warning_threshold": 0.8,
  "pause_on_limit": true
}
EOF
fi

# Initialize requests log
touch "$REQUESTS_FILE"

ACTION="${1:-status}"
WORKER_ID="${2:-unknown}"

# Get current timestamp
NOW=$(date +%s)

# Clean old requests (older than 1 hour)
cleanup_old_requests() {
    local ONE_HOUR_AGO=$((NOW - 3600))
    if [ -f "$REQUESTS_FILE" ]; then
        grep -v "^[0-9]*\s" "$REQUESTS_FILE" > /dev/null 2>&1 || touch "$REQUESTS_FILE"
        awk -v cutoff="$ONE_HOUR_AGO" '$1 > cutoff' "$REQUESTS_FILE" > "$REQUESTS_FILE.tmp"
        mv "$REQUESTS_FILE.tmp" "$REQUESTS_FILE"
    fi
}

# Count requests in time window
count_requests() {
    local SECONDS_AGO=$1
    local CUTOFF=$((NOW - SECONDS_AGO))

    if [ ! -f "$REQUESTS_FILE" ]; then
        echo "0"
        return
    fi

    awk -v cutoff="$CUTOFF" '$1 > cutoff' "$REQUESTS_FILE" | wc -l | tr -d ' '
}

# Read config
read_config() {
    local KEY=$1
    grep "\"$KEY\"" "$CONFIG_FILE" | sed 's/.*: \([0-9.]*\).*/\1/'
}

# Check if request is allowed
check_rate_limit() {
    cleanup_old_requests

    local MAX_PER_MIN=$(read_config "max_requests_per_minute")
    local MAX_PER_HOUR=$(read_config "max_requests_per_hour")
    local WARNING_THRESHOLD=$(read_config "warning_threshold")

    local REQUESTS_LAST_MIN=$(count_requests 60)
    local REQUESTS_LAST_HOUR=$(count_requests 3600)

    local WARNING_MIN=$(echo "$MAX_PER_MIN * $WARNING_THRESHOLD" | bc | cut -d. -f1)
    local WARNING_HOUR=$(echo "$MAX_PER_HOUR * $WARNING_THRESHOLD" | bc | cut -d. -f1)

    # Check hard limits
    if [ "$REQUESTS_LAST_MIN" -ge "$MAX_PER_MIN" ]; then
        echo "{\"allowed\": false, \"reason\": \"rate_limit_minute\", \"wait_seconds\": 60, \"requests_last_min\": $REQUESTS_LAST_MIN, \"requests_last_hour\": $REQUESTS_LAST_HOUR}"
        return 1
    fi

    if [ "$REQUESTS_LAST_HOUR" -ge "$MAX_PER_HOUR" ]; then
        echo "{\"allowed\": false, \"reason\": \"rate_limit_hour\", \"wait_seconds\": 3600, \"requests_last_min\": $REQUESTS_LAST_MIN, \"requests_last_hour\": $REQUESTS_LAST_HOUR}"
        return 1
    fi

    # Check warnings
    local STATUS="ok"
    if [ "$REQUESTS_LAST_MIN" -ge "$WARNING_MIN" ]; then
        STATUS="warning_minute"
    fi
    if [ "$REQUESTS_LAST_HOUR" -ge "$WARNING_HOUR" ]; then
        STATUS="warning_hour"
    fi

    echo "{\"allowed\": true, \"status\": \"$STATUS\", \"requests_last_min\": $REQUESTS_LAST_MIN, \"requests_last_hour\": $REQUESTS_LAST_HOUR, \"max_per_min\": $MAX_PER_MIN, \"max_per_hour\": $MAX_PER_HOUR}"
    return 0
}

# Record a request
record_request() {
    echo "$NOW $WORKER_ID" >> "$REQUESTS_FILE"
    echo "{\"success\": true, \"timestamp\": $NOW, \"worker_id\": \"$WORKER_ID\"}"
}

# Show status
show_status() {
    cleanup_old_requests

    local MAX_PER_MIN=$(read_config "max_requests_per_minute")
    local MAX_PER_HOUR=$(read_config "max_requests_per_hour")

    local REQUESTS_LAST_MIN=$(count_requests 60)
    local REQUESTS_LAST_HOUR=$(count_requests 3600)

    local PERCENT_MIN=$(echo "scale=1; $REQUESTS_LAST_MIN * 100 / $MAX_PER_MIN" | bc)
    local PERCENT_HOUR=$(echo "scale=1; $REQUESTS_LAST_HOUR * 100 / $MAX_PER_HOUR" | bc)

    cat <<EOF
{
  "rate_limiter_status": {
    "requests_last_minute": $REQUESTS_LAST_MIN,
    "max_per_minute": $MAX_PER_MIN,
    "percent_used_minute": $PERCENT_MIN,
    "requests_last_hour": $REQUESTS_LAST_HOUR,
    "max_per_hour": $MAX_PER_HOUR,
    "percent_used_hour": $PERCENT_HOUR,
    "status": "$([ $(echo "$PERCENT_HOUR > 80" | bc) -eq 1 ] && echo "warning" || echo "ok")"
  }
}
EOF
}

# Reset rate limiter
reset_limiter() {
    rm -f "$REQUESTS_FILE"
    touch "$REQUESTS_FILE"
    echo "{\"success\": true, \"message\": \"Rate limiter reset\"}"
}

# Main logic
case "$ACTION" in
    check)
        check_rate_limit
        ;;
    record)
        record_request
        ;;
    status)
        show_status
        ;;
    reset)
        reset_limiter
        ;;
    *)
        echo "{\"error\": \"Unknown action: $ACTION. Use: check, record, status, reset\"}"
        exit 1
        ;;
esac
