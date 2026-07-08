#!/usr/bin/env node
/**
 * piharness MCP server
 * Exposes piharness.sh commands as native MCP tools for Claude Code orchestration.
 *
 * Tools:
 *   spawn_worker        Create a new Pi worker pane (optionally with git worktree)
 *   use_pane            Register an existing cmux pane as a worker
 *   run_task            Send a pi --print task to a worker
 *   wait_worker         Block until a worker task completes
 *   get_output          Retrieve final worker output
 *   peek_output         Read partial output while worker is still running
 *   get_screen          Live capture of what the worker pane shows right now
 *   get_log             Structured event log for a worker
 *   get_status          Dashboard for all workers (status, elapsed, last line)
 *   list_workers        Table of all registered workers
 *   compare_outputs     Show both outputs side-by-side
 *   git_diff            Git diff between two workers' worktree branches
 *   close_worker        Exit pane and clean up worktree
 *   clean_all           Reset all piharness state
 *   skill_list          List installed skills
 *   skill_show          Show skill details
 *   skill_extract       Create skill from worker output
 *   learn_track         Log a task for pattern detection
 *   learn_suggest       Suggest new skills from repeated patterns
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execFileSync } from "child_process";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const HARNESS = resolve(__dirname, "../piharness.sh");

/**
 * Run piharness.sh with given args. Returns stdout+stderr as a string.
 * Never throws — errors come back as text so Claude can reason about them.
 */
function ph(args = []) {
  try {
    return execFileSync("bash", [HARNESS, ...args], {
      encoding: "utf8",
      timeout: 10_000,
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
  } catch (e) {
    const out = (e.stdout || "").trim();
    const err = (e.stderr || "").trim();
    return [out, err].filter(Boolean).join("\n") || e.message;
  }
}

/**
 * ph_wait uses a longer timeout since it blocks until the Pi task finishes.
 */
function ph_wait(surface, timeoutSecs = 300) {
  const args = ["wait", surface, "--timeout", String(timeoutSecs)];
  try {
    return execFileSync("bash", [HARNESS, ...args], {
      encoding: "utf8",
      timeout: (timeoutSecs + 10) * 1000,
      stdio: ["pipe", "pipe", "pipe"],
    }).trim();
  } catch (e) {
    const out = (e.stdout || "").trim();
    const err = (e.stderr || "").trim();
    return [out, err].filter(Boolean).join("\n") || "timeout";
  }
}

const server = new Server(
  { name: "piharness", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

// ── Tool definitions ──────────────────────────────────────────────────────────

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "spawn_worker",
      description:
        "Spawn a new Pi worker pane in cmux. Returns the surface ID (e.g. 'surface:11'). " +
        "Max 3 workers at a time (set by PIHARNESS_MAX_WORKERS). " +
        "First worker splits right from orchestrator; subsequent workers split down (horizontal). " +
        "Use worktree=true to give the worker its own isolated git branch so code changes don't conflict.",
      inputSchema: {
        type: "object",
        properties: {
          label: {
            type: "string",
            description: "Human-readable name for this worker (e.g. 'worker-a', 'gemini-run')",
          },
          cwd: {
            type: "string",
            description: "Working directory. Defaults to the PIHARNESS repo root.",
          },
          worktree: {
            type: "boolean",
            description: "If true, create an isolated git worktree + branch for this worker",
          },
          branch: {
            type: "string",
            description: "Branch name for the worktree (default: piharness/<label>)",
          },
        },
      },
    },
    {
      name: "use_pane",
      description: "Register an already-open cmux pane (e.g. the existing Pi pane) as a named worker.",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string", description: "cmux surface ID, e.g. 'surface:1'" },
          label: { type: "string", description: "Human-readable label" },
        },
      },
    },
    {
      name: "run_task",
      description:
        "Send a pi --print task to a worker. The worker runs Pi non-interactively and " +
        "saves its full output to a file. Combine with wait_worker to block until done, " +
        "or peek_output / get_screen for live observability while it runs.",
      inputSchema: {
        type: "object",
        required: ["surface", "prompt"],
        properties: {
          surface: { type: "string", description: "Worker surface ID" },
          prompt: { type: "string", description: "Task prompt to send to the Pi worker" },
        },
      },
    },
    {
      name: "wait_worker",
      description:
        "Wait for a worker task to finish. Polls the output file and returns 'done' " +
        "or 'timeout'. Use timeout_seconds to control how long to wait.",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string" },
          timeout_seconds: {
            type: "number",
            description: "Max seconds to wait (default 300)",
          },
        },
      },
    },
    {
      name: "get_output",
      description: "Get the complete output from a finished worker task.",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string" },
        },
      },
    },
    {
      name: "peek_output",
      description:
        "Read partial output from a worker while it is still running. " +
        "Useful for monitoring progress without blocking.",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string" },
        },
      },
    },
    {
      name: "get_screen",
      description:
        "Live capture of what the worker's terminal pane currently shows. " +
        "Use this to see what Pi is actively doing — streaming thoughts, tool calls, etc.",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string" },
        },
      },
    },
    {
      name: "get_log",
      description: "Show the structured event log for a worker (SPAWNED, TASK_SENT, TASK_DONE, etc.).",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string" },
        },
      },
    },
    {
      name: "get_status",
      description:
        "Dashboard view of all registered workers: status (idle/running/done), " +
        "elapsed time, and last line of output. Good for a quick health check.",
      inputSchema: {
        type: "object",
        properties: {},
      },
    },
    {
      name: "list_workers",
      description: "List all registered workers with their surface IDs, labels, and git branches.",
      inputSchema: {
        type: "object",
        properties: {},
      },
    },
    {
      name: "compare_outputs",
      description: "Show the full outputs of two workers side-by-side for review and selection.",
      inputSchema: {
        type: "object",
        required: ["surface1", "surface2"],
        properties: {
          surface1: { type: "string" },
          surface2: { type: "string" },
        },
      },
    },
    {
      name: "git_diff",
      description:
        "Git diff between two workers' worktree branches. Only works when workers were " +
        "spawned with worktree=true. Shows exactly what each worker changed.",
      inputSchema: {
        type: "object",
        required: ["surface1", "surface2"],
        properties: {
          surface1: { type: "string" },
          surface2: { type: "string" },
        },
      },
    },
    {
      name: "close_worker",
      description: "Exit the worker pane, optionally remove its git worktree and branch.",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string" },
          keep_worktree: {
            type: "boolean",
            description: "If true, keep the git worktree after closing (default: false)",
          },
        },
      },
    },
    {
      name: "clean_all",
      description: "Reset all piharness state: clear outputs, logs, and registry. Does not close panes.",
      inputSchema: {
        type: "object",
        properties: {},
      },
    },
    {
      name: "skill_list",
      description: "List installed skills with version, usage count, and creation date.",
      inputSchema: {
        type: "object",
        properties: {},
      },
    },
    {
      name: "skill_show",
      description: "Show a skill's full SKILL.md content including trigger patterns and usage guidance.",
      inputSchema: {
        type: "object",
        required: ["name"],
        properties: {
          name: { type: "string", description: "Skill name (e.g. 'prompt-escaping')" },
        },
      },
    },
    {
      name: "skill_extract",
      description: "Create a reusable skill scaffold from a finished worker's output. Auto-generates a name from the output content if --name is omitted.",
      inputSchema: {
        type: "object",
        required: ["surface"],
        properties: {
          surface: { type: "string", description: "Worker surface ID to extract from" },
          name: { type: "string", description: "Optional skill name (auto-generated from output if omitted)" },
          trigger: { type: "string", description: "Trigger pattern for matching future tasks" },
          desc: { type: "string", description: "Description of what the skill does" },
        },
      },
    },
    {
      name: "learn_track",
      description: "Log a task description with outcome for pattern detection. Used after any significant worker task to build the task history for future skill suggestions.",
      inputSchema: {
        type: "object",
        required: ["description"],
        properties: {
          description: { type: "string", description: "What the task accomplished" },
          surface: { type: "string", description: "Worker surface ID" },
          outcome: { type: "string", description: "Task outcome: success, failed" },
          skill: { type: "string", description: "Skill name if a skill was used" },
        },
      },
    },
    {
      name: "learn_suggest",
      description: "Analyze task history for repeated patterns and suggest new skills to create. Uses keyword clustering — tasks sharing 2+ keywords form a cluster. Run periodically after completing several tasks.",
      inputSchema: {
        type: "object",
        properties: {},
      },
    },
  ],
}));

