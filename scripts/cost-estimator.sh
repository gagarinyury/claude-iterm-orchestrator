#!/bin/bash

# Cost Estimator
# Calculate cost savings vs API
# Usage: cost-estimator.sh [period] [subscription_type]
#        period: today, week, month (default: today)
#        subscription_type: pro, max (default: pro)

PERIOD="${1:-today}"
SUBSCRIPTION="${2:-pro}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pricing (USD)
# API pricing per 1M tokens (Sonnet 4)
API_COST_PER_M_INPUT=3.00
API_COST_PER_M_OUTPUT=15.00
API_COST_PER_M_AVG=9.00  # Average (assuming 1:2 input/output ratio)

# Subscription costs per month
CLAUDE_PRO_MONTHLY=20
CLAUDE_MAX_MONTHLY=100

# Get subscription cost
get_subscription_cost() {
    case "$1" in
        pro)
            echo "$CLAUDE_PRO_MONTHLY"
            ;;
        max)
            echo "$CLAUDE_MAX_MONTHLY"
            ;;
        *)
            echo "$CLAUDE_PRO_MONTHLY"
            ;;
    esac
}

# Get period days
get_period_days() {
    case "$1" in
        today)
            echo "1"
            ;;
        week)
            echo "7"
            ;;
        month)
            echo "30"
            ;;
        *)
            echo "1"
            ;;
    esac
}

# Get token estimates
TOKEN_DATA=$("$SCRIPT_DIR/estimate-tokens.sh" "$PERIOD")
TOKENS=$(echo "$TOKEN_DATA" | jq -r ".token_estimates.$PERIOD.tokens")

# Calculate API cost
# Cost in dollars = (tokens / 1,000,000) * cost_per_million
API_COST=$(echo "scale=2; $TOKENS / 1000000 * $API_COST_PER_M_AVG" | bc)

# Calculate subscription cost for period
PERIOD_DAYS=$(get_period_days "$PERIOD")
SUBSCRIPTION_COST=$(get_subscription_cost "$SUBSCRIPTION")
SUBSCRIPTION_COST_PERIOD=$(echo "scale=2; $SUBSCRIPTION_COST * $PERIOD_DAYS / 30" | bc)

# Calculate savings
SAVINGS=$(echo "scale=2; $API_COST - $SUBSCRIPTION_COST_PERIOD" | bc)

# Calculate savings percentage
SAVINGS_PERCENT=0
if [ $(echo "$API_COST > 0" | bc) -eq 1 ]; then
    SAVINGS_PERCENT=$(echo "scale=1; ($SAVINGS / $API_COST) * 100" | bc)
fi

# ROI (Return on Investment)
ROI=$(echo "scale=0; $SAVINGS_PERCENT" | bc | cut -d. -f1)

# Projection to month if period is shorter
TOKENS_PROJECTED_MONTH=$TOKENS
if [ "$PERIOD" == "today" ]; then
    TOKENS_PROJECTED_MONTH=$((TOKENS * 30))
elif [ "$PERIOD" == "week" ]; then
    TOKENS_PROJECTED_MONTH=$((TOKENS * 30 / 7))
fi

API_COST_PROJECTED_MONTH=$(echo "scale=2; $TOKENS_PROJECTED_MONTH / 1000000 * $API_COST_PER_M_AVG" | bc)
SAVINGS_PROJECTED_MONTH=$(echo "scale=2; $API_COST_PROJECTED_MONTH - $SUBSCRIPTION_COST" | bc)

# Format output
cat <<EOF
{
  "cost_analysis": {
    "period": "$PERIOD",
    "period_days": $PERIOD_DAYS,
    "subscription_type": "$SUBSCRIPTION",
    "tokens_used": $TOKENS,
    "costs": {
      "api_would_cost": {
        "amount": $API_COST,
        "currency": "USD",
        "formatted": "\$$API_COST"
      },
      "subscription_cost": {
        "amount": $SUBSCRIPTION_COST_PERIOD,
        "currency": "USD",
        "formatted": "\$$SUBSCRIPTION_COST_PERIOD"
      },
      "savings": {
        "amount": $SAVINGS,
        "currency": "USD",
        "formatted": "\$$SAVINGS",
        "percent": $SAVINGS_PERCENT
      }
    },
    "monthly_projection": {
      "tokens": $TOKENS_PROJECTED_MONTH,
      "api_cost": $API_COST_PROJECTED_MONTH,
      "subscription_cost": $SUBSCRIPTION_COST,
      "savings": $SAVINGS_PROJECTED_MONTH,
      "formatted_savings": "\$$SAVINGS_PROJECTED_MONTH/month"
    },
    "roi": {
      "percentage": $ROI,
      "status": "$([ $(echo "$SAVINGS > 0" | bc) -eq 1 ] && echo "saving" || echo "losing")",
      "message": "$([ $(echo "$SAVINGS > 0" | bc) -eq 1 ] && echo "💰 You're saving money!" || echo "⚠️ API might be cheaper for your usage")"
    }
  }
}
EOF
