<script setup>
const commands = [
  { cmd: 'spawn', args: '[--role ROLE] [--worktree] [--label NAME]', desc: 'Spawn a new Pi worker pane. Optionally assign a role (implementer/tester/reviewer) and create an isolated git worktree.' },
  { cmd: 'task', args: '<surface> <prompt>', desc: 'Send a one-shot task to a worker surface. Worker runs the prompt and outputs the result.' },
  { cmd: 'auto', args: '<surface> <prompt>', desc: 'Same as `task` but with automatic runtime fallback. If Pi fails, falls through OpenCode → Gemini → Codex → Claude.' },
  { cmd: 'supervise', args: '<task> [--timeout N]', desc: 'Orchestrator mode — runs a task with auto-handoff across runtimes when token limits are reached. Designed for overnight builds.' },
  { cmd: 'pipeline', args: '<task> [--rounds N]', desc: 'Role-based pipeline: implementer builds, tester validates, reviewer audits. Each role gets its own isolated worktree.' },
  { cmd: 'orchestrate', args: '<surface> <task>', desc: 'Run a task on the orchestrator worker itself (not a spawned worker). Useful for orchestration logic.' },
  { cmd: 'handoff', args: '[--runtime R]', desc: 'Explicitly hand off the current orchestrator session to a different runtime. Used when approaching token limits.' },
  { cmd: 'status', args: '', desc: 'Dashboard view of all registered workers: surface ID, label, status (idle/running/done), elapsed time, and last output.' },
  { cmd: 'self-evolve', args: '', desc: 'Analyze recent task patterns and auto-extract reusable skills. The system gets smarter the more you use it.' },
  { cmd: 'nightly', args: '', desc: 'Full overnight maintenance: evolve skills + prune stale tasks + cleanup worktrees + generate report.' },
  { cmd: 'usage stats', args: '', desc: 'Per-runtime health dashboard: success rates, token usage, rate limit hits, cooldown status.' },
  { cmd: 'skill list', args: '', desc: 'List all installed skills with their trigger patterns and usage counts.' },
  { cmd: 'skill show', args: '<name>', desc: 'Show a skill\'s full documentation: description, trigger patterns, and step-by-step instructions.' },
  { cmd: 'skill extract', args: '<surface> [--name NAME]', desc: 'Extract a new skill from a completed task. Captures the task pattern for future reuse.' },
  { cmd: 'learn suggest', args: '', desc: 'Preview suggested skills based on keyword clustering of recent task history.' },
  { cmd: 'runtime list', args: '', desc: 'Show the current runtime fallback chain with order and status.' },
  { cmd: 'runtime add', args: '<entry>', desc: 'Add a runtime to the fallback chain (e.g., pi:kilo-auto/free).' },
  { cmd: 'runtime remove', args: '<index>', desc: 'Remove a runtime from the fallback chain by index.' },
  { cmd: 'close', args: '<surface>', desc: 'Exit a worker pane, optionally remove its git worktree and branch.' },
  { cmd: 'clean', args: '', desc: 'Reset all PIHARNESS state: clear outputs, logs, and registry. Does not close panes.' },
]
</script>

<template>
  <div class="commands-page">
    <div class="page-header">
      <h1>Commands</h1>
      <p>Complete reference for all PIHARNESS CLI commands.</p>
    </div>

    <div class="commands-table-wrapper">
      <table class="commands-table">
        <thead>
          <tr>
            <th class="col-cmd">Command</th>
            <th class="col-args">Arguments</th>
            <th class="col-desc">Description</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="c in commands" :key="c.cmd">
            <td class="col-cmd"><code>{{ c.cmd }}</code></td>
            <td class="col-args"><code class="args">{{ c.args }}</code></td>
            <td class="col-desc">{{ c.desc }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<style scoped>
.commands-page {
  max-width: 1000px;
  margin: 0 auto;
  padding: 3rem 1.5rem 5rem;
}

.page-header {
  text-align: center;
  margin-bottom: 3rem;
}

.page-header h1 {
  font-size: 2.2rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.page-header p {
  color: var(--text-secondary);
  font-size: 1.05rem;
}

.commands-table-wrapper {
  overflow-x: auto;
  border: 1px solid var(--border-color);
  border-radius: 10px;
  background: var(--bg-card);
}

.commands-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9rem;
}

.commands-table th {
  text-align: left;
  padding: 0.85rem 1rem;
  background: var(--bg-hover);
  font-weight: 600;
  color: var(--text-secondary);
  font-size: 0.8rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-bottom: 1px solid var(--border-color);
}

.commands-table td {
  padding: 0.85rem 1rem;
  border-bottom: 1px solid var(--border-color);
  vertical-align: top;
}

.commands-table tr:last-child td {
  border-bottom: none;
}

.commands-table code {
  font-family: 'SF Mono', 'Fira Code', monospace;
  font-size: 0.85rem;
  color: var(--accent);
}

.commands-table .args {
  color: var(--text-secondary);
  font-size: 0.8rem;
}

.col-cmd { width: 20%; }
.col-args { width: 30%; }

@media (max-width: 768px) {
  .col-args { display: none; }
}
</style>
