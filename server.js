#!/usr/bin/env node

/**
 * Simple MCP Server V2 - Routes commands to bash scripts
 * Uses McpServer API with registerTool
 */

import { execFile } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const execFilePromise = promisify(execFile);
const __dirname = dirname(fileURLToPath(import.meta.url));
const scriptsDir = join(__dirname, "scripts");

console.error("🚀 Simple MCP Server V2 Starting...");
console.error(`📁 Scripts directory: ${scriptsDir}`);

// Helper: Execute a script and return result
async function runScript(scriptName, args = []) {
  const scriptPath = join(scriptsDir, scriptName);

  console.error(`🔧 Executing: bash ${scriptPath} ${args.join(" ")}`);

  try {
    const { stdout, stderr } = await execFilePromise('bash', [scriptPath, ...args], {
      timeout: 30000,
      maxBuffer: 1024 * 1024,
    });

    if (stderr) {
      console.error(`⚠️  stderr: ${stderr}`);
    }

    return { success: true, output: stdout.trim() };
  } catch (error) {
    console.error(`❌ Script error: ${error.message}`);
    return { success: false, error: error.message };
  }
}

// Helper: Get current session's worker_id from iTerm
async function getCurrentWorkerId() {
  try {
    const result = await runScript("get-current-worker-id.sh", []);

    if (result.success) {
      const data = JSON.parse(result.output);
      return data.worker_id || null;
    }
  } catch (e) {
    console.error(`⚠️  Could not get current worker_id: ${e.message}`);
  }

  return null;
}

