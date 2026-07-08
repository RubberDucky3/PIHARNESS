<script setup>
import { ref, computed } from 'vue'

const search = ref('')
const copiedCmd = ref('')

const categories = [
  { key: 'worker', label: 'Worker Management' },
  { key: 'tasks', label: 'Tasks & Dispatch' },
  { key: 'obs', label: 'Observability' },
  { key: 'pipeline', label: 'Pipelines' },
  { key: 'evolve', label: 'Self-Evolution' },
  { key: 'cleanup', label: 'Cleanup' },
]

const commands = [
  { cmd: 'spawn', args: '[--role ROLE] [--worktree] [--label NAME]', desc: 'Spawn a new Pi worker pane with optional role and git worktree isolation.', cat: 'worker' },
  { cmd: 'close', args: '<surface> [--keep-worktree]', desc: 'Exit a worker pane, optionally keep its git worktree.', cat: 'worker' },
  { cmd: 'use', args: '<surface> [--label L] [--role R]', desc: 'Register an existing cmux pane as a named worker.', cat: 'worker' },
  { cmd: 'start', args: '<surface> [--runtime TYPE:MODEL]', desc: 'Launch interactive AI in a worker pane.', cat: 'worker' },
  { cmd: 'switch', args: '<surface> [--next | --runtime R]', desc: 'Change the runtime running in a worker pane.', cat: 'worker' },
  { cmd: 'task', args: '<surface> "<prompt>"', desc: 'Send a one-shot task to a worker surface.', cat: 'tasks' },
  { cmd: 'auto', args: '<surface> "<prompt>"', desc: 'Task with automatic runtime fallback on failure.', cat: 'tasks' },
  { cmd: 'run', args: '"<prompt>"', desc: 'Run a task on the most available worker (smart default).', cat: 'tasks' },
  { cmd: 'supervise', args: '"<task>" [--timeout N]', desc: 'Overnight mode — auto-handoff across runtimes at token limits.', cat: 'tasks' },
  { cmd: 'orchestrate', args: '<surface> "<task>"', desc: 'Run a task on the orchestrator worker.', cat: 'tasks' },
  { cmd: 'handoff', args: '[--runtime R]', desc: 'Hand off orchestrator to a different runtime before token cap.', cat: 'tasks' },
  { cmd: 'status', args: '[--verbose]', desc: 'Dashboard of all workers: surface, label, status, elapsed time.', cat: 'obs' },
  { cmd: 'screen', args: '<surface>', desc: 'Live capture of a worker terminal pane.', cat: 'obs' },
  { cmd: 'watch', args: '<surface>', desc: 'Stream worker output (tail -f style).', cat: 'obs' },
  { cmd: 'log', args: '<surface>', desc: 'Show a worker\'s structured event log.', cat: 'obs' },
  { cmd: 'collect', args: '<surface>', desc: 'Read a worker\'s final output.', cat: 'obs' },
  { cmd: 'compare', args: '<s1> <s2>', desc: 'Side-by-side worker output comparison.', cat: 'obs' },
  { cmd: 'diff', args: '<s1> <s2>', desc: 'Git diff between worktree branches.', cat: 'obs' },
  { cmd: 'pipeline', args: '"<task>" [--rounds N]', desc: 'Implement → test → review cycle with role-isolated worktrees.', cat: 'pipeline' },
  { cmd: 'monitor', args: '<surface> [--daemon]', desc: 'Auto-switch watchdog for long-running tasks.', cat: 'pipeline' },
  { cmd: 'skill', args: 'list|show|new|extract|suggest', desc: 'Manage the skill library — list, inspect, create, extract.', cat: 'evolve' },
  { cmd: 'learn', args: 'track|history|suggest', desc: 'Track task patterns and preview suggested skills.', cat: 'evolve' },
  { cmd: 'self-evolve', args: '[--dry-run]', desc: 'Auto-extract skills from recent task patterns.', cat: 'evolve' },
  { cmd: 'nightly', args: '', desc: 'Full maintenance: evolve + prune + cleanup + report.', cat: 'evolve' },
  { cmd: 'clean', args: '', desc: 'Reset all worker state. Does not close panes.', cat: 'cleanup' },
  { cmd: 'usage stats', args: '', desc: 'Per-runtime success/failure dashboard.', cat: 'obs' },
  { cmd: 'usage prune', args: '', desc: 'Clean usage data older than 7 days.', cat: 'cleanup' },
  { cmd: 'runtimes', args: '[<surface>]', desc: 'Show the runtime fallback chain and status.', cat: 'obs' },
]

const catBadge = {
  worker: { bg: 'rgba(88,166,255,0.15)', text: '#58a6ff' },
  tasks: { bg: 'rgba(63,185,80,0.15)', text: '#3fb950' },
  obs: { bg: 'rgba(210,153,34,0.15)', text: '#d29922' },
  pipeline: { bg: 'rgba(210,168,255,0.15)', text: '#d2a8ff' },
  evolve: { bg: 'rgba(255,167,87,0.15)', text: '#ffa657' },
  cleanup: { bg: 'rgba(248,81,73,0.15)', text: '#f85149' },
}

const catLabel = Object.fromEntries(categories.map(c => [c.key, c.label]))

