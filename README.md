# 🎭 Claude iTerm Orchestrator

![Tests](https://img.shields.io/badge/tests-7%2F7%20passing-brightgreen)
![Lint](https://img.shields.io/badge/lint-passing-brightgreen)
![Node](https://img.shields.io/badge/node-%E2%89%A518.0.0-brightgreen)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)

**Simple MCP server for managing Claude workers in iTerm2**

Control multiple Claude CLI instances in separate iTerm tabs through a clean MCP interface.

---

## ✨ Features

- 🪟 **Worker Management** - Create/kill workers in iTerm tabs
- 💬 **Communication** - Send commands and read output
- 💾 **Variables** - Store data in worker sessions
- 🤖 **Claude Integration** - Direct communication with Claude CLI
- 🔧 **Simple Architecture** - MCP server → Bash scripts → iTerm2 API

---

## 🚀 Quick Start

### Install
```bash
npm install
```

### Run
```bash
node server.js
```

### Test
```bash
# Create a worker
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "create_worker", "arguments": {"name": "Test", "task": "Demo"}}, "id": 1}' | node server.js

# List workers
echo '{"jsonrpc": "2.0", "method": "tools/call", "params": {"name": "list_workers", "arguments": {}}, "id": 2}' | node server.js
```

---

## 📦 Available Tools (16)

> **🗺️ Future features:** See [ROADMAP.md](ROADMAP.md) for planned features and milestones

### 1️⃣ Worker Lifecycle (4)
- **create_worker** - Create new worker in iTerm tab
- **create_worker_claude** - Create worker and auto-start Claude CLI
- **kill_worker** - Close worker tab
- **list_workers** - List all active workers
- **get_worker_info** - Get detailed worker info

### 2️⃣ Communication (3)
- **send_to_worker** - Send text (no Enter)
- **send_to_claude** - Send text + Enter (for Claude CLI)
- **read_from_worker** - Read terminal output

### 3️⃣ Variables (2)
- **set_variable** - Store data in worker session
- **get_variable** - Retrieve stored data

### 4️⃣ Advanced Monitoring (2)
- **set_tab_color** - Set tab color for visual identification
- **monitor_variable** - Monitor variable changes over time

### 5️⃣ Task Management (2)
- **assign_task** - Assign task to worker with metadata
- **complete_task** - Mark task as completed with result

### 6️⃣ Orchestrator System (2)
- **get_role_instructions** - Get role (orchestrator/worker) and instructions
- **ask_orchestrator** - Send question from worker to orchestrator

---

## 🏗️ Architecture

```
MCP Server (server.js)
  ↓ calls
Bash Scripts (scripts/*.sh)
  ↓ generate
Python Scripts (inline)
  ↓ use
iTerm2 Python API
```

**Why this design?**
- ✅ Minimal code in MCP server (just routing)
- ✅ Scripts are testable independently
- ✅ Easy to add new commands
- ✅ No server restart needed

---

## 📁 Project Structure

```
claude-iterm-orchestrator/
├── server.js              ← MCP server (500 lines)
├── scripts/               ← 16 bash scripts
│   ├── create-worker.sh
│   ├── create-worker-claude.sh
│   ├── send-to-claude-v3.sh
│   ├── read-output.sh
│   ├── set-variable.sh
│   ├── get-variable.sh
│   ├── assign-task.sh
│   ├── complete-task.sh
│   ├── get-role-instructions.sh
│   ├── ask-orchestrator.sh
│   └── ... (6 more)
├── tests/                 ← Test suite
│   └── server.test.js     ← 7 tests (100% passing)
├── biome.json             ← Linter config
├── vitest.config.js       ← Test config
├── package.json
├── README.md              ← Main docs
├── TESTING.md             ← Testing guide
└── ROADMAP.md             ← Future features
```

---

## 🎯 Example: Chat with Claude

```bash
# 1. Create worker
{"jsonrpc": "2.0", "method": "tools/call", "params": {
  "name": "create_worker",
  "arguments": {"name": "Claude", "task": "Chat"}
}, "id": 1}

# 2. Start Claude CLI
{"jsonrpc": "2.0", "method": "tools/call", "params": {
  "name": "send_to_claude",
  "arguments": {"worker_id": "worker-123", "message": "claude"}
}, "id": 2}

# 3. Ask question
{"jsonrpc": "2.0", "method": "tools/call", "params": {
  "name": "send_to_claude",
  "arguments": {"worker_id": "worker-123", "message": "What is 2+2?"}
}, "id": 3}

# 4. Read answer
{"jsonrpc": "2.0", "method": "tools/call", "params": {
  "name": "read_from_worker",
  "arguments": {"worker_id": "worker-123", "lines": 30}
}, "id": 4}
```

---

## 🔧 Requirements

- **Node.js** ≥ 18.0.0
- **Python** ≥ 3.8.0
- **iTerm2** with Python API enabled
- **macOS** (iTerm2 is macOS-only)
- **Claude CLI** with `claude+` alias (recommended for orchestration)

### Setting up `claude+` alias

For orchestration, workers need to run in bypass mode (skip permissions). Add this alias to your shell:

**macOS (Zsh - default):**
```bash
# Add to ~/.zshrc
alias claude+='claude --dangerously-skip-permissions'
```

**macOS (Bash):**
```bash
# Add to ~/.bash_profile or ~/.bashrc
alias claude+='claude --dangerously-skip-permissions'
```

**Linux:**
```bash
# Add to ~/.bashrc (or ~/.bash_aliases on Debian/Ubuntu)
alias claude+='claude --dangerously-skip-permissions'
```

**After adding, reload your shell:**
```bash
# For zsh (macOS default)
source ~/.zshrc

# For bash (Linux / older macOS)
source ~/.bashrc  # or ~/.bash_profile
```

**Verify it works:**
```bash
claude+ --version  # Should work without asking
```

> **Why bypass mode?** Workers need to operate autonomously without blocking on permission prompts. This allows the orchestrator to manage multiple workers efficiently.

> **Note:** Only use bypass mode for trusted orchestrator tasks. For normal interactive use, use `claude` without the alias.

> **Platform compatibility:** This alias syntax works on macOS, Linux, and Unix-like systems using bash or zsh shells.

---

## 🧪 Testing & Development

> **📖 Detailed guide:** See [TESTING.md](TESTING.md) for complete testing documentation

### Quick Start

```bash
# Install dependencies
npm install

# Run all checks (lint + test)
npm run check
```

### Available Commands

| Command | Description |
|---------|-------------|
| `npm test` | Run all tests (7 tests) |
| `npm run test:watch` | Run tests in watch mode |
| `npm run test:ui` | Open Vitest web UI |
| `npm run test:coverage` | Generate coverage report |
| `npm run lint` | Check code style |
| `npm run lint:fix` | Auto-fix code issues |
| `npm run format` | Format code with Biome |
| `npm run check` | Run lint + test together |

### Test Structure

```
tests/
└── server.test.js (7 tests)
    ├── MCP Server V2
    │   ├── should start and respond to initialize
    │   └── should list available tools
    ├── Script Validation
    │   ├── should have all required bash scripts
    │   └── should have executable permissions
    └── Configuration Files
        ├── should have valid package.json
        ├── should have valid biome.json
        └── should have valid vitest.config.js
```

### What's Being Tested

1. **MCP Protocol** - Server initialization and tools listing
2. **Script Existence** - All 9 bash scripts are present
3. **Script Permissions** - Scripts are executable
4. **Configuration** - Valid package.json, biome.json, vitest config

### Manual Testing Bash Scripts

Test individual scripts directly:

```bash
# Test variables
./test-variables-simple.sh

# Test MCP server with variables
./test-variables-mcp.sh

# Full test: Worker → Claude → Question → Answer
./test-full-claude-mcp.sh
```

### Testing Tools

- **Vitest 4.0** - Fast test framework with HMR
- **Biome 2.3** - Ultra-fast linter + formatter (15-25x faster than ESLint)

### Coverage

Run coverage report:

```bash
npm run test:coverage
```

This will generate:
- Console output with coverage stats
- HTML report in `coverage/` directory
- JSON report for CI integration

### CI/CD Integration

For continuous integration, add to your workflow:

```yaml
- name: Run tests
  run: npm run check
```

This runs both linting and tests in a single command.

---

## 📝 License

MIT

---

## 🙏 Built With

- [Model Context Protocol SDK](https://github.com/modelcontextprotocol/typescript-sdk)
- [iTerm2 Python API](https://iterm2.com/python-api/)
- [Zod](https://github.com/colinhacks/zod) for schema validation
- [Vitest](https://vitest.dev/) for testing
- [Biome](https://biomejs.dev/) for linting & formatting

---

## 📊 Project Status

| Metric | Status |
|--------|--------|
| **Tests** | ✅ 7/7 passing (100%) |
| **Linting** | ✅ All checks passed |
| **Tools** | ✅ 16/16 working |
| **Coverage** | MCP Protocol, Scripts, Config |
| **Platform** | macOS (iTerm2) |

**Last verified:** 2025-01-03

---

## 🗺️ Roadmap

See [ROADMAP.md](ROADMAP.md) for:
- 14 planned features
- Implementation priorities
- Future milestones (v2.0 - v3.1)
- Interactive UX, advanced control, visual management
