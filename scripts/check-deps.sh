#!/bin/bash

# Check Dependencies
# Verifies all required dependencies are installed
# Usage: check-deps.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo "🔍 Checking dependencies..."
echo ""

# Check Node.js
echo -n "Checking Node.js... "
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    MAJOR_VERSION=$(echo "$NODE_VERSION" | cut -d'.' -f1 | tr -d 'v')

    if [ "$MAJOR_VERSION" -ge 18 ]; then
        echo -e "${GREEN}✓${NC} $NODE_VERSION"
    else
        echo -e "${RED}✗${NC} $NODE_VERSION (need ≥18.0.0)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Install from: https://nodejs.org/"
    ERRORS=$((ERRORS + 1))
fi

# Check Python
echo -n "Checking Python... "
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    MAJOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f1)
    MINOR=$(echo "$PYTHON_VERSION" | cut -d'.' -f2)

    if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 8 ]; then
        echo -e "${GREEN}✓${NC} $PYTHON_VERSION"
    else
        echo -e "${RED}✗${NC} $PYTHON_VERSION (need ≥3.8.0)"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Install from: https://python.org/"
    ERRORS=$((ERRORS + 1))
fi

# Check jq
echo -n "Checking jq... "
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version)
    echo -e "${GREEN}✓${NC} $JQ_VERSION"
else
    echo -e "${YELLOW}⚠${NC} Not found (optional but recommended)"
    echo "  Install: brew install jq"
    WARNINGS=$((WARNINGS + 1))
fi

# Check bc
echo -n "Checking bc... "
if command -v bc &> /dev/null; then
    echo -e "${GREEN}✓${NC} Installed"
else
    echo -e "${YELLOW}⚠${NC} Not found (optional for calculations)"
    echo "  Install: brew install bc"
    WARNINGS=$((WARNINGS + 1))
fi

# Check iTerm2 (macOS only)
echo -n "Checking iTerm2... "
if [ -d "/Applications/iTerm.app" ]; then
    echo -e "${GREEN}✓${NC} Installed"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Install from: https://iterm2.com/"
    ERRORS=$((ERRORS + 1))
fi

# Check Claude CLI
echo -n "Checking Claude CLI... "
if command -v claude &> /dev/null; then
    echo -e "${GREEN}✓${NC} Installed"
else
    echo -e "${YELLOW}⚠${NC} Not found (install if you want to use workers)"
    echo "  Install: npm install -g @anthropic-ai/claude-cli"
    WARNINGS=$((WARNINGS + 1))
fi

# Check claude+ alias
echo -n "Checking claude+ alias... "
if type claude+ &> /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Configured"
else
    echo -e "${YELLOW}⚠${NC} Not configured"
    echo "  Run setup-alias.sh to configure"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓ All critical dependencies met!${NC}"
else
    echo -e "${RED}✗ $ERRORS critical dependency(ies) missing${NC}"
fi

if [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS optional dependency(ies) missing${NC}"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# JSON output
cat <<EOF
{
  "dependencies": {
    "critical_missing": $ERRORS,
    "optional_missing": $WARNINGS,
    "ready": $([ "$ERRORS" -eq 0 ] && echo "true" || echo "false")
  }
}
EOF

# Exit with error if critical deps missing
[ "$ERRORS" -eq 0 ] && exit 0 || exit 1
