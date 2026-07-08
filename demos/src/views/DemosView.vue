<script setup>
import DemoPlayer from '../components/DemoPlayer.vue'

const demos = [
  { id: 'demo-01-spawn-auto',   title: 'Spawn + Auto Task',      desc: 'Spawn workers and send tasks with automatic runtime fallback.' },
  { id: 'demo-02-status',       title: 'Status Dashboard',        desc: 'Real-time worker dashboard showing all active surfaces and their status.' },
  { id: 'demo-03-pipeline',     title: 'Role-Based Pipeline',     desc: 'Implementer → Tester → Reviewer pipeline with isolated worktrees.' },
  { id: 'demo-04-self-evolve',  title: 'Self-Evolution',          desc: 'Auto-extract skills from repeated task patterns.' },
  { id: 'demo-05-supervise',    title: 'Orchestrator Supervision', desc: 'Long-running tasks with auto-handoff between runtimes.' },
  { id: 'demo-06-usage',        title: 'Usage Statistics',        desc: 'Per-runtime health dashboard and usage analytics.' },
  { id: 'demo-07-skill-list',   title: 'Skills System',           desc: 'List, show, and manage installed skills.' },
]
</script>

<template>
  <div class="demos-page">
    <div class="page-header">
      <h1>Interactive Demos</h1>
      <p>Watch PIHARNESS in action. Each demo is a video recording — click to play.</p>
    </div>

    <div class="demos-grid">
      <article v-for="demo in demos" :key="demo.id" class="demo-card">
        <div class="demo-info">
          <h2 class="demo-title">{{ demo.title }}</h2>
          <p class="demo-desc">{{ demo.desc }}</p>
        </div>
        <div class="demo-player-wrapper">
          <DemoPlayer
            :src="`videos/${demo.id}.mp4`"
          />
        </div>
      </article>
    </div>
  </div>
</template>

<style scoped>
.demos-page {
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
  max-width: 600px;
  margin: 0 auto;
}

.demos-grid {
  display: flex;
  flex-direction: column;
  gap: 2.5rem;
}

.demo-card {
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-radius: 12px;
  overflow: hidden;
}

.demo-info {
  padding: 1.5rem 1.5rem 0.5rem;
}

.demo-title {
  font-size: 1.15rem;
  font-weight: 600;
  margin-bottom: 0.3rem;
}

.demo-desc {
  font-size: 0.9rem;
  color: var(--text-secondary);
}

.demo-player-wrapper {
  padding: 0 1.5rem 1.5rem;
}
</style>
