<script setup>
import { useRouter } from 'vue-router'
const router = useRouter()
</script>

<template>
  <div class="not-found">
    <div class="nf-content">
      <div class="nf-code">404</div>
      <h1 class="nf-title">Page not found</h1>
      <p class="nf-desc">The surface you're looking for doesn't exist — or it timed out.</p>
      <div class="nf-actions">
        <router-link to="/" class="btn btn-primary">Back to Home</router-link>
        <button class="btn btn-secondary" @click="router.go(-1)">Go Back</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.not-found {
  max-width: 600px;
  margin: 0 auto;
  padding: 6rem 1.5rem;
  text-align: center;
}

.nf-code {
  font-size: 6rem;
  font-weight: 800;
  color: var(--accent);
  line-height: 1;
  margin-bottom: 1rem;
  font-family: 'SF Mono', 'Fira Code', monospace;
  opacity: 0.6;
}

.nf-title {
  font-size: 1.8rem;
  font-weight: 700;
  margin-bottom: 0.8rem;
}

.nf-desc {
  color: var(--text-secondary);
  font-size: 1rem;
  margin-bottom: 2rem;
  line-height: 1.6;
}

.nf-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
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
  cursor: pointer;
  border: none;
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
</style>
