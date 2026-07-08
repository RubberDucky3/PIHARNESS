<script setup>
import AnimatedTerminal from '@/components/AnimatedTerminal.vue'
import FeatureCard from '@/components/FeatureCard.vue'

const demoCommands = [
  { prompt: '$', text: './piharness.sh spawn --label worker-a --worktree' },
  { prompt: '✓', text: 'Spawning worker-a from kilo-auto/free...' },
  { prompt: '✓', text: 'worker-a ready (surface:42)' },
  { prompt: '$', text: './piharness.sh auto surface:42 "Build a CLI tool"' },
  { prompt: '▶', text: 'Routing through runtime chain...' },
  { prompt: '✓', text: 'Task running on pi:kilo-auto/free' },
  { prompt: '$', text: './piharness.sh status' },
  { prompt: '', text: '┌──────────┬─────────┬────────┐' },
  { prompt: '', text: '│ worker   │ status  │ model  │' },
  { prompt: '', text: '├──────────┼─────────┼────────┤' },
  { prompt: '', text: '│ worker-a │ running │ kilo   │' },
  { prompt: '', text: '│ worker-b │ idle    │ kilo   │' },
  { prompt: '', text: '└──────────┴─────────┴────────┘' },
  { prompt: '$', text: './piharness.sh usage stats' },
  { prompt: 'ℹ', text: 'Requests: 47 | Success: 44 (93.6%) | Avg: 3.2s' },
]
</script>

<template>
  <div class="home">
    <!-- Hero -->
    <section class="hero">
      <div class="hero-content">
        <div class="hero-badge">v1.0 — AI Worker Orchestrator</div>
        <h1 class="hero-title">Ship code <span class="accent">while you sleep</span></h1>
        <p class="hero-subtitle">
          Orchestrate multiple AI agents (Pi, OpenCode, Gemini, Codex, Claude) across cmux panes
          with automatic fallback, self-healing runtimes, and overnight self-evolution.
        </p>
        <div class="hero-actions">
          <router-link to="/demos" class="btn btn-primary">Watch Demos</router-link>
          <router-link to="/commands" class="btn btn-secondary">Commands</router-link>
        </div>
      </div>

      <!-- Terminal preview -->
      <AnimatedTerminal :commands="demoCommands" />
    </section>

    <!-- Features -->
    <section class="features">
      <div class="section-header">
        <h2>Why PIHARNESS?</h2>
        <p>Designed for developers who want maximum throughput from their AI tools.</p>
      </div>

      <div class="feature-grid">
        <FeatureCard icon="⚡" title="Multi-Runtime Fallback" description="Tasks auto-fall through Pi → OpenCode → Gemini → Codex → Claude. When one hits rate limits, the next picks up." />
        <FeatureCard icon="🔄" title="Self-Evolution" description="The system watches your task patterns and auto-extracts reusable skills. It gets smarter the more you use it." />
        <FeatureCard icon="🌙" title="Overnight Sessions" description="Start a supervised session before bed. PIHARNESS works through the night, handing off between runtimes as needed." />
        <FeatureCard icon="📊" title="Real-Time Dashboard" description="See every worker's status, model, and output — all from a single cmux terminal window." />
        <FeatureCard icon="🧠" title="Role-Based Pipelines" description="Split work across implementer, tester, and reviewer agents. Each role gets its own isolated worktree." />
        <FeatureCard icon="🔧" title="Intelligent Recovery" description="Detects rate limits, token limits, quota exhaustion, and timeouts — sets cooldowns and retries automatically." />
      </div>
    </section>

    <!-- Quick Start -->
    <section class="quickstart">
      <div class="section-header">
        <h2>Get Started in 30 Seconds</h2>
      </div>
      <div class="code-block">
        <div class="code-header">Terminal</div>
        <pre><code><span class="prompt">$</span> git clone https://github.com/your-org/PIHARNESS.git
<span class="prompt">$</span> cd PIHARNESS
<span class="prompt">$</span> ./piharness.sh spawn --label worker-a --worktree
<span class="green">✓</span> Spawned worker-a
<span class="prompt">$</span> ./piharness.sh auto surface:1 "Build a CLI tool in Python"</code></pre>
      </div>
    </section>
  </div>
</template>

<style scoped>
.home { padding-bottom: 4rem; }

/* Hero */
.hero {
  max-width: 1200px;
  margin: 0 auto;
  padding: 5rem 1.5rem 3rem;
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 4rem;
  align-items: center;
}

.hero-badge {
  display: inline-block;
  padding: 0.3rem 0.8rem;
  border-radius: 999px;
  background: var(--bg-active);
  color: var(--accent);
  font-size: 0.8rem;
  font-weight: 600;
  margin-bottom: 1rem;
}

.hero-title {
  font-size: 2.8rem;
  font-weight: 800;
  line-height: 1.15;
  margin-bottom: 1.2rem;
  color: var(--text-primary);
}

.accent { color: var(--accent); }

.hero-subtitle {
  font-size: 1.1rem;
  color: var(--text-secondary);
  line-height: 1.6;
  margin-bottom: 2rem;
}

.hero-actions {
  display: flex;
  gap: 1rem;
}

.btn {
  display: inline-flex;
  align-items: center;
  padding: 0.7rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  font-size: 0.9rem;
  text-decoration: none;
  transition: all 0.15s;
}

.btn-primary {
  background: var(--accent);
  color: #fff;
}

.btn-primary:hover { opacity: 0.9; }

.btn-secondary {
  background: var(--bg-hover);
  color: var(--text-primary);
  border: 1px solid var(--border-color);
}

.btn-secondary:hover { background: var(--bg-active); }

/* Features */
.features {
  max-width: 1200px;
  margin: 0 auto;
  padding: 4rem 1.5rem;
}

.section-header {
  text-align: center;
  margin-bottom: 3rem;
}

.section-header h2 {
  font-size: 2rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
}

.section-header p {
  color: var(--text-secondary);
  font-size: 1.05rem;
}

.feature-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1.5rem;
}

/* Quick Start */
.quickstart {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem 1.5rem;
}

.code-block {
  background: #0d1117;
  border: 1px solid var(--border-color);
  border-radius: 10px;
  overflow: hidden;
}

.code-header {
  background: #161b22;
  padding: 0.5rem 1rem;
  font-size: 0.8rem;
  color: #8b949e;
  border-bottom: 1px solid var(--border-color);
}

.code-block pre {
  padding: 1rem;
  overflow-x: auto;
  font-size: 0.85rem;
  line-height: 1.7;
  color: #c9d1d9;
}

@media (max-width: 800px) {
  .hero {
    grid-template-columns: 1fr;
    padding-top: 3rem;
    gap: 2rem;
  }
  .hero-title { font-size: 2rem; }
  .hero-actions { flex-direction: column; }
  .btn { text-align: center; justify-content: center; }
}
</style>
