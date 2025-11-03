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

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("✅ Simple MCP Server V2 ready! (9 tools registered)");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
