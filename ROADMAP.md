# 🗺️ Roadmap - Future Features

This document outlines **planned features** and **future improvements** for the Claude iTerm Orchestrator project.

---

## 📊 Current Status (v1.0.0)

✅ **16 tools implemented and tested:**
- Worker lifecycle (4 tools)
- Communication (3 tools)
- Variables (2 tools)
- Advanced monitoring (2 tools)
- Task management (2 tools)
- Orchestrator system (2 tools)
- Claude CLI integration (1 tool)

---

## 🎯 Planned Features

### 🔴 **Priority 1: Interactive User Experience**

#### 1. **show_alert** - Display Alert Dialog
**Status:** 📋 Planned
**Complexity:** ⭐⭐ Medium (15 min)
**iTerm2 API:** `iterm2.Alert`

Show modal alert dialogs to the user from orchestrator or workers.

**Use Cases:**
- Orchestrator asks user: "Approve this plan?"
- Worker requests confirmation: "Delete this file?"
- Critical notifications: "Worker-3 failed!"

**Example:**
```javascript
show_alert({
  title: "Confirm Action",
  message: "Delete 50 files?",
  buttons: ["Yes", "No", "Cancel"]
})
→ Returns: button index (0, 1, 2)
```

**Implementation:**
- Create `scripts/show-alert.sh`
- Use `iterm2.Alert()` with `add_button()` and `async_run()`
- Return selected button index

---

#### 2. **ask_user_input** - Text Input Dialog
**Status:** 📋 Planned
**Complexity:** ⭐⭐ Medium (15 min)
**iTerm2 API:** `iterm2.TextInputAlert`

Request text input from user with a modal dialog.

**Use Cases:**
- Ask for API key: "Enter your OpenAI key"
- Configuration: "Set project name"
- Dynamic parameters: "How many workers to create?"

**Example:**
```javascript
ask_user_input({
  title: "Enter API Key",
  placeholder: "sk-...",
  default_value: ""
})
→ Returns: user input string or null (if cancelled)
```

**Implementation:**
- Create `scripts/ask-user-input.sh`
- Use `iterm2.TextInputAlert()` with placeholder and default
- Handle cancellation (return null)

---

### 🟡 **Priority 2: Advanced Worker Control**

#### 3. **inject_output** - Inject Fake Terminal Output
**Status:** 📋 Planned
**Complexity:** ⭐ Easy (10 min)
**iTerm2 API:** `session.async_inject()`

Insert text into worker's terminal as if it were program output (not user input).

**Use Cases:**
- Simulate API responses for testing
- Pass data between workers without typing
- Debug workers with fake output

**Example:**
```javascript
inject_output({
  worker_id: "worker-123",
  text: "[Worker-456 says]: Backend ready on port 3000\n"
})
```

