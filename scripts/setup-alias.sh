#!/bin/bash

# Setup claude+ Alias
# Configures claude+ alias for bypass mode
# Usage: setup-alias.sh

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Setting up claude+ alias${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Detect shell
SHELL_NAME=$(basename "$SHELL")
SHELL_RC=""

case "$SHELL_NAME" in
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    bash)
        if [ -f "$HOME/.bash_profile" ]; then
            SHELL_RC="$HOME/.bash_profile"
        else
            SHELL_RC="$HOME/.bashrc"
        fi
        ;;
    *)
        echo -e "${YELLOW}⚠ Unknown shell: $SHELL_NAME${NC}"
        echo "Please add this manually to your shell config:"
        echo ""
        echo "alias claude+='claude --dangerously-skip-permissions'"
        echo ""
        exit 1
        ;;
esac

echo "Detected shell: $SHELL_NAME"
echo "Config file: $SHELL_RC"
echo ""

# Check if alias already exists
if grep -q "alias claude+=" "$SHELL_RC" 2>/dev/null; then
    echo -e "${GREEN}✓ Alias already exists in $SHELL_RC${NC}"
else
    echo "Adding alias to $SHELL_RC..."

    # Backup
    cp "$SHELL_RC" "$SHELL_RC.backup-$(date +%s)"

    # Add alias
    cat >> "$SHELL_RC" <<EOF

# Claude+ alias for orchestrator bypass mode
alias claude+='claude --dangerously-skip-permissions'
EOF

    echo -e "${GREEN}✓ Alias added!${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}⚠ Important: Reload your shell${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Run one of:"
echo ""
echo "  source $SHELL_RC"
echo "  exec $SHELL_NAME"
echo ""
echo "Then verify:"
echo ""
echo "  claude+ --version"
echo ""

cat <<EOF
{
  "success": true,
  "shell": "$SHELL_NAME",
  "config_file": "$SHELL_RC",
  "alias": "claude+='claude --dangerously-skip-permissions'"
}
EOF
