<script setup>
import { RouterLink, RouterView } from 'vue-router'
</script>

<template>
  <div class="app">
    <aside class="sidebar">
      <div class="brand">
        <span class="brand-icon">⬡</span>
        <span class="brand-text">PIHARNESS</span>
      </div>
      <nav class="nav">
        <RouterLink to="/" class="nav-item" active-class="active">
          <span class="nav-icon">⊞</span>
          <span class="nav-label">Workspace</span>
        </RouterLink>
        <RouterLink to="/panes" class="nav-item" active-class="active">
          <span class="nav-icon">▚</span>
          <span class="nav-label">Panes</span>
        </RouterLink>
        <RouterLink to="/agents" class="nav-item" active-class="active">
          <span class="nav-icon">◆</span>
          <span class="nav-label">Agents</span>
        </RouterLink>
        <RouterLink to="/context" class="nav-item" active-class="active">
          <span class="nav-icon">≡</span>
          <span class="nav-label">Context</span>
        </RouterLink>
        <RouterLink to="/settings" class="nav-item" active-class="active">
          <span class="nav-icon">⚙</span>
          <span class="nav-label">Settings</span>
        </RouterLink>
      </nav>
    </aside>
    <main class="main">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
.app {
  display: flex;
  height: 100vh;
  overflow: hidden;
  background: #0d1117;
  color: #c9d1d9;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
}

.sidebar {
  width: 200px;
  flex-shrink: 0;
  background: #161b22;
  border-right: 1px solid #30363d;
  display: flex;
  flex-direction: column;
  padding: 16px 0;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 0 20px 20px;
  border-bottom: 1px solid #30363d;
  margin-bottom: 12px;
}

.brand-icon {
  font-size: 20px;
  color: #58a6ff;
}

.brand-text {
  font-size: 14px;
  font-weight: 600;
  color: #f0f6fc;
  letter-spacing: 0.5px;
}

.nav {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 0 12px;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 12px;
  border-radius: 6px;
  color: #8b949e;
  text-decoration: none;
  font-size: 13px;
  font-weight: 500;
  transition: all 0.15s ease;
}

.nav-item:hover {
  background: #21262d;
  color: #c9d1d9;
}

.nav-item.active {
  background: #21262d;
  color: #f0f6fc;
  border-left: 2px solid #58a6ff;
}

.nav-icon {
  font-size: 15px;
  width: 20px;
  text-align: center;
}

.nav-label {
  white-space: nowrap;
}

.main {
  flex: 1;
  overflow: auto;
  padding: 24px;
}
</style>
