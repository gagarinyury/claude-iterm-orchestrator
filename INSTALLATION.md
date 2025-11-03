# 📦 Installation Guide - Claude iTerm Orchestrator

Complete guide for installing the Claude iTerm Orchestrator MCP server globally in **Claude Code** and **Claude Desktop**.

---

## 🎯 Overview

This MCP server allows Claude to control multiple worker instances in iTerm2 tabs for orchestrating complex multi-agent tasks.

**What you'll install:**
- ✅ MCP server accessible from any Claude Code project
- ✅ MCP server accessible from Claude Desktop app
- ✅ 16 tools for worker management, communication, and orchestration

---

## ✅ Prerequisites

Before installation, ensure you have:

1. **macOS** (iTerm2 is macOS-only)
2. **Node.js** ≥ 18.0.0
   ```bash
   node --version  # Should show v18.0.0 or higher
   ```
3. **Python** ≥ 3.8.0 with iTerm2 Python API
   ```bash
   python3 --version  # Should show 3.8.0 or higher
   ```
4. **iTerm2** with Python API enabled
   - Download from: https://iterm2.com/
   - Enable Python API: iTerm2 → Preferences → General → Magic → Enable Python API
5. **Claude Code CLI** or **Claude Desktop** installed

---

## 📥 Step 1: Install the MCP Server

### Option A: Install from npm (Recommended)

```bash
npm install -g claude-iterm-orchestrator
```

### Option B: Install from Source

```bash
# Clone the repository
git clone https://github.com/gagarinyury/claude-iterm-orchestrator.git
cd claude-iterm-orchestrator

# Install dependencies
npm install

# Link globally
npm link
```

### Verify Installation

```bash
# Check that the command is available
which claude-orchestrator
# Should output: /usr/local/bin/claude-orchestrator (or similar)

# Test the server
echo '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}' | claude-orchestrator
# Should return JSON with list of 16 tools
```

---

## 🔧 Step 2: Configure Claude Code

### Find Your Configuration File

Claude Code stores global MCP server configuration in:
```
~/.claude.json
```

### Add the Server Configuration

1. **Open the config file:**
   ```bash
   open -a "TextEdit" ~/.claude.json
   # Or use your preferred editor:
   code ~/.claude.json
   vim ~/.claude.json
   ```

2. **Add the orchestrator to `mcpServers`:**

   ```json
   {
     "mcpServers": {
       "claude-orchestrator": {
         "command": "node",
         "args": [
           "/Users/YOUR_USERNAME/code/claude-iterm-orchestrator/server.js"
         ]
       }
     }
   }
   ```

   **Important:** Replace `/Users/YOUR_USERNAME/code/claude-iterm-orchestrator/server.js` with the **absolute path** to your `server.js` file.

3. **To find your absolute path:**
   ```bash
   cd /path/to/claude-iterm-orchestrator
   pwd
   # Copy the output and append /server.js
   ```

### Alternative: Using npx (if installed globally)

If you installed via npm globally or `npm link`, you can use:

```json
{
  "mcpServers": {
    "claude-orchestrator": {
      "command": "npx",
      "args": [
        "-y",
        "claude-orchestrator"
      ]
    }
  }
}
```

### Restart Claude Code

After saving the configuration:
```bash
# Restart Claude Code completely
# (Quit and reopen the application)
```

### Verify Installation in Claude Code

1. Start a new Claude Code session in any project
2. Type a message that would trigger MCP tools
3. Check that orchestrator tools are available:
   - Look for tools like `create_worker`, `list_workers`, etc.
   - Tools should appear in autocomplete or tool selection

---

## 🖥️ Step 3: Configure Claude Desktop

### Find Your Configuration File

Claude Desktop stores MCP configuration in:
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

### Add the Server Configuration

1. **Option A: Use Claude Desktop UI**
   - Open Claude Desktop
   - Go to: Claude → Settings (⌘,)
   - Click "Developer" tab
   - Click "Edit Config"
   - This opens Finder showing the config file location

2. **Option B: Edit directly**
   ```bash
   open -a "TextEdit" ~/Library/Application\ Support/Claude/claude_desktop_config.json
   ```

3. **Add the orchestrator:**

   ```json
   {
     "mcpServers": {
       "claude-orchestrator": {
         "command": "node",
         "args": [
           "/Users/YOUR_USERNAME/code/claude-iterm-orchestrator/server.js"
         ]
       }
     },
     "preferences": {
       "quickEntryDictationShortcut": "capslock"
     }
   }
   ```

   **Important:**
   - Replace `/Users/YOUR_USERNAME/...` with your absolute path
   - Keep any existing `preferences` section
   - If `mcpServers` already exists, add `claude-orchestrator` to it

### Restart Claude Desktop

**You MUST restart Claude Desktop** for changes to take effect:
1. Quit Claude Desktop completely (⌘Q)
2. Reopen Claude Desktop

### Verify Installation in Claude Desktop

1. Start a new conversation
2. Look for the 🔌 icon in the bottom-left corner
3. Click it to see available MCP servers
4. "claude-orchestrator" should be listed with 16 tools

---

## ✅ Step 4: Verify Everything Works

### Test in Claude Code