// ── Tool dispatch ─────────────────────────────────────────────────────────────

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  const { name, arguments: args = {} } = req.params;
  let text = "";

  switch (name) {
    case "spawn_worker": {
      const a = ["spawn"];
      if (args.label)    a.push("--label", args.label);
      if (args.cwd)      a.push("--cwd", args.cwd);
      if (args.worktree) a.push("--worktree");
      if (args.branch)   a.push("--branch", args.branch);
      text = ph(a);
      break;
    }

    case "use_pane": {
      const a = ["use", args.surface];
      if (args.label) a.push("--label", args.label);
      text = ph(a);
      break;
    }

    case "run_task": {
      text = ph(["task", args.surface, args.prompt]);
      break;
    }

    case "wait_worker": {
      const timeout = args.timeout_seconds ?? 300;
      text = ph_wait(args.surface, timeout);
      break;
    }

    case "get_output":    text = ph(["collect", args.surface]); break;
    case "peek_output":   text = ph(["peek",    args.surface]); break;
    case "get_screen":    text = ph(["screen",  args.surface]); break;
    case "get_log":       text = ph(["log",     args.surface]); break;
    case "get_status":    text = ph(["status"]); break;
    case "list_workers":  text = ph(["list"]);   break;

    case "compare_outputs":
      text = ph(["compare", args.surface1, args.surface2]);
      break;

    case "git_diff":
      text = ph(["diff", args.surface1, args.surface2]);
      break;

    case "close_worker": {
      const a = ["close", args.surface];
      if (args.keep_worktree) a.push("--keep-worktree");
      text = ph(a);
      break;
    }

    case "clean_all":
      text = ph(["clean"]);
      break;

    case "skill_list":
      text = ph(["skill", "list"]);
      break;

    case "skill_show":
      text = ph(["skill", "show", args.name]);
      break;

    case "skill_extract": {
      const a = ["skill", "extract", args.surface];
      if (args.name)    a.push("--name",    args.name);
      if (args.trigger) a.push("--trigger", args.trigger);
      if (args.desc)    a.push("--desc",    args.desc);
      text = ph(a);
      break;
    }

    case "learn_track": {
      const a = ["learn", "track", args.description];
      if (args.surface) a.push("--surface", args.surface);
      if (args.outcome) a.push("--outcome", args.outcome);
      if (args.skill)   a.push("--skill",   args.skill);
      text = ph(a);
      break;
    }

    case "learn_suggest":
      text = ph(["learn", "suggest"]);
      break;

    default:
      text = `Unknown tool: ${name}`;
  }

  return {
    content: [{ type: "text", text: text || "(no output)" }],
  };
});

// ── Start ─────────────────────────────────────────────────────────────────────

const transport = new StdioServerTransport();
await server.connect(transport);
