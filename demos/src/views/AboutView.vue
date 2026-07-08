<script setup>
const techStack = [
  { name: 'cmux', desc: 'Terminal multiplexer — manages surfaces, panes, and workspaces with a JSON-RPC API.' },
  { name: 'Pi', desc: 'Primary AI coding assistant (kilo-auto/free). Runs inside cmux panes as interactive workers.' },
  { name: 'OpenCode', desc: 'Orchestrator runtime — plans work, delegates to Pi workers, and synthesizes results.' },
  { name: 'Gemini / Codex / Claude', desc: 'Fallback runtimes when Pi is rate-limited or unavailable.' },
  { name: 'Ollama', desc: 'Local LLM runtime for offline operation (e.g., qwen2.5-coder).' },
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
        <p>The orchestrator (OpenCode or any compatible runtime) plans the work, delegates tasks to workers, monitors progress, and synthesizes outputs. When a worker hits a rate limit or token cap, the runtime chain automatically falls through to the next available backend.</p>
      </section>

      <section class="section">
        <h2>Architecture</h2>
        <div class="arch-diagram">
          <div class="arch-node orchestrator">
            <div class="arch-label">Orchestrator</div>
            <div class="arch-sub">OpenCode / Claude / Pi</div>
          </div>
          <div class="arch-arrow">▽ delegates to</div>
          <div class="arch-workers">
            <div class="arch-node worker">Worker A<br><span class="dim">Pi (kilo-auto)</span></div>
            <div class="arch-node worker">Worker B<br><span class="dim">Pi (kilo-auto)</span></div>
            <div class="arch-node worker">Worker C<br><span class="dim">Codex fallback</span></div>
          </div>
          <div class="arch-arrow">▽ fallback chain</div>
          <div class="arch-row">
            <div class="arch-node small">OpenCode</div>
            <div class="arch-node small">Gemini</div>
            <div class="arch-node small">Claude</div>
            <div class="arch-node small">Ollama</div>
          </div>
        </div>
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
.about-page {
  max-width: 800px;
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
  line-height: 1.6;
}

.section {
  margin-bottom: 3rem;
}

.section h2 {
  font-size: 1.4rem;
  font-weight: 600;
  margin-bottom: 1rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid var(--border-color);
}

.section p {
  color: var(--text-secondary);
  line-height: 1.7;
  margin-bottom: 0.8rem;
}

/* Architecture */
.arch-diagram {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 2rem;
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 10px;
}

.arch-node {
  padding: 0.8rem 1.5rem;
  border-radius: 8px;
  text-align: center;
  font-weight: 600;
  font-size: 0.9rem;
  line-height: 1.5;
}

.arch-node.orchestrator {
  background: var(--accent);
  color: #fff;
}

.arch-node .arch-sub {
  font-weight: 400;
  font-size: 0.8rem;
  opacity: 0.8;
}

.arch-node.worker {
  background: var(--bg-hover);
  border: 1px solid var(--border-color);
}

.arch-node .dim {
  font-weight: 400;
  font-size: 0.8rem;
  color: var(--text-secondary);
}

.arch-node.small {
  background: var(--bg-active);
  font-size: 0.8rem;
  font-weight: 400;
  padding: 0.5rem 1rem;
}

.arch-arrow {
  color: var(--text-secondary);
  font-size: 0.85rem;
}

.arch-workers {
  display: flex;
  gap: 1rem;
}

.arch-row {
  display: flex;
  gap: 0.75rem;
  flex-wrap: wrap;
  justify-content: center;
}

/* Tech Stack */
.stack-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.stack-item {
  display: flex;
  gap: 1rem;
  padding: 0.8rem 1rem;
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  font-size: 0.9rem;
}

.stack-item strong {
  min-width: 120px;
  color: var(--accent);
}

.stack-item span {
  color: var(--text-secondary);
}

/* Definitions */
.def-list dt {
  font-weight: 600;
  color: var(--accent);
  margin-top: 1.2rem;
  margin-bottom: 0.3rem;
  font-size: 1rem;
}

.def-list dd {
  color: var(--text-secondary);
  line-height: 1.6;
  margin-left: 0;
  font-size: 0.9rem;
}

@media (max-width: 600px) {
  .arch-workers { flex-direction: column; }
  .stack-item { flex-direction: column; gap: 0.3rem; }
  .stack-item strong { min-width: auto; }
}
</style>
