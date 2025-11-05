#!/usr/bin/env node

/**
 * Simple MCP Server V2 - Routes commands to bash scripts
 * Uses McpServer API with registerTool
 */

import { exec } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const execPromise = promisify(exec);
const __dirname = dirname(fileURLToPath(import.meta.url));
const scriptsDir = join(__dirname, "scripts");

console.error("🚀 Simple MCP Server V2 Starting...");
console.error(`📁 Scripts directory: ${scriptsDir}`);

// Helper: Execute a script and return result
async function runScript(scriptName, args = []) {
  const scriptPath = join(scriptsDir, scriptName);
  const command = `bash "${scriptPath}" ${args.join(" ")}`;

  console.error(`🔧 Executing: ${command}`);

  try {
    const { stdout, stderr } = await execPromise(command, {
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
      "Create a new worker in iTerm2 tab and auto-start Claude CLI (default: claude+ bypass mode)",
    inputSchema: {
      name: z.string().describe("Worker name"),
      task: z.string().optional().describe("Task description"),
      claude_command: z
        .string()
        .optional()
        .describe(
          "Claude command to run: 'claude' or 'claude+' (default: 'claude+')"
        ),
    },
  },
  async ({ name, task, claude_command }) => {
    const result = await runScript("create-worker-claude.sh", [
      name,
      task || "No task",
      claude_command || "claude+",
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
    const escapedMessage = message.replace(/'/g, "'\\''");
    const result = await runScript("send-command.sh", [
      worker_id,
      `'${escapedMessage}'`,
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
    const escapedMessage = message.replace(/'/g, "'\\''");
    const result = await runScript("send-to-claude-v3.sh", [
      worker_id,
      `'${escapedMessage}'`,
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
    const escapedResult = (result || "Task completed successfully").replace(
      /'/g,
      "'\\''"
    );
    const scriptResult = await runScript("complete-task.sh", [
      worker_id,
      task_id,
      `'${escapedResult}'`,
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
    const escapedQuestion = question.replace(/'/g, "'\\''");
    const result = await runScript("ask-orchestrator.sh", [
      worker_id,
      `'${escapedQuestion}'`,
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
  "check_rate_limit",
  {
    description: "Check current rate limit status to avoid hitting Claude Pro/Max limits",
    inputSchema: {
      worker_id: z.string().optional().describe("Worker ID (for tracking)"),
    },
  },
  async ({ worker_id }) => {
    const result = await runScript("rate-limiter.sh", [
      "status",
      worker_id || "unknown",
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ check_rate_limit\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "get_queue_status",
  {
    description: "Get status of the request queue",
    inputSchema: {},
  },
  async () => {
    const result = await runScript("queue-manager.sh", ["status"]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ get_queue_status\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "smart_restart_worker",
  {
    description: "Gracefully restart a worker with context preservation (useful on rate limit errors)",
    inputSchema: {
      worker_id: z.string().describe("Worker ID to restart"),
      reason: z
        .string()
        .optional()
        .describe("Reason for restart (default: 'manual_restart')"),
    },
  },
  async ({ worker_id, reason }) => {
    const result = await runScript("smart-restart.sh", [
      worker_id,
      reason || "manual_restart",
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ smart_restart_worker\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "show_dashboard",
  {
    description: "Show visual dashboard with workers, rate limits, token usage, and cost savings",
    inputSchema: {
      subscription_type: z
        .string()
        .optional()
        .describe("Subscription type: 'pro' or 'max' (default: 'pro')"),
    },
  },
  async ({ subscription_type }) => {
    const result = await runScript("show-dashboard.sh", [
      subscription_type || "pro",
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ show_dashboard\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "estimate_tokens",
  {
    description: "Estimate token usage for a period (today, week, month)",
    inputSchema: {
      period: z
        .string()
        .optional()
        .describe("Period: 'today', 'week', 'month' (default: 'today')"),
    },
  },
  async ({ period }) => {
    const result = await runScript("estimate-tokens.sh", [period || "today"]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ estimate_tokens\n\n${result.output}`
            : `❌ Failed\n\n${result.error}`,
        },
      ],
    };
  }
);

server.registerTool(
  "cost_estimator",
  {
    description: "Calculate cost savings vs API usage",
    inputSchema: {
      period: z
        .string()
        .optional()
        .describe("Period: 'today', 'week', 'month' (default: 'today')"),
      subscription_type: z
        .string()
        .optional()
        .describe("Subscription: 'pro' or 'max' (default: 'pro')"),
    },
  },
  async ({ period, subscription_type }) => {
    const result = await runScript("cost-estimator.sh", [
      period || "today",
      subscription_type || "pro",
    ]);
    return {
      content: [
        {
          type: "text",
          text: result.success
            ? `✅ cost_estimator\n\n${result.output}`
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
  console.error("✅ Simple MCP Server V2 ready! (22 tools registered)");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
