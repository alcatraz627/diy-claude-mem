import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import { execSync } from "child_process";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SCRIPTS = path.resolve(__dirname, "../scripts");

function run(script, args = []) {
  const escapedArgs = args.map(a => `'${String(a).replace(/'/g, "'\\''")}'`).join(" ");
  const cmd = `bash '${SCRIPTS}/${script}' ${escapedArgs}`.trim();
  try {
    return execSync(cmd, { encoding: "utf8", timeout: 10000 }).trim();
  } catch (e) {
    return e.stdout?.trim() || e.message || "error";
  }
}

const server = new Server(
  { name: "diy-claude-mem", version: "1.2.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "shell_tail",
      description: "Show recent shell command log entries. Use this to see what Bash commands Claude ran recently, especially background processes.",
      inputSchema: {
        type: "object",
        properties: {
          n: { type: "number", description: "Number of lines to show (default 30)" },
          date: { type: "string", description: "Date in YYYY-MM-DD format (default today)" }
        }
      }
    },
    {
      name: "shell_search",
      description: "Search shell command history across log files.",
      inputSchema: {
        type: "object",
        properties: {
          query: { type: "string", description: "Search term" },
          scope: { type: "string", enum: ["today", "week", "month", "all"], description: "Date range to search (default today)" }
        },
        required: ["query"]
      }
    },
    {
      name: "shell_active",
      description: "List active (not yet done) background shell processes from recent sessions. Checks across the last N days. Use this to see what's still running.",
      inputSchema: {
        type: "object",
        properties: {
          days: { type: "number", description: "How many days back to check (default 2)" }
        }
      }
    },
    {
      name: "shell_mark_done",
      description: "Mark a background shell process as done ([BG] → [BG:DONE]). Call this when you know a background process has finished.",
      inputSchema: {
        type: "object",
        properties: {
          session_id: { type: "string", description: "Session ID that started the process" },
          cmd: { type: "string", description: "Command fragment to match" },
          date: { type: "string", description: "Date in YYYY-MM-DD format (default today)" }
        },
        required: ["session_id", "cmd"]
      }
    },
    {
      name: "shell_stats",
      description: "Show today's shell log statistics: command count, session count, active and completed background processes, log file size.",
      inputSchema: {
        type: "object",
        properties: {
          date: { type: "string", description: "Date in YYYY-MM-DD format (default today)" }
        }
      }
    },
    {
      name: "shell_cleanup",
      description: "Delete shell log files older than 60 days.",
      inputSchema: { type: "object", properties: {} }
    },
    {
      name: "shell_append",
      description: "Manually append a shell command entry to the log.",
      inputSchema: {
        type: "object",
        properties: {
          session_id: { type: "string" },
          cmd: { type: "string" },
          is_bg: { type: "boolean", description: "Whether this is a background process" },
          pid: { type: "string", description: "Process ID if known" }
        },
        required: ["session_id", "cmd", "is_bg"]
      }
    }
  ]
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  let output = "";

  switch (name) {
    case "shell_tail":
      output = run("shell-log-tail.sh", [args.n || 30, ...(args.date ? [args.date] : [])]);
      break;
    case "shell_search":
      output = run("shell-log-search.sh", [args.query, args.scope || "today"]);
      break;
    case "shell_active":
      output = run("shell-log-active.sh", [args.days || 2]);
      break;
    case "shell_mark_done":
      output = run("shell-log-mark-done.sh", [args.session_id, args.cmd, ...(args.date ? [args.date] : [])]);
      break;
    case "shell_stats":
      output = run("shell-log-stats.sh", [...(args.date ? [args.date] : [])]);
      break;
    case "shell_cleanup":
      output = run("shell-log-cleanup.sh", []);
      break;
    case "shell_append":
      output = run("shell-log-append.sh", [args.session_id, args.cmd, args.is_bg ? "true" : "false", ...(args.pid ? [args.pid] : [])]);
      break;
    default:
      output = `Unknown tool: ${name}`;
  }

  return { content: [{ type: "text", text: output || "(no output)" }] };
});

const transport = new StdioServerTransport();
await server.connect(transport);
