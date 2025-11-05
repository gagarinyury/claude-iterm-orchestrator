#!/bin/bash

# Estimate Token Usage
# Estimates approximate token usage for tracking
# Usage: estimate-tokens.sh [period]
#        period: today, week, month (default: today)

PERIOD="${1:-today}"
TOKEN_LOG_DIR="/tmp/claude-tokens"
TOKEN_LOG="$TOKEN_LOG_DIR/usage.log"

mkdir -p "$TOKEN_LOG_DIR"
touch "$TOKEN_LOG"

NOW=$(date +%s)

# Estimate tokens from request log
estimate_from_requests() {
    local REQUESTS_FILE="/tmp/claude-rate-limiter/requests.log"

    if [ ! -f "$REQUESTS_FILE" ]; then
        echo "0"
        return
    fi

    # Average tokens per request (rough estimate)
    # Input: ~1000 tokens, Output: ~2000 tokens = 3000 total
    local AVG_TOKENS_PER_REQUEST=3000

    local COUNT=$(wc -l < "$REQUESTS_FILE" | tr -d ' ')
    local TOTAL=$((COUNT * AVG_TOKENS_PER_REQUEST))

    echo "$TOTAL"
}

# Get cutoff time based on period
get_cutoff_time() {
    case "$1" in
        today)
            # Start of today
            date -d "today 00:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$(date +%Y-%m-%d) 00:00:00" +%s
            ;;
        week)
            # 7 days ago
            echo $((NOW - 604800))
            ;;
        month)
            # 30 days ago
            echo $((NOW - 2592000))
            ;;
        *)
            echo "$NOW"
            ;;
    esac
}

# Count tokens in period
count_tokens_in_period() {
    local CUTOFF=$(get_cutoff_time "$PERIOD")
    local REQUESTS_FILE="/tmp/claude-rate-limiter/requests.log"

    if [ ! -f "$REQUESTS_FILE" ]; then
        echo "0"
        return
    fi

    # Count requests since cutoff
    local COUNT=$(awk -v cutoff="$CUTOFF" '$1 > cutoff' "$REQUESTS_FILE" | wc -l | tr -d ' ')

    # Estimate tokens (3000 per request average)
    local TOKENS=$((COUNT * 3000))
    echo "$TOKENS"
}

# Format large numbers
format_number() {
    local NUM=$1
    if [ "$NUM" -ge 1000000 ]; then
        echo "$(echo "scale=2; $NUM / 1000000" | bc)M"
    elif [ "$NUM" -ge 1000 ]; then
        echo "$(echo "scale=1; $NUM / 1000" | bc)K"
    else
        echo "$NUM"
    fi
}

# Get estimates
TOKENS_TODAY=$(count_tokens_in_period "today")
TOKENS_WEEK=$(count_tokens_in_period "week")
TOKENS_MONTH=$(count_tokens_in_period "month")

# Calculate rates
SECONDS_TODAY=$((NOW - $(get_cutoff_time "today")))
TOKENS_PER_HOUR=0
if [ "$SECONDS_TODAY" -gt 0 ]; then
    TOKENS_PER_HOUR=$((TOKENS_TODAY * 3600 / SECONDS_TODAY))
fi

# Estimate for full day
TOKENS_PROJECTED_TODAY=$((TOKENS_PER_HOUR * 24))

# Output JSON
cat <<EOF
{
  "token_estimates": {
    "today": {
      "tokens": $TOKENS_TODAY,
      "formatted": "$(format_number $TOKENS_TODAY)",
      "projected_full_day": $TOKENS_PROJECTED_TODAY,
      "projected_formatted": "$(format_number $TOKENS_PROJECTED_TODAY)"
    },
    "week": {
      "tokens": $TOKENS_WEEK,
      "formatted": "$(format_number $TOKENS_WEEK)"
    },
    "month": {
      "tokens": $TOKENS_MONTH,
      "formatted": "$(format_number $TOKENS_MONTH)"
    },
    "rates": {
      "tokens_per_hour": $TOKENS_PER_HOUR,
      "formatted": "$(format_number $TOKENS_PER_HOUR)/hour"
    },
    "note": "Estimates based on average 3K tokens per request"
  }
}
EOF
