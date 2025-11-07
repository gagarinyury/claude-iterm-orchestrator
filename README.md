# 🎭 Claude iTerm Orchestrator

![Tests](https://img.shields.io/badge/tests-7%2F7%20passing-brightgreen)
![Lint](https://img.shields.io/badge/lint-passing-brightgreen)
![Node](https://img.shields.io/badge/node-%E2%89%A518.0.0-brightgreen)
![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)
![License](https://img.shields.io/badge/license-MIT-blue)

> **MCP server for orchestrating multiple Claude AI workers in iTerm2 tabs**

Control multiple Claude CLI instances through a clean [Model Context Protocol](https://modelcontextprotocol.io/) interface. Create specialized AI workers (researcher, coder, tester, etc.) that work autonomously in separate iTerm tabs, managed by a central orchestrator.

**Perfect for:**
- 🤖 Multi-agent AI workflows
- 🔬 Research and data gathering
- 💻 Parallel code development
- 🧪 Automated testing scenarios
- 📊 Complex task orchestration

---

## ✨ Features

- 🪟 **Worker Management** - Create/kill workers in iTerm tabs
- 📡 **Broadcast Communication** - Workers talk to each other, orchestrator observes
- 💬 **Direct Communication** - Send commands and read output
- 💾 **Variables** - Store data in worker sessions
- 🎭 **AI Roles** - 9 pre-built specialist roles (researcher, coder, tester, etc.)
- 🤖 **Claude Integration** - Direct communication with Claude CLI
- 🔧 **Simple Architecture** - MCP server → Bash scripts → iTerm2 API

---

## 💡 Quick Example

```javascript
// Create a researcher worker with automatic role
await mcp.create_worker_claude({
  name: "Research-Agent",
  task: "Research MCP protocol",
  role: "researcher"  // Auto-applies researcher system prompt
});

// Create a coder worker
await mcp.create_worker_claude({
  name: "Code-Agent",
  task: "Implement auth module",
  role: "coder"
});

// After creating all workers, announce the network
await mcp.announce_network();
// → All workers receive: "[NETWORK] Active participants: Researcher-Agent (researcher), Code-Agent (coder), orchestrator-123 (orchestrator)"

// Orchestrator broadcasts to start discussion
await mcp.broadcast({
  from_worker_id: "orchestrator-123",
  message: "Task: Design authentication API. Speak in order: Researcher → Coder"
});

// Workers broadcast in turn
// researcher → broadcast("I found OAuth 2.0 is best practice")
// coder → broadcast("I can implement JWT tokens")
// Workers discuss, argue, and coordinate autonomously!
```

**Result:** Multi-agent discussion where workers communicate freely, orchestrator observes and guides.

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

## 📦 Available Tools (18)

### 1️⃣ Worker Lifecycle (4)
- **create_worker** - Create new worker in iTerm tab
- **create_worker_claude** - Create worker and auto-start Claude CLI
- **kill_worker** - Close worker tab
- **list_workers** - List all active workers
- **get_worker_info** - Get detailed worker info

### 2️⃣ Communication (5)
- **send_to_worker** - Send text (no Enter)
- **send_to_claude** - Send text + Enter (for Claude CLI)
- **read_from_worker** - Read terminal output
- **broadcast** - Send message to all workers and orchestrator (everyone can use)
- **announce_network** - Broadcast network roster to all participants (orchestrator use)

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
├── server.js              ← MCP server (552 lines)
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
├── roles/                 ← AI worker roles
│   └── prompts.json       ← System prompts for 9 roles
├── tests/                 ← Test suite
│   └── server.test.js     ← 7 tests (100% passing)
├── biome.json             ← Linter config
├── vitest.config.js       ← Test config
├── package.json
├── README.md              ← Main docs
├── ROLE_PROMPTS.md        ← Role system guide
└── INSTALLATION.md        ← Setup instructions
```

---

## 🎭 AI Worker Roles

Create specialized AI workers with **ready-to-use system prompts** for different roles:

| Role | Description | Use Case |
|------|-------------|----------|
| 🔵 **Researcher** | Information gathering, web search | Research topics, gather data |
| 🟢 **Coder** | Software development | Write code, implement features |
| 🟣 **Tester** | QA, testing, validation | Test code, find bugs |
| 🟠 **Analyst** | Data analysis, insights | Analyze data, provide recommendations |
| 🎨 **Writer** | Content creation | Write docs, articles, copy |
| 🏗️ **Architect** | System design | Design architecture, plan systems |
| 🔍 **Debugger** | Problem diagnosis | Debug issues, troubleshoot |
| 📚 **Docs Specialist** | Technical writing | Write documentation |
| 🛡️ **Security Auditor** | Security assessment | Find vulnerabilities |
| 💡 **Custom** | Your own role | Create custom prompts |

**📖 See [ROLE_PROMPTS.md](ROLE_PROMPTS.md) for complete system prompts!**

### Quick Example: Create a Researcher (Automatic Role)

```javascript
// ⚡ NEW: Role is applied AUTOMATICALLY!
create_worker_claude({
  name: "Researcher-Alpha",
  task: "Research MCP protocol",
  role: "researcher"  // ← Role prompt auto-applied!
})
// Worker is ready with researcher role immediately!

// Just read the results
read_from_worker({
  worker_id: "worker-xxx",
  lines: 100
})
```

**What happens automatically:**
1. ✅ iTerm tab created
2. ✅ Claude CLI started
3. ✅ **Researcher role prompt sent automatically**
4. ✅ Worker ready to work as researcher!

**No manual prompt sending needed!** 🎉

### Available Roles:
- `researcher`, `coder`, `tester`, `analyst`, `writer`, `architect`, `debugger`, `docs`, `security`

### Create Different Roles:

```javascript
// Coder
create_worker_claude({
  name: "Coder-Beta",
  task: "Implement auth module",
  role: "coder"
})

// Tester
create_worker_claude({
  name: "Tester-Gamma",
  task: "Test API endpoints",
  role: "tester"
})

// Security Auditor
create_worker_claude({
  name: "Security-Delta",
  task: "Audit codebase",
  role: "security"
})
```

---

## 📚 How to Use: Multi-Agent Discussion

### Scenario: Design Team Discussion

Create a team of AI specialists that discuss and design an authentication system together.

#### Step 1: Create Workers with Roles

```javascript
// Orchestrator creates specialized workers
await mcp.create_worker_claude({
  name: "Research-Lead",
  task: "Research best practices",
  role: "researcher"
});

await mcp.create_worker_claude({
  name: "System-Architect",
  task: "Design system architecture",
  role: "architect"
});

await mcp.create_worker_claude({
  name: "Dev-Lead",
  task: "Implement features",
  role: "coder"
});

await mcp.create_worker_claude({
  name: "QA-Lead",
  task: "Test and validate",
  role: "tester"
});
```

#### Step 2: Announce Network

```javascript
// Let everyone know who is in the team
await mcp.announce_network();

// All workers receive:
// "[NETWORK] Active participants: Research-Lead (researcher), System-Architect (architect),
//  Dev-Lead (coder), QA-Lead (tester), orchestrator-123 (orchestrator)"
```

#### Step 3: Start Discussion

```javascript
// Orchestrator initiates and sets order
await mcp.broadcast({
  from_worker_id: "orchestrator-123",
  message: "Task: Design authentication system for our API. Discuss approach. Speak in order: Research-Lead → System-Architect → Dev-Lead → QA-Lead"
});
```

#### Step 4: Workers Discuss Autonomously

Workers now communicate via broadcast:

```
Research-Lead: broadcast("I researched OAuth 2.0 and JWT. Recommend JWT tokens with refresh tokens for security.")

System-Architect: broadcast("Agreed on JWT. I propose: Access tokens (15min), Refresh tokens (7 days), Redis for token blacklist.")

Dev-Lead: broadcast("I can implement this with Node.js + jsonwebtoken library. Will need 2-3 days. Question: Do we need social login?")

QA-Lead: broadcast("I'll prepare test scenarios: token expiration, refresh flow, invalid tokens. Need clarification on rate limiting.")

Research-Lead: broadcast("Regarding social login - yes, recommend OAuth 2.0 with Google and GitHub providers.")

System-Architect: broadcast("Rate limiting: 5 requests per minute for auth endpoints. Store in Redis.")
```

#### Step 5: Orchestrator Guides

```javascript
// Orchestrator observes discussion via read_from_worker
// Then guides decision:
await mcp.broadcast({
  from_worker_id: "orchestrator-123",
  message: "Good discussion! Decision: Implement JWT with refresh tokens + social login (Google, GitHub). Dev-Lead start coding, QA-Lead prepare tests. Deadline: 3 days."
});
```

#### Step 6: Read Worker Outputs

```javascript
// Orchestrator monitors progress
await mcp.read_from_worker({
  worker_id: "worker-dev-lead-id",
  lines: 50
});
```

### Result

You get an autonomous team that:
- ✅ Discusses approaches
- ✅ Asks clarifying questions
- ✅ Makes technical decisions together
- ✅ Coordinates work
- ✅ Orchestrator observes and guides when needed

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
2. **Script Existence** - All 16 bash scripts are present
3. **Script Permissions** - Scripts are executable
4. **Configuration** - Valid package.json, biome.json, vitest config

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
| **Tools** | ✅ 18/18 working |
| **Coverage** | MCP Protocol, Scripts, Config |
| **Platform** | macOS (iTerm2) |

**Last verified:** 2025-01-03

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

## ⚠️ Known Issues

### iTerm2 Display Artifacts

**Problem:** When Claude Code outputs text with progress indicators (e.g., "Pollinating...", "Hatching..."), iTerm2 may display visual artifacts - text appears duplicated or repeated on screen.

**Cause:** iTerm2 rendering issue when handling rapid screen updates with Unicode characters and progress animations.

**Impact:** Visual only - commands execute correctly and workers function properly despite the display glitches. The duplicated text is just a display bug, not actual repeated execution.

**Status:** This is an inherent iTerm2 terminal emulation issue and cannot be resolved at the MCP server level. If you know how to fix this, please open an issue or PR!

---

## 📬 Contact

- **Author**: [@gagarinyury](https://github.com/gagarinyury)
- **GitHub Issues**: [Report bugs or request features](https://github.com/gagarinyury/claude-iterm-orchestrator/issues)
- **GitHub Repository**: [gagarinyury/claude-iterm-orchestrator](https://github.com/gagarinyury/claude-iterm-orchestrator)
