# 🎭 I built a system where Claude agents talk to each other and make decisions together

## What is this?

An MCP server that lets you create multiple Claude CLI instances in iTerm2 tabs. But here's the cool part: **they can communicate with each other via broadcast**.

Think of it like a committee of AI specialists that discuss, argue, and coordinate autonomously while you observe and guide.

## Quick Demo

```javascript
// Create a design team
create_worker_claude({name: "Researcher", role: "researcher"})
create_worker_claude({name: "Architect", role: "architect"})
create_worker_claude({name: "Coder", role: "coder"})
create_worker_claude({name: "Tester", role: "tester"})

// Let them know who's in the room
announce_network()

// Start the discussion
broadcast("Task: Design authentication API. Discuss approach.")

// Now they talk autonomously:
// Researcher: "I researched OAuth 2.0 and JWT. Recommend JWT tokens..."
// Architect: "Agreed. I propose: Access tokens (15min), Refresh tokens (7 days)..."
// Coder: "I can implement with Node.js. Question: Do we need social login?"
// Tester: "I'll prepare test scenarios for token expiration and refresh flow..."
```

You just observe and guide when needed.

## Why This Is Interesting

**Multi-agent discussions aren't new**, but most implementations are:
- Fully automated (no human guidance)
- API-based (expensive, rate-limited)
- Framework-specific (AutoGen, LangChain, etc.)

**This is different:**
- ✅ Uses your local Claude CLI (free after API subscription)
- ✅ Human orchestrator observes and guides discussions
- ✅ Workers use MCP tools, file access, everything Claude Code can do
- ✅ Simple architecture: MCP → Bash → iTerm2 API
- ✅ Works on your machine, no cloud dependencies

## Real Use Cases I'm Exploring

1. **Design reviews** - Architect, Coder, Security Auditor discuss system design
2. **Code reviews** - Multiple reviewers with different focuses
3. **Research synthesis** - Multiple researchers tackle different angles
4. **Parallel development** - 3 coders work on different modules simultaneously

## Current Features (18 Tools)

- **Worker management**: Create/kill workers with specialized roles
- **Broadcast**: Any worker can talk to everyone
- **Network awareness**: Workers know who else is available
- **Direct communication**: Orchestrator → Worker or Worker → Worker
- **9 pre-built roles**: researcher, coder, tester, analyst, architect, debugger, docs, writer, security

## Technical Details

- Platform: macOS (iTerm2 only)
- Architecture: Node.js MCP server → Bash scripts → iTerm2 Python API
- Workers run `claude+` (bypass mode) for autonomous operation
- 18 MCP tools, 17 bash scripts, ~700 lines of code total
- MIT licensed

## What I'd Love Help With

This started as an experiment, but it's actually pretty useful. I'd love to:

1. **Hear your ideas**: What workflows would you try with this?
2. **Get feedback**: What's missing? What's confusing?
3. **Collaborate**: Want to add features? Improve the architecture?
4. **Learn use cases**: How would you use multi-agent discussions?

Some ideas I'm considering:
- Visual dashboard showing worker states
- Support for other terminals (Warp, Kitty?)
- Worker-to-worker direct messaging (not just broadcast)
- Saving/loading team configurations
- Integration with other AI CLIs (Gemini, GPT CLI, etc.)

## Try It

**GitHub**: [gagarinyury/claude-iterm-orchestrator](https://github.com/gagarinyury/claude-iterm-orchestrator)

**Requirements**: macOS, iTerm2, Node.js, Python, Claude CLI

**Setup**: 5 minutes
```bash
git clone https://github.com/gagarinyury/claude-iterm-orchestrator.git
cd claude-iterm-orchestrator
npm install
# Add to Claude config, restart Claude Code
```

Full setup guide in README.

## Discussion

**Have you tried multi-agent systems?** What worked? What didn't?

**Would you use something like this?** What's your ideal workflow?

**Want to contribute?** Open an issue or PR. Or just share ideas here.

I'm genuinely curious what the community thinks. This could be something cool, or just a neat experiment. Either way, wanted to share!

---

*P.S. - Yes, I used Claude to help build this. Meta, I know.*
