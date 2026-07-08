<script setup>
const techStack = [
  { name: 'cmux', desc: 'Terminal multiplexer — manages surfaces, panes, and workspaces with a JSON-RPC API.' },
  { name: 'Pi', desc: 'Primary AI coding assistant (kilo-auto/free). Runs inside cmux panes as interactive workers.' },
  { name: 'OpenCode', desc: 'Orchestrator runtime — plans work, delegates to Pi workers, and synthesizes results.' },
  { name: 'Gemini / Codex / Claude', desc: 'Fallback runtimes when Pi is rate-limited or unavailable.' },
  { name: 'Ollama', desc: 'Local LLM runtime for offline operation (e.g., qwen2.5-coder).' },
]

const features = [
  { title: 'Multi-Pane Workers', desc: 'Spawn isolated AI workers in cmux panes, each with its own surface and worktree for conflict-free parallel work.' },
  { title: 'Auto Runtime Fallback', desc: 'A prioritized runtime chain tries Pi, then OpenCode, Codex, and Ollama — no manual switching when limits hit.' },
  { title: 'Self-Evolving Skills', desc: 'Repeated task patterns are captured as skills and reused, so the system gets faster and more consistent over time.' },
  { title: 'Session Handoff', desc: 'Orchestrator state is compacted and passed to a fresh runtime when the token limit is reached — zero lost context.' },
  { title: 'Git Worktree Isolation', desc: 'Each worker operates on its own branch, so parallel implementations never collide and review is a simple diff.' },
]

const quickSteps = [
  'Install cmux and ensure the PIHARNESS shell script is on your PATH.',
  'Run `./piharness.sh status` to verify the cmux JSON-RPC server is reachable.',
  'Start your first worker with `./piharness.sh spawn --label dev-1 --worktree`.',
  'Send a task via `./piharness.sh task dev-1 "Your coding prompt"` and collect results.',
  'Inspect runtimes or add fallback models with `./piharness.sh runtimes`.',
]
</script>

<template>
  <div class="about-page">
    <div class="page-header">
      <h1>About PIHARNESS</h1>
      <p>PIHARNESS is an AI worker orchestrator that manages multiple coding agents across cmux terminal panes, with automatic runtime fallback and self-healing capabilities.</p>
    </div>

    <div class="content">
      <section class="section">
        <h2>How It Works</h2>
        <p>At its core, PIHARNESS is a shell script that spawns AI workers inside cmux panes. Each worker runs an AI coding agent (Pi by default) that can receive tasks, execute them, and report results — all through standard terminal I/O.</p>
        <p>The orchestrator plans the work, delegates tasks to workers, monitors progress, and synthesizes outputs. When a worker hits a rate limit or token cap, the runtime chain automatically falls through to the next available backend.</p>
      </section>

      <section class="section">
        <h2>Architecture</h2>
        <div class="arch-grid">
          <div class="arch-cell orchestrator">
            <div class="arch-title">Orchestrator</div>
            <div class="arch-sub">Plans, routes, decides</div>
          </div>
          <div class="arch-cell workers">
            <div class="arch-title">Workers</div>
            <div class="arch-row">
              <div class="arch-chip">A <span>Pi</span></div>
              <div class="arch-chip">B <span>Pi</span></div>
              <div class="arch-chip">C <span>Codex</span></div>
            </div>
          </div>
          <div class="arch-cell runtime-chain">
            <div class="arch-title">Runtime Fallback Chain</div>
            <div class="chain-flow">
              <div class="chain-step">Pi</div>
              <div class="chain-arrow">→ fail →</div>
              <div class="chain-step">OpenCode</div>
              <div class="chain-arrow">→ fail →</div>
              <div class="chain-step">Codex</div>
              <div class="chain-arrow">→ fail →</div>
              <div class="chain-step">Ollama</div>
            </div>
          </div>
        </div>
      </section>

      <section class="section">
        <h2>Why PIHARNESS?</h2>
        <div class="compare-table">
          <div class="compare-row compare-header">
            <div class="compare-cell"></div>
            <div class="compare-cell">Manual</div>
            <div class="compare-cell">PIHARNESS</div>
          </div>
          <div class="compare-row">
            <div class="compare-cell">Task routing</div>
            <div class="compare-cell">Copy-paste across terminals</div>
            <div class="compare-cell good">Central dispatch + fallback</div>
          </div>
          <div class="compare-row">
            <div class="compare-cell">Parallel work</div>
            <div class="compare-cell">Tab juggling</div>
            <div class="compare-cell good">Isolated workers + worktrees</div>
          </div>
          <div class="compare-row">
            <div class="compare-cell">Rate limits</div>
            <div class="compare-cell">Manually switch accounts</div>
            <div class="compare-cell good">Auto fallback chain</div>
          </div>
          <div class="compare-row">
            <div class="compare-cell">Patterns</div>
            <div class="compare-cell">Rewritten from scratch</div>
            <div class="compare-cell good">Extracted reusable skills</div>
          </div>
        </div>
      </section>

      <section class="section">
        <h2>Features</h2>
        <div class="feature-grid">
          <div v-for="f in features" :key="f.title" class="feature-card">
            <div class="feature-title">{{ f.title }}</div>
            <p>{{ f.desc }}</p>
          </div>
        </div>
      </section>

      <section class="section">
        <h2>Quick Start</h2>
        <ol class="steps">
          <li v-for="(step, i) in quickSteps" :key="i">{{ step }}</li>
        </ol>
      </section>

      <section class="section">
        <h2>Tech Stack</h2>
        <div class="stack-list">
          <div v-for="tech in techStack" :key="tech.name" class="stack-item">
            <strong>{{ tech.name }}</strong>
            <span>{{ tech.desc }}</span>
          </div>
        </div>
      </section>

      <section class="section">
        <h2>Key Concepts</h2>
        <dl class="def-list">
          <dt>Surface</dt>
          <dd>A cmux terminal surface — each worker gets its own surface for isolated I/O.</dd>
          <dt>Worktree</dt>
          <dd>An isolated git branch/working tree. Each worker can modify code without conflicts.</dd>
          <dt>Runtime Chain</dt>
          <dd>The ordered list of AI backends. Tasks fall through the chain on failure.</dd>
          <dt>Skill</dt>
          <dd>A reusable task pattern extracted from repeated work. Skills make the system smarter over time.</dd>
          <dt>Handoff</dt>
          <dd>When the orchestrator hits its token limit, it packages its state and hands off to a fresh runtime.</dd>
        </dl>
      </section>
    </div>
  </div>
