import { spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { afterEach, beforeEach, describe, expect, it } from "vitest";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serverPath = join(__dirname, "..", "server.js");

describe("MCP Server V2", () => {
  let serverProcess;
  let _serverInput;
  let serverOutput = "";

  beforeEach(() => {
    serverOutput = "";
  });

  afterEach(() => {
    if (serverProcess) {
      serverProcess.kill();
      serverProcess = null;
    }
  });

  it("should start and respond to initialize", async () => {
    return new Promise((resolve, reject) => {
      serverProcess = spawn("node", [serverPath]);
      let timeout;

      serverProcess.stdout.on("data", (data) => {
        serverOutput += data.toString();
        // Check if we got a response
        if (serverOutput.includes("result") || serverOutput.includes("error")) {
          clearTimeout(timeout);
          try {
            expect(serverOutput).toContain("result");
            resolve();
          } catch (err) {
            reject(err);
          }
        }
      });

      serverProcess.stderr.on("data", (data) => {
        const msg = data.toString();
        // Wait for server ready message
        if (msg.includes("ready")) {
          // Send initialize request after server is ready
          const initRequest = {
            jsonrpc: "2.0",
            method: "initialize",
            params: {
              protocolVersion: "2024-11-05",
              capabilities: {},
              clientInfo: {
                name: "test-client",
                version: "1.0.0",
              },
            },
            id: 1,
          };

          serverProcess.stdin.write(`${JSON.stringify(initRequest)}\n`);

          // Set timeout for response
          timeout = setTimeout(() => {
            reject(new Error("Timeout waiting for server response"));
          }, 3000);
        }
      });

      serverProcess.on("error", (err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });
  }, 5000);

  it("should list available tools", async () => {
    return new Promise((resolve, reject) => {
      serverProcess = spawn("node", [serverPath]);
      let toolsResponse = "";
      let timeout;

      serverProcess.stdout.on("data", (data) => {
        toolsResponse += data.toString();
        // Check if we got tools list response
        if (
          toolsResponse.includes("create_worker") ||
          toolsResponse.includes("tools")
        ) {
          clearTimeout(timeout);
          try {
            expect(toolsResponse).toContain("create_worker");
            expect(toolsResponse).toContain("send_to_worker");
            expect(toolsResponse).toContain("send_to_claude");
            expect(toolsResponse).toContain("read_from_worker");
            expect(toolsResponse).toContain("list_workers");
            expect(toolsResponse).toContain("kill_worker");
            expect(toolsResponse).toContain("get_worker_info");
            expect(toolsResponse).toContain("set_variable");
            expect(toolsResponse).toContain("get_variable");
            resolve();
          } catch (err) {
            reject(err);
          }
        }
      });

      serverProcess.stderr.on("data", (data) => {
        const msg = data.toString();
        // Wait for server ready message
        if (msg.includes("ready")) {
          const listToolsRequest = {
            jsonrpc: "2.0",
            method: "tools/list",
            id: 1,
          };

          serverProcess.stdin.write(`${JSON.stringify(listToolsRequest)}\n`);

          // Set timeout for response
          timeout = setTimeout(() => {
            reject(new Error("Timeout waiting for tools list response"));
          }, 3000);
        }
      });

      serverProcess.on("error", (err) => {
        clearTimeout(timeout);
        reject(err);
      });
    });
  }, 5000);
});

describe("Script Validation", () => {
  it("should have all required bash scripts", async () => {
    const fs = await import("node:fs/promises");
    const { join } = await import("node:path");

    const scriptsDir = "scripts";
    const requiredScripts = [
      "create-worker.sh",
      "send-command.sh",
      "send-to-claude-v3.sh",
      "read-output.sh",
      "list-workers.sh",
      "kill-worker.sh",
      "get-worker-info.sh",
      "set-variable.sh",
      "get-variable.sh",
    ];

    for (const script of requiredScripts) {
      const scriptPath = join(scriptsDir, script);
      const exists = await fs
        .access(scriptPath)
        .then(() => true)
        .catch(() => false);
      expect(exists).toBe(true);
    }
  });

  it("should have executable permissions on bash scripts", async () => {
    const fs = await import("node:fs/promises");
    const { join } = await import("node:path");

    const scriptsDir = "scripts";
    const scripts = ["create-worker.sh", "send-command.sh", "read-output.sh"];

    for (const script of scripts) {
      const scriptPath = join(scriptsDir, script);
      const stats = await fs.stat(scriptPath);
      // Check if file has execute permission (user, group, or other)
      const hasExecute = (stats.mode & 0o111) !== 0;
      expect(hasExecute).toBe(true);
    }
  });
});

describe("Configuration Files", () => {
  it("should have valid package.json", async () => {
    const fs = await import("node:fs/promises");
    const packageJson = JSON.parse(await fs.readFile("package.json", "utf-8"));

    expect(packageJson.name).toBe("claude-iterm-orchestrator");
    expect(packageJson.version).toBeDefined();
    expect(packageJson.type).toBe("module");
    expect(packageJson.dependencies).toHaveProperty(
      "@modelcontextprotocol/sdk"
    );
    expect(packageJson.dependencies).toHaveProperty("zod");
  });

  it("should have valid biome.json", async () => {
    const fs = await import("node:fs/promises");
    const biomeJson = JSON.parse(await fs.readFile("biome.json", "utf-8"));

    expect(biomeJson.formatter.enabled).toBe(true);
    expect(biomeJson.linter.enabled).toBe(true);
    expect(biomeJson.javascript).toBeDefined();
  });

  it("should have valid vitest.config.js", async () => {
    const fs = await import("node:fs/promises");
    const exists = await fs
      .access("vitest.config.js")
      .then(() => true)
      .catch(() => false);

    expect(exists).toBe(true);
  });
});
