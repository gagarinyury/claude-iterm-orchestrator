#!/bin/bash

# Comprehensive test of all 15 MCP tools
# This script validates that all tools are accessible via MCP server

echo "🧪 Testing Claude iTerm Orchestrator - All 15 Tools"
echo "=================================================="
echo ""

SERVER="node server.js"
SUCCESS_COUNT=0
FAIL_COUNT=0

# Helper function to test a tool
test_tool() {
    local tool_name="$1"
    local test_description="$2"

    echo -n "Testing: $tool_name ... "

    # Check if tool exists in tools/list
    result=$(echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | $SERVER 2>/dev/null | jq -r ".result.tools[] | select(.name == \"$tool_name\") | .name")

    if [ "$result" == "$tool_name" ]; then
        echo "✅ PASS - $test_description"
        ((SUCCESS_COUNT++))
        return 0
    else
        echo "❌ FAIL - $test_description"
        ((FAIL_COUNT++))
        return 1
    fi
}

# Test 1: Server initialization
echo "=== Part 1: Server Initialization ==="
echo -n "Testing: MCP Server startup ... "
if echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | $SERVER 2>/dev/null | jq -e '.result.tools' > /dev/null; then
    echo "✅ PASS"
    ((SUCCESS_COUNT++))
else
    echo "❌ FAIL"
    ((FAIL_COUNT++))
    exit 1
fi

# Count tools
TOOL_COUNT=$(echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | $SERVER 2>/dev/null | jq '.result.tools | length')
echo "Tools registered: $TOOL_COUNT"
echo ""

# Test 2: Basic worker lifecycle tools
echo "=== Part 2: Worker Lifecycle Tools (4) ==="
test_tool "create_worker" "Create new worker in iTerm tab"
test_tool "kill_worker" "Close worker tab"
test_tool "list_workers" "List all active workers"
test_tool "get_worker_info" "Get detailed worker info"
echo ""

# Test 3: Communication tools
echo "=== Part 3: Communication Tools (3) ==="
test_tool "send_to_worker" "Send text without Enter"
test_tool "send_to_claude" "Send text with Enter (for Claude CLI)"
test_tool "read_from_worker" "Read terminal output"
echo ""

# Test 4: Variables tools
echo "=== Part 4: Variables Tools (2) ==="
test_tool "set_variable" "Store data in worker session"
test_tool "get_variable" "Retrieve stored data"
echo ""

# Test 5: Advanced monitoring tools
echo "=== Part 5: Advanced Monitoring Tools (2) ==="
test_tool "set_tab_color" "Set tab color for worker"
test_tool "monitor_variable" "Monitor variable changes"
echo ""

# Test 6: Task management tools
echo "=== Part 6: Task Management Tools (2) ==="
test_tool "assign_task" "Assign task to worker"
test_tool "complete_task" "Mark task as completed"
echo ""

# Test 7: Orchestrator system tools
echo "=== Part 7: Orchestrator System Tools (2) ==="
test_tool "get_role_instructions" "Get role and instructions"
test_tool "ask_orchestrator" "Worker asks orchestrator question"
echo ""

# Test 8: Validate all bash scripts exist
echo "=== Part 8: Bash Scripts Validation ==="
SCRIPTS=(
    "create-worker.sh"
    "send-command.sh"
    "send-to-claude-v3.sh"
    "read-output.sh"
    "list-workers.sh"
    "kill-worker.sh"
    "get-worker-info.sh"
    "set-variable.sh"
    "get-variable.sh"
    "set-tab-color.sh"
    "monitor-variable.sh"
    "assign-task.sh"
    "complete-task.sh"
    "get-role-instructions.sh"
    "ask-orchestrator.sh"
)

for script in "${SCRIPTS[@]}"; do
    echo -n "Script: $script ... "
    if [ -f "scripts/$script" ] && [ -x "scripts/$script" ]; then
        echo "✅ EXISTS & EXECUTABLE"
        ((SUCCESS_COUNT++))
    else
        echo "❌ MISSING OR NOT EXECUTABLE"
        ((FAIL_COUNT++))
    fi
done
echo ""

# Test 9: Tool descriptions
echo "=== Part 9: Tool Descriptions Validation ==="
echo -n "Checking all tools have descriptions ... "
MISSING_DESC=$(echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | $SERVER 2>/dev/null | jq -r '.result.tools[] | select(.description == null or .description == "") | .name' | wc -l)
if [ "$MISSING_DESC" -eq 0 ]; then
    echo "✅ PASS - All tools have descriptions"
    ((SUCCESS_COUNT++))
else
    echo "❌ FAIL - $MISSING_DESC tools missing descriptions"
    ((FAIL_COUNT++))
fi
echo ""

# Summary
echo "=================================================="
echo "📊 Test Results Summary"
echo "=================================================="
echo "✅ Passed: $SUCCESS_COUNT"
echo "❌ Failed: $FAIL_COUNT"
echo "📈 Total:  $((SUCCESS_COUNT + FAIL_COUNT))"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "🎉 All tests passed! System is ready."
    exit 0
else
    echo "⚠️  Some tests failed. Please review."
    exit 1
fi