</template>

<style scoped>
.about-page { max-width: 900px; margin: 0 auto; padding: 3rem 1.5rem 5rem; }
.page-header { text-align: center; margin-bottom: 3rem; }
.page-header h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.5rem; }
.page-header p { color: var(--text-secondary); font-size: 1.05rem; line-height: 1.6; }
.section { margin-bottom: 3rem; }
.section h2 { font-size: 1.4rem; font-weight: 600; margin-bottom: 1rem; padding-bottom: 0.5rem; border-bottom: 1px solid var(--border-color); }
.section p { color: var(--text-secondary); line-height: 1.7; margin-bottom: 0.8rem; }

.arch-grid {
  display: grid;
  grid-template-columns: 140px 1fr;
  grid-template-rows: auto auto;
  gap: 0.6rem;
  padding: 1.25rem;
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 10px;
}

.arch-cell {
  background: var(--bg-hover);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 0.85rem;
}

.arch-cell.orchestrator {
  background: var(--accent);
  color: #fff;
  border-color: transparent;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.arch-title { font-weight: 700; font-size: 0.88rem; margin-bottom: 0.25rem; }
.arch-sub { font-size: 0.78rem; opacity: 0.85; }

.arch-row { display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.4rem; }
.arch-chip {
  background: var(--bg-active);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.4rem 0.6rem;
  font-size: 0.78rem;
  line-height: 1.35;
  text-align: center;
}
.arch-chip span { display: block; font-size: 0.7rem; color: var(--text-secondary); }

.runtime-chain { grid-column: 2; }
.chain-flow { display: flex; align-items: center; gap: 0.45rem; flex-wrap: wrap; }
.chain-step {
  background: var(--bg-active);
  border: 1px solid var(--border-color);
  border-radius: 6px;
  padding: 0.4rem 0.6rem;
  font-size: 0.8rem;
  font-weight: 600;
}
.chain-arrow { color: var(--text-secondary); font-size: 0.72rem; font-weight: 600; }

.compare-table { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 0.5rem; margin-top: 0.5rem; }
.compare-row { display: contents; }
.compare-header .compare-cell { font-weight: 700; color: var(--accent); }
.compare-cell {
  padding: 0.7rem 0.8rem;
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  font-size: 0.88rem;
  color: var(--text-secondary);
  line-height: 1.4;
}
.compare-cell.good { color: #4ade80; font-weight: 500; }

.feature-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 0.75rem; margin-top: 0.5rem; }
.feature-card { padding: 1rem; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; }
.feature-title { font-weight: 700; color: var(--accent); margin-bottom: 0.35rem; font-size: 0.95rem; }
.feature-card p { color: var(--text-secondary); font-size: 0.88rem; line-height: 1.5; margin: 0; }

.steps { padding-left: 1.25rem; margin-top: 0.5rem; color: var(--text-secondary); line-height: 1.75; }
.steps li { margin-bottom: 0.3rem; }

.stack-list { display: flex; flex-direction: column; gap: 0.75rem; }
.stack-item { display: flex; gap: 1rem; padding: 0.8rem 1rem; background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 8px; font-size: 0.9rem; }
.stack-item strong { min-width: 160px; color: var(--accent); }
.stack-item span { color: var(--text-secondary); }

.def-list dt { font-weight: 600; color: var(--accent); margin-top: 1.2rem; margin-bottom: 0.3rem; font-size: 1rem; }
.def-list dd { color: var(--text-secondary); line-height: 1.6; margin-left: 0; font-size: 0.9rem; }

@media (max-width: 640px) {
  .arch-grid { grid-template-columns: 1fr; }
  .runtime-chain { grid-column: 1; }
  .chain-flow { flex-direction: column; align-items: stretch; }
  .chain-arrow { text-align: center; }
  .compare-table { grid-template-columns: 1fr; }
  .compare-header { display: none; }
  .stack-item { flex-direction: column; gap: 0.3rem; }
  .stack-item strong { min-width: auto; }
}
</style>
