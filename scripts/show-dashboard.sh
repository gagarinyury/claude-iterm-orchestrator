#!/bin/bash

# Dashboard - Visual monitoring of orchestrator system
# Usage: show-dashboard.sh [subscription_type]
#        subscription_type: pro, max (default: pro)

SUBSCRIPTION="${1:-pro}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Get all data
RATE_LIMIT_DATA=$("$SCRIPT_DIR/rate-limiter.sh" status 2>/dev/null)
QUEUE_DATA=$("$SCRIPT_DIR/queue-manager.sh" status 2>/dev/null)
TOKEN_DATA=$("$SCRIPT_DIR/estimate-tokens.sh" today 2>/dev/null)
COST_DATA=$("$SCRIPT_DIR/cost-estimator.sh" today "$SUBSCRIPTION" 2>/dev/null)

# Get workers count
WORKERS_COUNT=0
if [ -f "/tmp/workers/registry.txt" ]; then
    WORKERS_COUNT=$(wc -l < /tmp/workers/registry.txt | tr -d ' ')
fi

# Extract values
REQUESTS_LAST_MIN=$(echo "$RATE_LIMIT_DATA" | jq -r '.rate_limiter_status.requests_last_minute // 0')
REQUESTS_LAST_HOUR=$(echo "$RATE_LIMIT_DATA" | jq -r '.rate_limiter_status.requests_last_hour // 0')
MAX_PER_MIN=$(echo "$RATE_LIMIT_DATA" | jq -r '.rate_limiter_status.max_per_minute // 50')
MAX_PER_HOUR=$(echo "$RATE_LIMIT_DATA" | jq -r '.rate_limiter_status.max_per_hour // 1000')
PERCENT_MIN=$(echo "$RATE_LIMIT_DATA" | jq -r '.rate_limiter_status.percent_used_minute // 0')
PERCENT_HOUR=$(echo "$RATE_LIMIT_DATA" | jq -r '.rate_limiter_status.percent_used_hour // 0')

QUEUE_SIZE=$(echo "$QUEUE_DATA" | jq -r '.queue_status.size // 0')
QUEUE_WAIT=$(echo "$QUEUE_DATA" | jq -r '.queue_status.oldest_wait_seconds // 0')

TOKENS_TODAY=$(echo "$TOKEN_DATA" | jq -r '.token_estimates.today.formatted // "0"')
TOKENS_PROJECTED=$(echo "$TOKEN_DATA" | jq -r '.token_estimates.today.projected_formatted // "0"')
TOKENS_PER_HOUR=$(echo "$TOKEN_DATA" | jq -r '.token_estimates.rates.formatted // "0/hour"')

SAVINGS=$(echo "$COST_DATA" | jq -r '.cost_analysis.costs.savings.formatted // "$0"')
SAVINGS_MONTH=$(echo "$COST_DATA" | jq -r '.cost_analysis.monthly_projection.formatted_savings // "$0/month"')
ROI_STATUS=$(echo "$COST_DATA" | jq -r '.cost_analysis.roi.message // "N/A"')

# Status colors
RATE_COLOR=$GREEN
if [ $(echo "$PERCENT_HOUR > 80" | bc 2>/dev/null) -eq 1 ]; then
    RATE_COLOR=$RED
elif [ $(echo "$PERCENT_HOUR > 60" | bc 2>/dev/null) -eq 1 ]; then
    RATE_COLOR=$YELLOW
fi

QUEUE_COLOR=$GREEN
if [ "$QUEUE_SIZE" -gt 10 ]; then
    QUEUE_COLOR=$RED
elif [ "$QUEUE_SIZE" -gt 5 ]; then
    QUEUE_COLOR=$YELLOW
fi

# Build dashboard
clear
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║          🎭 CLAUDE ORCHESTRATOR DASHBOARD                    ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}📊 WORKERS${NC}"
echo -e "   Active workers: ${GREEN}$WORKERS_COUNT${NC}"
echo ""
echo -e "${BOLD}⚡ RATE LIMITS${NC}"
echo -e "   Last minute:    ${RATE_COLOR}$REQUESTS_LAST_MIN${NC} / $MAX_PER_MIN  (${PERCENT_MIN}%)"
echo -e "   Last hour:      ${RATE_COLOR}$REQUESTS_LAST_HOUR${NC} / $MAX_PER_HOUR  (${PERCENT_HOUR}%)"
if [ $(echo "$PERCENT_HOUR > 80" | bc 2>/dev/null) -eq 1 ]; then
    echo -e "   ${RED}⚠️  WARNING: Approaching rate limit!${NC}"
fi
echo ""
echo -e "${BOLD}📋 REQUEST QUEUE${NC}"
echo -e "   Queue size:     ${QUEUE_COLOR}$QUEUE_SIZE${NC} requests"
if [ "$QUEUE_SIZE" -gt 0 ]; then
    echo -e "   Oldest wait:    ${YELLOW}${QUEUE_WAIT}s${NC}"
fi
echo ""
echo -e "${BOLD}🎯 TOKEN USAGE (Estimated)${NC}"
echo -e "   Today so far:   ${BLUE}$TOKENS_TODAY${NC} tokens"
echo -e "   Projected:      ${BLUE}$TOKENS_PROJECTED${NC} tokens/day"
echo -e "   Rate:           ${BLUE}$TOKENS_PER_HOUR${NC}"
echo ""
echo -e "${BOLD}💰 COST SAVINGS (Subscription: $SUBSCRIPTION)${NC}"
echo -e "   Today:          ${GREEN}$SAVINGS${NC}"
echo -e "   Projected:      ${GREEN}$SAVINGS_MONTH${NC}"
echo -e "   $ROI_STATUS"
echo ""
echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
echo -e "Updated: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "${CYAN}─────────────────────────────────────────────────────────────${NC}"
echo ""

# Also output JSON for programmatic access
cat <<EOF
{
  "dashboard": {
    "timestamp": $(date +%s),
    "workers": {
      "active": $WORKERS_COUNT
    },
    "rate_limits": {
      "requests_last_min": $REQUESTS_LAST_MIN,
      "max_per_min": $MAX_PER_MIN,
      "percent_min": $PERCENT_MIN,
      "requests_last_hour": $REQUESTS_LAST_HOUR,
      "max_per_hour": $MAX_PER_HOUR,
      "percent_hour": $PERCENT_HOUR,
      "status": "$([ $(echo "$PERCENT_HOUR > 80" | bc 2>/dev/null) -eq 1 ] && echo "warning" || echo "ok")"
    },
    "queue": {
      "size": $QUEUE_SIZE,
      "oldest_wait_seconds": $QUEUE_WAIT
    },
    "tokens": {
      "today": "$TOKENS_TODAY",
      "projected": "$TOKENS_PROJECTED",
      "rate": "$TOKENS_PER_HOUR"
    },
    "cost_savings": {
      "today": "$SAVINGS",
      "projected_month": "$SAVINGS_MONTH",
      "subscription": "$SUBSCRIPTION"
    }
  }
}
EOF