**Implementation:**
- Create `scripts/inject-output.sh`
- Use `await session.async_inject(text)`
- No Enter key needed (it's output, not input)

---

#### 4. **focus_worker** - Switch Focus to Worker
**Status:** 📋 Planned
**Complexity:** ⭐ Easy (5 min)
**iTerm2 API:** `session.async_activate()`, `window.async_activate()`

Programmatically switch focus to a specific worker's tab.

**Use Cases:**
- Show error to user: focus on failed worker
- Present result: focus on completed worker
- Manual inspection: orchestrator brings worker to front

**Example:**
```javascript
focus_worker({
  worker_id: "worker-123"
})
→ Switches to worker's tab and brings window to front
```

**Implementation:**
- Create `scripts/focus-worker.sh`
- Call `await session.async_activate()` and `await window.async_activate()`

---

#### 5. **restart_worker** - Restart Worker Session
**Status:** 📋 Planned
**Complexity:** ⭐⭐ Medium (10 min)
**iTerm2 API:** `session.async_restart()`

Restart a worker's terminal session (useful for recovery from crashes).

**Use Cases:**
- Automatic recovery: worker hung → restart
- Reset state: worker in bad state → fresh start
- Retry mechanism: failed task → restart and retry

**Example:**
```javascript
restart_worker({
  worker_id: "worker-123"
})
→ Restarts the terminal session
```

**Implementation:**
- Create `scripts/restart-worker.sh`
- Use `await session.async_restart()`
- Preserve worker_id and metadata

---

### 🟢 **Priority 3: Orchestration Enhancements**

#### 6. **broadcast** - Send Message to All Workers
**Status:** 📋 Planned
**Complexity:** ⭐⭐ Medium (20 min)
**iTerm2 API:** `asyncio.gather()` + `session.async_send_text()`

Send the same message to multiple workers simultaneously.

**Use Cases:**
- Emergency stop: "STOP - critical error detected"
- Global update: "New config available - reload"
- Status check: "All workers report progress"

**Example:**
```javascript
broadcast({
  message: "Emergency stop - critical bug detected",
  include_orchestrator: false,  // optional, default: false
  filter_role: "worker"          // optional: only send to workers
})
→ Returns: list of workers who received the message
```

**Implementation:**
- Create `scripts/broadcast.sh`
- Use `asyncio.gather()` to send to all workers in parallel
- Support filtering by role (worker/orchestrator)

---

#### 7. **get_workers_summary** - Aggregate Worker Status
**Status:** 📋 Planned
**Complexity:** ⭐⭐ Medium (20 min)
**iTerm2 API:** Combine `list_workers` with aggregation

Get a high-level summary of all workers' states.

**Use Cases:**
- Dashboard view: "3 idle, 5 working, 1 failed"
- Monitoring: quick health check
- Capacity planning: "2 workers available"

**Example:**
```javascript
get_workers_summary()
→ Returns: {
  total: 10,
  by_status: { idle: 3, working: 5, failed: 1, completed: 1 },
  by_role: { orchestrator: 1, worker: 9 }
}
```

**Implementation:**
- Create `scripts/get-workers-summary.sh`
- Reuse `list-workers.sh` logic
- Add aggregation logic in Python

---

#### 8. **shared_variable** - Global Shared State
**Status:** 📋 Planned
**Complexity:** ⭐⭐⭐ Medium-Hard (30 min)
**iTerm2 API:** Window-level variables or orchestrator storage

Create shared variables accessible by all workers.

**Use Cases:**
- API endpoint: all workers need to know backend URL
- Configuration: shared project settings
- Coordination: "backend_ready" flag for frontend workers

**Example:**
```javascript
set_shared_variable({ key: "backend_url", value: "http://localhost:3000" })
get_shared_variable({ key: "backend_url" })
→ Returns: "http://localhost:3000"
```

**Implementation:**
- Option A: Store in orchestrator session variables
- Option B: Use window-level variables
- Create `scripts/set-shared-variable.sh` and `get-shared-variable.sh`

---

### 🔵 **Priority 4: Visual & Layout Management**

#### 9. **split_worker** - Create Split Pane Worker
**Status:** 📋 Planned
**Complexity:** ⭐⭐⭐ Medium-Hard (30 min)
**iTerm2 API:** `session.async_split_pane()`

Create a worker in a split pane instead of a new tab.

**Use Cases:**
- Side-by-side monitoring: backend | frontend
- Compact layout: 4 workers in 2x2 grid
- Visual grouping: related workers together

**Example:**
```javascript
split_worker({
  parent_worker_id: "worker-123",
  name: "RelatedWorker",
  vertical: true  // or false for horizontal split
})
```

**Implementation:**
- Create `scripts/split-worker.sh`
- Use `await session.async_split_pane(vertical=True)`
- Set up worker metadata in new pane

---

#### 10. **set_worker_profile** - Change Worker Appearance
**Status:** 📋 Planned
**Complexity:** ⭐⭐ Medium (15 min)
**iTerm2 API:** `session.async_set_profile()`

Dynamically change worker's terminal profile (colors, fonts, behavior).

**Use Cases:**
- Visual states: error state → red profile
- Role indicators: orchestrator → blue, workers → default
- Focus management: active worker → highlight profile

**Example:**
```javascript
set_worker_profile({
  worker_id: "worker-123",
  profile_name: "ErrorMode"  // iTerm2 profile name
})
```

**Implementation:**
- Create `scripts/set-worker-profile.sh`
- Use `await session.async_set_profile("ProfileName")`
- Requires pre-configured iTerm2 profiles

---

#### 11. **add_annotation** - Mark Important Lines
**Status:** 📋 Planned
**Complexity:** ⭐⭐⭐ Medium-Hard (25 min)
**iTerm2 API:** `session.async_add_annotation()`

Add visual annotations to specific lines in worker's terminal.

**Use Cases:**
- Highlight errors: annotate error line
- Mark milestones: "Build completed here"
- Navigation: quick jump to important output

**Example:**
```javascript
add_annotation({
  worker_id: "worker-123",
  start_line: 150,
  end_line: 155,
  message: "⚠️ Error occurred here"
})
```

**Implementation:**
- Create `scripts/add-annotation.sh`
- Use `await session.async_add_annotation(start, end, text)`
- Calculate line numbers from screen contents

---

### 🟣 **Priority 5: Advanced Workflows**

#### 12. **save_arrangement** / **restore_arrangement** - Project Snapshots
**Status:** 📋 Planned
**Complexity:** ⭐⭐⭐⭐ Hard (45 min)
**iTerm2 API:** `Arrangement.async_save()` / `async_restore()`

Save and restore complete worker setups (all tabs, positions, states).

**Use Cases:**
- Project templates: "Web project" → 4 workers (backend, frontend, db, tests)
- Session persistence: save work → resume tomorrow
- Quick start: restore complex setup in 1 command

**Example:**
```javascript
save_arrangement({ name: "MyProject" })
restore_arrangement({ name: "MyProject" })
```

**Implementation:**
- Create `scripts/save-arrangement.sh` and `restore-arrangement.sh`
- Use iTerm2 Arrangement API
- May need to re-initialize worker metadata after restore

---

#### 13. **get_selection** - Read Selected Text
**Status:** 📋 Planned
**Complexity:** ⭐⭐ Medium (15 min)
**iTerm2 API:** `session.async_get_selection_text()`

Get text that user has selected in worker's terminal.

**Use Cases:**
- Interactive debugging: user selects error → orchestrator analyzes
- Copy automation: user selects result → save to variable
- Context extraction: user highlights code → send to another worker

**Example:**
```javascript
get_selection({ worker_id: "worker-123" })
→ Returns: selected text or null if nothing selected
```

**Implementation:**
- Create `scripts/get-selection.sh`
- Use `await session.async_get_selection_text(connection)`

---

#### 14. **set_grid_size** - Resize Terminal
**Status:** 📋 Planned
**Complexity:** ⭐ Easy (10 min)
**iTerm2 API:** `session.async_set_grid_size()`

Change worker's terminal dimensions (rows x columns).

**Use Cases:**
- Optimize for logs: more rows
- Wide code view: more columns
- Standardization: all workers same size

**Example:**
```javascript
set_grid_size({
  worker_id: "worker-123",
  columns: 120,
  rows: 40
})
```

**Implementation:**
- Create `scripts/set-grid-size.sh`
- Use `await session.async_set_grid_size(iterm2.Size(cols, rows))`

---

## 📈 Implementation Priority Summary

| Priority | Feature | Complexity | Time | Impact |
|----------|---------|-----------|------|--------|
| 🔴 P1 | show_alert | ⭐⭐ | 15 min | 🔥🔥🔥🔥🔥 |
| 🔴 P1 | ask_user_input | ⭐⭐ | 15 min | 🔥🔥🔥🔥🔥 |
| 🟡 P2 | inject_output | ⭐ | 10 min | 🔥🔥🔥🔥 |
| 🟡 P2 | focus_worker | ⭐ | 5 min | 🔥🔥🔥🔥 |
| 🟡 P2 | restart_worker | ⭐⭐ | 10 min | 🔥🔥🔥 |
| 🟢 P3 | broadcast | ⭐⭐ | 20 min | 🔥🔥🔥 |
| 🟢 P3 | get_workers_summary | ⭐⭐ | 20 min | 🔥🔥🔥🔥 |
| 🟢 P3 | shared_variable | ⭐⭐⭐ | 30 min | 🔥🔥🔥🔥 |
| 🔵 P4 | split_worker | ⭐⭐⭐ | 30 min | 🔥🔥🔥 |
| 🔵 P4 | set_worker_profile | ⭐⭐ | 15 min | 🔥🔥 |
| 🔵 P4 | add_annotation | ⭐⭐⭐ | 25 min | 🔥🔥 |
| 🟣 P5 | save/restore_arrangement | ⭐⭐⭐⭐ | 45 min | 🔥🔥🔥 |
| 🟣 P5 | get_selection | ⭐⭐ | 15 min | 🔥 |
| 🟣 P5 | set_grid_size | ⭐ | 10 min | 🔥 |

**Total estimated time:** ~4-5 hours for all features

---

## 🚀 Quick Wins (< 15 minutes each)

These features provide high value with minimal effort:

1. **focus_worker** (5 min) - Switch to worker tab
2. **inject_output** (10 min) - Insert data into worker terminal
3. **restart_worker** (10 min) - Restart worker session
4. **set_grid_size** (10 min) - Resize terminal

**Combined impact:** Significantly improves orchestrator control and user experience

---

## 🎯 Milestone 1: Interactive UX (v2.0.0)

**Goal:** Make orchestrator interactive with users

**Features:**
- ✅ show_alert
- ✅ ask_user_input
- ✅ focus_worker

**Impact:** Orchestrator can ask for approvals, display notifications, and guide user attention

**Timeline:** ~30 minutes implementation + testing

---

## 🎯 Milestone 2: Advanced Control (v2.1.0)

**Goal:** Enhanced worker management

**Features:**
- ✅ inject_output
- ✅ restart_worker
- ✅ broadcast
- ✅ get_workers_summary

**Impact:** Better automation, recovery, and monitoring

**Timeline:** ~1 hour implementation + testing

---

## 🎯 Milestone 3: Shared State (v2.2.0)

**Goal:** Worker coordination

**Features:**
- ✅ shared_variable (set/get)

**Impact:** Workers can share data without going through orchestrator

**Timeline:** ~30 minutes implementation + testing

---

## 🎯 Milestone 4: Visual & Layout (v3.0.0)

**Goal:** Better visual organization

**Features:**
- ✅ split_worker
- ✅ set_worker_profile
- ✅ add_annotation
- ✅ set_grid_size

**Impact:** Professional multi-worker setup with visual feedback

**Timeline:** ~1.5 hours implementation + testing

---

## 🎯 Milestone 5: Workflows (v3.1.0)

**Goal:** Session persistence and advanced features

**Features:**
- ✅ save_arrangement
- ✅ restore_arrangement
- ✅ get_selection

**Impact:** Save/restore complex setups, interactive text extraction

**Timeline:** ~1.5 hours implementation + testing

---

## 🤔 Features NOT Planned (Rationale)

### ❌ **pause_worker / resume_worker**
**Why not:**
- Pausing = just don't send more tasks (orchestrator controls this)
- Real process pause (SIGSTOP) is dangerous and can break Claude CLI
- Metadata flag "paused" already possible with `set_variable`

### ❌ **get_worker_cpu / get_worker_memory**
**Why not:**
- Already visible in terminal output via iTerm2 status bar
- `read_from_worker` shows CPU/memory markers (💾 🔥 🧠)
- No need for separate tool

---

## 💡 Contributing Ideas

Have ideas for new features? Consider:

1. **Is it iTerm2 API compatible?** - Check [iTerm2 Python API docs](https://iterm2.com/python-api/)
2. **Real use case?** - Describe a concrete scenario where it's needed
3. **Simple implementation?** - Should follow our bash → Python → iTerm2 pattern
4. **Avoid complexity** - Keep the architecture simple

**Open an issue or PR!** 🚀

---

## 📅 Version History

- **v1.0.0** (2025-01-03) - Initial release with 16 tools
- **v2.0.0** (Planned) - Interactive UX milestone
- **v2.1.0** (Planned) - Advanced control milestone
- **v2.2.0** (Planned) - Shared state milestone
- **v3.0.0** (Planned) - Visual & layout milestone
- **v3.1.0** (Planned) - Workflows milestone

---

**Last updated:** 2025-01-03
