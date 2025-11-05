#!/bin/bash

# Setup Wizard - Interactive installation guide
# Usage: setup-wizard.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear

echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                           ║${NC}"
echo -e "${BOLD}${CYAN}║        🎭 CLAUDE iTERM ORCHESTRATOR SETUP WIZARD          ║${NC}"
echo -e "${BOLD}${CYAN}║                                                           ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}Welcome! This wizard will guide you through the setup process.${NC}"
echo ""

# Step 1: Check dependencies
echo -e "${BOLD}${BLUE}Step 1: Checking Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

"$SCRIPT_DIR/check-deps.sh"
DEPS_OK=$?

echo ""

if [ "$DEPS_OK" -ne 0 ]; then
    echo -e "${RED}✗ Some critical dependencies are missing.${NC}"
    echo ""
    echo "Please install missing dependencies and run this wizard again."
    echo ""
    exit 1
fi

# Step 2: Install npm dependencies
echo -e "${BOLD}${BLUE}Step 2: Installing Node Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_ROOT" || exit 1

if [ -f "package.json" ]; then
    echo "Running: npm install"
    echo ""
    npm install

    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Dependencies installed${NC}"
    else
        echo ""
        echo -e "${RED}✗ Failed to install dependencies${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ No package.json found${NC}"
fi

echo ""

# Step 3: Setup claude+ alias
echo -e "${BOLD}${BLUE}Step 3: Configure claude+ Alias${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "The claude+ alias enables bypass mode for worker orchestration."
echo ""
echo -n "Would you like to configure it now? (y/n): "
read -r SETUP_ALIAS

if [[ "$SETUP_ALIAS" =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/setup-alias.sh"
else
    echo ""
    echo -e "${YELLOW}Skipped. You can run this later:${NC}"
    echo "  ./scripts/setup-alias.sh"
fi

echo ""

# Step 4: Initialize configuration
echo -e "${BOLD}${BLUE}Step 4: Initialize Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

CONFIG_DIR="$HOME/.claude-orchestrator"
CONFIG_FILE="$CONFIG_DIR/config.json"

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓ Configuration already exists${NC}"
    echo "  Location: $CONFIG_FILE"
else
    mkdir -p "$CONFIG_DIR"

    if [ -f "$PROJECT_ROOT/config.example.json" ]; then
        cp "$PROJECT_ROOT/config.example.json" "$CONFIG_FILE"
        echo -e "${GREEN}✓ Configuration initialized${NC}"
        echo "  Location: $CONFIG_FILE"
    else
        echo -e "${YELLOW}⚠ Example config not found${NC}"
    fi
fi

echo ""

# Step 5: Choose subscription type
echo -e "${BOLD}${BLUE}Step 5: Configure Subscription${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "What Claude subscription do you have?"
echo ""
echo "  1) Claude Pro ($20/month)"
echo "  2) Claude Max ($100/month)"
echo ""
echo -n "Enter choice (1-2): "
read -r SUBSCRIPTION_CHOICE

case "$SUBSCRIPTION_CHOICE" in
    1)
        SUBSCRIPTION="pro"
        COST=20
        ;;
    2)
        SUBSCRIPTION="max"
        COST=100
        ;;
    *)
        echo -e "${YELLOW}Invalid choice, defaulting to Pro${NC}"
        SUBSCRIPTION="pro"
        COST=20
        ;;
esac

# Update config
if [ -f "$CONFIG_FILE" ]; then
    jq ".subscription.type = \"$SUBSCRIPTION\" | .subscription.monthly_cost = $COST" "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
    mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

echo ""
echo -e "${GREEN}✓ Subscription set to: $SUBSCRIPTION ($COST/month)${NC}"
echo ""

# Step 6: Test run
echo -e "${BOLD}${BLUE}Step 6: Test Installation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -n "Would you like to run a test? (y/n): "
read -r RUN_TEST

if [[ "$RUN_TEST" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Testing rate limiter..."
    "$SCRIPT_DIR/rate-limiter.sh" status

    echo ""
    echo "Testing cost estimator..."
    "$SCRIPT_DIR/cost-estimator.sh" today "$SUBSCRIPTION"

    echo ""
    echo -e "${GREEN}✓ Test completed${NC}"
fi

echo ""

# Summary
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                 ✅ SETUP COMPLETE!                         ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BOLD}Next steps:${NC}"
echo ""
echo "1. ${GREEN}Reload your shell${NC} (if you configured claude+ alias):"
echo "   source ~/.zshrc  # or ~/.bashrc"
echo ""
echo "2. ${GREEN}Start the MCP server${NC}:"
echo "   node server.js"
echo ""
echo "3. ${GREEN}View dashboard${NC}:"
echo "   ./scripts/show-dashboard.sh $SUBSCRIPTION"
echo ""
echo "4. ${GREEN}Read the docs${NC}:"
echo "   cat README.md"
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}Thank you for using Claude iTerm Orchestrator!${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cat <<EOF
{
  "setup_complete": true,
  "subscription": "$SUBSCRIPTION",
  "config_location": "$CONFIG_FILE"
}
EOF