// Helper: Ensure current session is registered as orchestrator
async function ensureOrchestratorRegistered() {
  let currentId = await getCurrentWorkerId();

  // If no worker_id exists, we need to initialize as orchestrator
  if (!currentId) {
    const orchestratorId = `orchestrator-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
    console.error(`🎭 No worker_id found. Registering as orchestrator: ${orchestratorId}`);

    // Call get_role_instructions to register
    const result = await runScript("get-role-instructions.sh", [orchestratorId]);

    if (result.success) {
      console.error(`✅ Registered as orchestrator: ${orchestratorId}`);
      return orchestratorId;
    } else {
      console.error(`❌ Failed to register orchestrator: ${result.error}`);
      return null;
    }
  }

  console.error(`ℹ️  Already registered with worker_id: ${currentId}`);
  return currentId;
}

// Create MCP server
const server = new McpServer({
  name: "simple-orchestrator",
  version: "2.0.0",
});

// Register all tools
server.registerTool(
  "create_worker",
  {
    description: "Create a new worker in iTerm2 tab",
    inputSchema: {
      name: z.string().describe("Worker name"),
      task: z.string().optional().describe("Task description"),
    },
  },
  async ({ name, task }) => {
    const result = await runScript("create-worker.sh", [
      name,
      task || "No task",
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ create_worker\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "create_worker_claude",
  {
    description:
      "Create a new worker in iTerm2 tab and auto-start Claude CLI with optional role. Role prompt will be automatically applied if specified.",
    inputSchema: {
      name: z.string().describe("Worker name"),
      task: z.string().optional().describe("Task description"),
      claude_command: z
        .string()
        .optional()
        .describe(
          "Claude command to run: 'claude' or 'claude+' (default: 'claude+')"
        ),
      role: z
        .enum(["researcher", "coder", "tester", "analyst", "writer", "architect", "debugger", "docs", "security"])
        .optional()
        .describe(
          "Optional role: researcher, coder, tester, analyst, writer, architect, debugger, docs, security. Role prompt will be auto-applied."
        ),
    },
  },
  async ({ name, task, claude_command, role }) => {
    // Automatically register as orchestrator if needed
    const parentId = await ensureOrchestratorRegistered();

    const result = await runScript("create-worker-claude.sh", [
      name,
      task || "No task",
      claude_command || "claude+",
      parentId || "",
      role || "",  // Pass role to script
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ create_worker_claude\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "send_to_worker",
  {
    description:
      "Send command to a worker (no auto-enter, use send_to_claude for that)",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      message: z.string().describe("Message/command to send"),
    },
  },
  async ({ worker_id, message }) => {
    const result = await runScript("send-command.sh", [
      worker_id,
      message,
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ send_to_worker\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "send_to_claude",
  {
    description: "Send message to Claude CLI (auto-presses Enter)",
    inputSchema: {
      worker_id: z.string().describe("Worker ID where Claude is running"),
      message: z.string().describe("Message/question to send to Claude"),
    },
  },
  async ({ worker_id, message }) => {
    const result = await runScript("send-to-claude-v3.sh", [
      worker_id,
      message,
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ send_to_claude\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "read_from_worker",
  {
    description: "Read output from a worker's terminal",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      lines: z
        .number()
        .optional()
        .describe("Number of lines to read (default: 20)"),
    },
  },
  async ({ worker_id, lines }) => {
    const result = await runScript("read-output.sh", [worker_id, lines || 20]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ read_from_worker\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "list_workers",
  {
    description: "List all active workers",
  },
  async () => {
    const result = await runScript("list-workers.sh");
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ list_workers\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "kill_worker",
  {
    description: "Kill a worker (close its iTerm tab)",
    inputSchema: {
      worker_id: z.string().describe("Worker ID to kill"),
    },
  },
  async ({ worker_id }) => {
    const result = await runScript("kill-worker.sh", [worker_id]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ kill_worker\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "get_worker_info",
  {
    description: "Get detailed information about a worker",
    inputSchema: {
      worker_id: z.string().describe("Worker ID to query"),
    },
  },
  async ({ worker_id }) => {
    const result = await runScript("get-worker-info.sh", [worker_id]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ get_worker_info\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "set_variable",
  {
    description: "Set a custom variable for a worker",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      key: z.string().describe("Variable name"),
      value: z.string().describe("Variable value"),
    },
  },
  async ({ worker_id, key, value }) => {
    const result = await runScript("set-variable.sh", [worker_id, key, value]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ set_variable\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "get_variable",
  {
    description: "Get a variable value from a worker",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      key: z.string().describe("Variable name"),
    },
  },
  async ({ worker_id, key }) => {
    const result = await runScript("get-variable.sh", [worker_id, key]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ get_variable\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "set_tab_color",
  {
    description:
      "Set tab color for a worker (supports: red, green, blue, yellow, cyan, magenta, orange, purple, pink, gray, white, black, or rgb(r,g,b))",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      color: z
        .string()
        .describe("Color name or RGB format (e.g., 'red' or 'rgb(255,0,0)')"),
    },
  },
  async ({ worker_id, color }) => {
    const result = await runScript("set-tab-color.sh", [worker_id, color]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ set_tab_color\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "monitor_variable",
  {
    description:
      "Monitor a variable for changes in a worker for specified duration",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      key: z.string().describe("Variable name to monitor"),
      duration: z
        .number()
        .optional()
        .describe("Duration in seconds (default: 10)"),
    },
  },
  async ({ worker_id, key, duration }) => {
    const result = await runScript("monitor-variable.sh", [
      worker_id,
      key,
      duration || 10,
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ monitor_variable\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "assign_task",
  {
    description: "Assign a task to a worker",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      task_id: z.string().describe("Unique task identifier"),
      task_description: z.string().describe("Task description"),
    },
  },
  async ({ worker_id, task_id, task_description }) => {
    const result = await runScript("assign-task.sh", [
      worker_id,
      task_id,
      task_description,
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ assign_task\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "complete_task",
  {
    description: "Mark a task as completed for a worker",
    inputSchema: {
      worker_id: z.string().describe("Worker ID"),
      task_id: z.string().describe("Task identifier to complete"),
      result: z
        .string()
        .optional()
        .describe(
          "Task result or outcome (default: 'Task completed successfully')"
        ),
    },
  },
  async ({ worker_id, task_id, result }) => {
    const scriptResult = await runScript("complete-task.sh", [
      worker_id,
      task_id,
      result || "Task completed successfully",
    ]);
    return {
      content: [
        {
          type: "text",
          text: scriptResult.success
            ? `✅ complete_task\n\n${scriptResult.output}`
            : `❌ Failed\n\n${scriptResult.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "get_role_instructions",
  {
    description:
      "Get role (orchestrator/worker) and instructions for current Claude instance. Call this first when starting!",
    inputSchema: {
      my_worker_id: z
        .string()
        .describe("Your worker ID (from create_worker result or environment)"),
    },
  },
  async ({ my_worker_id }) => {
    const result = await runScript("get-role-instructions.sh", [my_worker_id]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ get_role_instructions\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "ask_orchestrator",
  {
    description:
      "Send a question to the orchestrator (only for workers). Orchestrator will see your message in their terminal.",
    inputSchema: {
      worker_id: z.string().describe("Your worker ID"),
      question: z.string().describe("Question to ask the orchestrator"),
    },
  },
  async ({ worker_id, question }) => {
    const result = await runScript("ask-orchestrator.sh", [
      worker_id,
      question,
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ ask_orchestrator\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "broadcast",
  {
    description:
      "Broadcast message to all workers and orchestrator. Available to everyone - orchestrator can broadcast to workers, workers can broadcast to each other and orchestrator.",
    inputSchema: {
      from_worker_id: z.string().describe("Your worker ID (sender)"),
      message: z.string().describe("Message to broadcast to everyone"),
    },
  },
  async ({ from_worker_id, message }) => {
    const result = await runScript("broadcast.sh", [
      from_worker_id,
      message,
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ broadcast\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("✅ Simple MCP Server V2 ready! (17 tools registered)");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