```bash
# In any project directory, start Claude Code
claude

# In the chat, try:
> Can you list available MCP tools?

# Should show claude-orchestrator with 16 tools:
# - create_worker, create_worker_claude
# - list_workers, get_worker_info, kill_worker
# - send_to_worker, send_to_claude, read_from_worker
# - set_variable, get_variable
# - set_tab_color, monitor_variable
# - assign_task, complete_task
# - get_role_instructions, ask_orchestrator
```

### Test Creating a Worker

Try this in Claude Code or Claude Desktop:

```
Create a test worker in iTerm2 called "TestBot" with the task "Test orchestrator"
```

Claude should:
1. Use the `create_worker` tool
2. Create a new iTerm2 tab
3. Return the worker_id

Then check iTerm2 - you should see a new tab named "TestBot"!

---

## 🔍 Troubleshooting

### Problem: "claude-orchestrator not found"

**Solution:**
```bash
# Verify the file path is correct
ls -la /Users/YOUR_USERNAME/code/claude-iterm-orchestrator/server.js

# Check file is executable
chmod +x /Users/YOUR_USERNAME/code/claude-iterm-orchestrator/server.js

# Verify node works
node /Users/YOUR_USERNAME/code/claude-iterm-orchestrator/server.js
```

### Problem: "Command not found: node"

**Solution:**
```bash
# Find your node path
which node
# Example output: /opt/homebrew/bin/node

# Use the full path in config:
{
  "command": "/opt/homebrew/bin/node",
  "args": ["/Users/YOUR_USERNAME/code/..."]
}
```

### Problem: "iTerm2 Python API not working"

**Solution:**
```bash
# Check Python version
python3 --version

# Install iTerm2 Python module
pip3 install iterm2

# Enable iTerm2 Python API
# Go to: iTerm2 → Preferences → General → Magic
# Check: "Enable Python API"
```

### Problem: "Tools not showing up"

**Checklist:**
1. ✅ Config file saved correctly (valid JSON)
2. ✅ Absolute paths used (not relative)
3. ✅ Claude Code/Desktop restarted completely
4. ✅ No syntax errors in JSON (use `jq` to validate):
   ```bash
   cat ~/.claude.json | jq .
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq .
   ```

### Problem: "Permission denied"

**Solution:**
```bash
# Make scripts executable
cd /path/to/claude-iterm-orchestrator
chmod +x scripts/*.sh
chmod +x server.js
```

---

## 📋 Complete Configuration Examples

### Claude Code (~/.claude.json)

```json
{
  "mcpServers": {
    "claude-orchestrator": {
      "command": "node",
      "args": [
        "/Users/yurygagarin/code/claude-iterm-orchestrator/server.js"
      ]
    },
    "dart-flutter": {
      "command": "dart",
      "args": ["mcp-server"]
    }
  }
}
```

### Claude Desktop (~/Library/Application Support/Claude/claude_desktop_config.json)

```json
{
  "mcpServers": {
    "claude-orchestrator": {
      "command": "node",
      "args": [
        "/Users/yurygagarin/code/claude-iterm-orchestrator/server.js"
      ]
    }
  },
  "preferences": {
    "quickEntryDictationShortcut": "capslock"
  }
}
```

---

## 🎯 Quick Start After Installation

### 1. Basic Usage

```
# In Claude Code or Claude Desktop:

> Create a worker called "BackendDev" with task "Build REST API"

> List all workers

> Send a message to BackendDev: "Start working on /api/users endpoint"

> Read output from BackendDev (last 30 lines)

> Kill worker BackendDev
```

### 2. Orchestrator Mode

```
# First Claude instance becomes orchestrator:

> Get my role instructions

# This tells you if you're orchestrator or worker
# Orchestrator can create workers, assign tasks
# Workers can ask_orchestrator questions
```

### 3. Auto-start Claude CLI

```
> Create a worker with Claude CLI called "Assistant" running in bypass mode

# This creates a worker and automatically starts "claude+" (bypass/NOM mode)
```

---

## 🗺️ Next Steps

- **Read the README:** [README.md](README.md) - Full feature list
- **Check the Roadmap:** [ROADMAP.md](ROADMAP.md) - 14 planned features
- **Testing Guide:** [TESTING.md](TESTING.md) - Development and testing

---

## 🆘 Getting Help

**Issue tracker:** https://github.com/gagarinyury/claude-iterm-orchestrator/issues

**Before opening an issue:**
1. Check the Troubleshooting section above
2. Verify all prerequisites are met
3. Test with the minimal example
4. Include your config file (remove sensitive data)

---

## 📊 Installation Checklist

- [ ] macOS installed
- [ ] Node.js ≥ 18.0.0 installed
- [ ] Python ≥ 3.8.0 installed
- [ ] iTerm2 installed with Python API enabled
- [ ] MCP server installed (npm or source)
- [ ] `~/.claude.json` configured (for Claude Code)
- [ ] `claude_desktop_config.json` configured (for Claude Desktop)
- [ ] Claude Code restarted
- [ ] Claude Desktop restarted
- [ ] Test worker created successfully
- [ ] All 16 tools visible

**If all checked ✅ - you're ready to orchestrate!** 🎉

---

**Last updated:** 2025-01-03