const filtered = computed(() => {
  if (!search.value.trim()) return commands
  const q = search.value.toLowerCase()
  return commands.filter(c =>
    c.cmd.includes(q) || c.desc.toLowerCase().includes(q) || catLabel[c.cat]?.toLowerCase().includes(q)
  )
})

const grouped = computed(() => {
  const map = {}
  for (const c of filtered.value) {
    if (!map[c.cat]) map[c.cat] = []
    map[c.cat].push(c)
  }
  return map
})

function copyCmd(cmd) {
  navigator.clipboard.writeText(cmd).then(() => {
    copiedCmd.value = cmd
    setTimeout(() => { copiedCmd.value = '' }, 1500)
  }).catch(() => {})
}
</script>

<template>
  <div class="commands-page">
    <div class="page-header">
      <h1>Commands</h1>
      <p>Complete reference for all PIHARNESS CLI commands.</p>
    </div>

    <div class="search-bar">
      <svg class="search-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2">
        <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
      </svg>
      <input v-model="search" type="search" placeholder="Search commands, categories…" class="search-input" />
    </div>

    <div v-for="cat in categories" :key="cat.key">
      <div v-if="grouped[cat.key]?.length" class="cat-group">
        <h2 class="cat-title">{{ cat.label }}</h2>

        <!-- Desktop table -->
        <div class="table-wrapper desktop-only">
          <table class="cmd-table">
            <tbody>
              <tr v-for="c in grouped[cat.key]" :key="c.cmd">
                <td class="col-cmd">
                  <code class="cmd-name" @click="copyCmd(c.cmd)" :title="'Click to copy'">
                    {{ c.cmd }}
                    <span class="copy-hint" v-if="copiedCmd === c.cmd">copied</span>
                  </code>
                </td>
                <td class="col-args"><code class="args-text">{{ c.args }}</code></td>
                <td class="col-desc">{{ c.desc }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <!-- Mobile cards -->
        <div class="mobile-only">
          <div v-for="c in grouped[cat.key]" :key="c.cmd" class="cmd-card">
            <div class="card-header">
              <code class="cmd-name" @click="copyCmd(c.cmd)">
                {{ c.cmd }}
                <span class="copy-hint" v-if="copiedCmd === c.cmd">copied</span>
              </code>
            </div>
            <div class="card-args"><code>{{ c.args }}</code></div>
            <div class="card-desc">{{ c.desc }}</div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="filtered.length === 0" class="empty">
      No commands match "{{ search }}"
    </div>
  </div>
</template>

<style scoped>
.commands-page { max-width: 1000px; margin: 0 auto; padding: 3rem 1.5rem 5rem; }
.page-header { text-align: center; margin-bottom: 2rem; }
.page-header h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.5rem; }
.page-header p { color: var(--text-secondary); font-size: 1.05rem; }

.search-bar {
  position: relative;
  max-width: 400px;
  margin: 0 auto 2.5rem;
}
.search-icon { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--text-secondary); pointer-events: none; }
.search-input {
  width: 100%;
  padding: 0.65rem 1rem 0.65rem 2.4rem;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  background: var(--bg-card);
  color: var(--text-primary);
  font-size: 0.9rem;
  outline: none;
  transition: border-color 0.15s;
}
.search-input:focus { border-color: var(--accent); }
.search-input::placeholder { color: var(--text-secondary); }

.cat-group { margin-bottom: 2.5rem; }
.cat-title {
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-secondary);
  margin-bottom: 0.75rem;
  padding-bottom: 0.4rem;
  border-bottom: 1px solid var(--border-color);
}

.cmd-table { width: 100%; border-collapse: collapse; font-size: 0.88rem; }
.cmd-table td { padding: 0.65rem 0.75rem; border-bottom: 1px solid var(--border-color); vertical-align: top; }
.cmd-table tr:last-child td { border-bottom: none; }
.col-cmd { width: 16%; }
.col-args { width: 30%; }

.cmd-name {
  font-family: 'SF Mono', 'Fira Code', monospace;
  font-size: 0.85rem;
  color: var(--accent);
  cursor: pointer;
  position: relative;
  white-space: nowrap;
}
.cmd-name:hover { text-decoration: underline; text-underline-offset: 2px; }

.copy-hint {
  position: absolute;
  top: -1.5rem;
  left: 50%;
  transform: translateX(-50%);
  font-size: 0.65rem;
  font-weight: 600;
  color: var(--success);
  background: rgba(63,185,80,0.12);
  padding: 0.1rem 0.4rem;
  border-radius: 4px;
  white-space: nowrap;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}

.args-text { color: var(--text-secondary); font-size: 0.8rem; font-family: 'SF Mono', 'Fira Code', monospace; }
.col-desc { color: var(--text-primary); line-height: 1.5; }

/* Mobile cards */
.mobile-only { display: none; }
.cmd-card {
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 10px;
  padding: 0.85rem 1rem;
  margin-bottom: 0.6rem;
}
.card-header { margin-bottom: 0.35rem; }
.card-args { margin-bottom: 0.4rem; }
.card-args code { font-size: 0.78rem; color: var(--text-secondary); }
.card-desc { font-size: 0.85rem; color: var(--text-primary); line-height: 1.5; }

.empty { text-align: center; padding: 3rem; color: var(--text-secondary); }

@media (max-width: 768px) {
  .desktop-only { display: none; }
  .mobile-only { display: block; }
  .search-bar { max-width: 100%; }
}
</style>
