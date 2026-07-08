<script setup>
import { ref, onMounted, computed } from 'vue'
import { invoke } from '@tauri-apps/api/core'
import TerminalPane from '../components/TerminalPane.vue'

const loading = ref(true)
const error = ref('')
const treeData = ref(null)
const connected = ref(false)
const refreshing = ref(false)

// Active leaf tracking
const activeWorkspace = ref(null)
const activeSurface = ref(null)

// Terminal target: clicking a workspace opens a shell terminal for it
const selectedWorkspace = ref(null)
const terminalCounter = ref(0)

function selectWorkspace(ws) {
  if (selectedWorkspace.value === ws.ref) {
    selectedWorkspace.value = null
    return
  }
  selectedWorkspace.value = ws.ref
  terminalCounter.value++
}

const currentTerminalId = computed(() => {
  if (!selectedWorkspace.value) return null
  return `term-${selectedWorkspace.value.replace(/[^a-zA-Z0-9-]/g, '-')}`
})

async function loadTree() {
  loading.value = true
  error.value = ''
  try {
    const raw = await invoke('cmux_tree_json')
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw
    treeData.value = parsed
    connected.value = true

    // Track active workspace/surface for visual emphasis
    const ap = parsed.active
    if (ap) {
      activeWorkspace.value = ap.workspace_ref
      activeSurface.value = ap.surface_ref
    }
  } catch (e) {
    const errMsg = typeof e === 'object' && e !== null
      ? (e.message || e.toString ? e.toString() : JSON.stringify(e))
      : String(e)
    error.value = errMsg
    connected.value = false
  } finally {
    loading.value = false
  }
}

async function createWorkspace() {
  const ts = Date.now()
  const args = `workspace create --name "ADE-${ts}"`
  try {
    await invoke('cmux_run', { args })
    await loadTree()
  } catch (e) {
    const errMsg = typeof e === 'object' && e !== null
      ? (e.message || e.toString ? e.toString() : JSON.stringify(e))
      : String(e)
    error.value = errMsg
  }
}

async function refresh() {
  refreshing.value = true
  await loadTree()
  refreshing.value = false
}

onMounted(() => {
  loadTree()
})

function surfaceIcon(type) {
  return type === 'browser' ? '\u{1F310}' : '\u{1F4BB}'
}

function paneCount(workspace) {
  return workspace.panes ? workspace.panes.length : 0
}

function surfaceCount(workspace) {
  if (!workspace.panes) return 0
  return workspace.panes.reduce((acc, p) => acc + (p.surfaces ? p.surfaces.length : 0), 0)
}

function truncate(str, limit = 50) {
  if (!str) return ''
  return str.length > limit ? str.slice(0, limit) + '\u2026' : str
}
</script>

<template>
  <div class="workspace-view">
    <header class="view-header">
      <div class="title-group">
        <h1>Workspaces</h1>
        <span class="status-badge" :class="{ online: connected, offline: !connected }">
          {{ connected ? 'Connected' : 'Disconnected' }}
        </span>
      </div>
      <div class="actions">
        <button class="btn btn-primary" @click="createWorkspace">+ New Workspace</button>
        <button class="btn btn-ghost" @click="refresh" :disabled="refreshing">
          {{ refreshing ? 'Refreshing\u2026' : 'Refresh' }}
        </button>
      </div>
    </header>

    <main class="view-main" :class="{ 'has-terminal': selectedWorkspace }">
      <!-- Loading state -->
      <div v-if="loading" class="state-msg">
        <div class="spinner"></div>
        <span>Loading workspace tree\u2026</span>
      </div>

      <!-- Error state -->
      <div v-else-if="error" class="state-msg error">
        <span class="error-icon">!</span>
        <div class="error-text">{{ error }}</div>
      </div>

      <!-- Empty state -->
      <div v-else-if="!treeData || !treeData.windows || treeData.windows.length === 0" class="state-msg">
        <span>No workspaces found. Create one with <code>+ New Workspace</code>.</span>
      </div>

      <!-- Dashboard -->
      <template v-else>
        <!-- Tree panel -->
        <div class="tree-panel">
        <!-- Summary bar -->
        <div class="summary-bar">
          <div class="stat">
            <span class="stat-val">{{ treeData.windows.length }}</span>
            <span class="stat-lbl">windows</span>
          </div>
          <div class="stat">
            <span class="stat-val">
              {{ treeData.windows.reduce((a, w) => a + (w.workspaces ? w.workspaces.length : 0), 0) }}
            </span>
            <span class="stat-lbl">workspaces</span>
          </div>
          <div class="stat">
            <span class="stat-val" v-if="activeSurface">{{ activeSurface }}</span>
            <span class="stat-val muted" v-else>--</span>
            <span class="stat-lbl">active surface</span>
          </div>
        </div>

        <!-- Window cards -->
        <div
          v-for="win in treeData.windows"
          :key="win.ref"
          class="window-section"
          :class="{ 'window-active': win.active }"
        >
          <div class="window-header">
            <span class="window-title">{{ win.current ? 'Current Window' : 'Window' }}</span>
            <span class="window-ref">{{ win.ref }}</span>
            <span class="window-counts">{{ win.workspace_count }} workspaces</span>
          </div>

          <!-- Workspace cards (clickable to open terminal) -->
          <div v-if="win.workspaces && win.workspaces.length" class="workspace-list">
            <div
              v-for="ws in win.workspaces"
              :key="ws.ref"
              class="workspace-card"
              :class="{
                'ws-active': ws.ref === activeWorkspace,
                'ws-selected': ws.selected,
                'ws-terminal-open': ws.ref === selectedWorkspace,
              }"
              @click="selectWorkspace(ws)"
              role="button"
              tabindex="0"
            >
              <!-- Workspace header row -->
              <div class="ws-header">
                <span class="ws-title">{{ ws.title || '(untitled)' }}</span>
                <span class="ws-ref">{{ ws.ref }}</span>
                <div class="ws-meta">
                  <span class="meta-badge panes">{{ paneCount(ws) }} panes</span>
                  <span class="meta-badge surfaces">{{ surfaceCount(ws) }} surfaces</span>
                  <span v-if="ws.pinned" class="meta-badge pinned">pinned</span>
                  <span v-if="ws.selected && !ws.active" class="meta-badge selected">selected</span>
                  <span v-if="ws.active" class="meta-badge active">active</span>
                </div>
              </div>

              <!-- Panes grid -->
              <div v-if="ws.panes && ws.panes.length" class="panes-grid">
                <div
                  v-for="pane in ws.panes"
                  :key="pane.ref"
                  class="pane-card"
                  :class="{ 'pane-focused': pane.focused, 'pane-active': pane.active }"
                >
                  <div class="pane-header">
                    <span class="pane-ref">{{ pane.ref }}</span>
                    <span v-if="pane.focused" class="pane-tag focused">focused</span>
                    <span v-if="pane.active && !pane.focused" class="pane-tag active">active</span>
                    <span class="pane-count">{{ pane.surface_count }} surface{{ pane.surface_count !== 1 ? 's' : '' }}</span>
                  </div>

                  <!-- Surfaces list -->
                  <div v-if="pane.surfaces && pane.surfaces.length" class="surfaces-list">
                    <div
                      v-for="surf in pane.surfaces"
                      :key="surf.ref"
                      class="surface-row"
                      :class="{
                        'surf-active': surf.active,
                        'surf-focused': surf.focused,
                        'surf-selected': surf.selected,
                        'surf-browser': surf.type === 'browser',
                        'surf-terminal': surf.type === 'terminal',
                      }"
                    >
                      <span class="surf-icon">{{ surfaceIcon(surf.type) }}</span>
                      <span class="surf-type">{{ surf.type }}</span>
                      <span class="surf-ref">{{ surf.ref }}</span>
                      <span class="surf-title" :title="surf.title">{{ truncate(surf.title, 60) }}</span>
                      <span v-if="surf.tty" class="surf-tty">{{ surf.tty }}</span>
                      <a
                        v-if="surf.url"
                        :href="surf.url"
                        target="_blank"
                        class="surf-url"
                        :title="surf.url"
                      >{{ truncate(surf.url, 40) }}</a>
                      <div class="surf-badges">
                        <span v-if="surf.active && !surf.focused" class="badge-sm active">active</span>
                        <span v-if="surf.focused" class="badge-sm focused">focused</span>
                        <span v-if="surf.selected && !surf.active && !surf.focused" class="badge-sm selected">selected</span>
                        <span v-if="surf.here" class="badge-sm here">here</span>
                      </div>
                    </div>
                  </div>
                  <div v-else class="surfaces-empty">No surfaces</div>
                </div>
              </div>

              <div v-else class="panes-empty">No panes</div>
            </div>
          </div>

          <div v-else class="workspaces-empty">No workspaces</div>
        </div>
        </div><!-- /.tree-panel -->

        <!-- Terminal panel -->
        <div v-if="selectedWorkspace && currentTerminalId" class="terminal-panel">
          <div class="terminal-header">
            <span class="terminal-label">{{ selectedWorkspace }}</span>
            <button class="btn btn-ghost btn-sm" @click="selectedWorkspace = null">Close</button>
          </div>
          <TerminalPane
            :key="terminalCounter"
            :terminalId="currentTerminalId"
            cmd="zsh"
          />
        </div>
      </template>
    </main>
  </div>
</template>

<style scoped>
.workspace-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  color: var(--color-text);
  background: var(--color-bg);
}

/* ── Header ────────────────────────────── */
.view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 20px;
  border-bottom: 1px solid var(--color-border);
  flex-shrink: 0;
}
.title-group {
  display: flex;
  align-items: center;
  gap: 12px;
}
.title-group h1 {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}
.status-badge {
  font-size: 11px;
  font-weight: 500;
  padding: 2px 10px;
  border-radius: 999px;
  letter-spacing: 0.3px;
}
.status-badge.offline {
  background: var(--color-danger-soft);
  color: var(--color-danger);
}
.status-badge.online {
  background: var(--color-success-soft);
  color: var(--color-success);
}
.actions {
  display: flex;
  gap: 8px;
}

/* ── Main scroll ────────────────────────── */
.view-main {
  flex: 1;
  padding: 16px 20px;
  overflow-y: auto;
}
.view-main.has-terminal {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
  overflow: hidden;
  padding: 12px;
}
.tree-panel {
  overflow-y: auto;
  padding-right: 4px;
}
.terminal-panel {
  display: flex;
  flex-direction: column;
  border: 1px solid var(--color-border);
  border-radius: 8px;
  overflow: hidden;
  background: #0d1117;
}
.terminal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 12px;
  background: var(--bg-tertiary);
  border-bottom: 1px solid var(--color-border);
  font-size: 12px;
  flex-shrink: 0;
}
.terminal-label {
  font-family: var(--font-mono);
  color: var(--text-secondary);
  font-weight: 600;
}
.btn-sm {
  font-size: 11px;
  padding: 2px 8px;
}

/* ── States ─────────────────────────────── */
.state-msg {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  height: 200px;
  color: var(--text-muted);
}
.state-msg.error {
  color: var(--color-danger);
}
.spinner {
  width: 20px;
  height: 20px;
  border: 2px solid var(--border-color);
  border-top-color: var(--accent);
  border-radius: 50%;
  animation: spin 0.7s linear infinite;
}
@keyframes spin {
  to { transform: rotate(360deg); }
}
.error-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: rgba(248, 81, 73, 0.15);
  color: var(--color-danger);
  font-weight: 700;
  font-size: 14px;
}
.error-text {
  max-width: 600px;
  text-align: center;
  font-family: var(--font-mono);
  font-size: 13px;
  line-height: 1.5;
  word-break: break-word;
}

/* ── Summary bar ────────────────────────── */
.summary-bar {
  display: flex;
  gap: 24px;
  margin-bottom: 16px;
  padding: 10px 16px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 8px;
}
.stat {
  display: flex;
  align-items: baseline;
  gap: 6px;
}
.stat-val {
  font-family: var(--font-mono);
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
}
.stat-val.muted {
  color: var(--text-muted);
}
.stat-lbl {
  font-size: 12px;
  color: var(--text-muted);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

/* ── Window section ─────────────────────── */
.window-section {
  margin-bottom: 16px;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  overflow: hidden;
  background: var(--color-surface);
}
.window-section.window-active {
  border-color: var(--accent);
}
.window-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  background: var(--bg-tertiary);
  border-bottom: 1px solid var(--color-border);
  font-size: 13px;
}
.window-title {
  font-weight: 600;
  color: var(--text-primary);
}
.window-ref {
  font-family: var(--font-mono);
  font-size: 12px;
  color: var(--text-muted);
}
.window-counts {
  margin-left: auto;
  font-size: 12px;
  color: var(--text-muted);
}
.window-active .window-header {
  border-left: 3px solid var(--accent);
}

/* ── Workspace cards ────────────────────── */
.workspace-list {
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.workspace-card {
  background: var(--bg-primary);
  border: 1px solid var(--color-border);
  border-radius: 8px;
  overflow: hidden;
}
.workspace-card.ws-active {
  border-color: var(--accent);
  box-shadow: 0 0 0 1px rgba(88, 166, 255, 0.15);
}
.workspace-card.ws-selected:not(.ws-active) {
  border-color: var(--warning);
}
.ws-header {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 8px;
  padding: 10px 14px;
}
.ws-title {
  font-weight: 600;
  font-size: 14px;
  color: var(--text-primary);
}
.ws-ref {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--text-muted);
}
.ws-meta {
  display: flex;
  gap: 6px;
  margin-left: auto;
  flex-wrap: wrap;
}
.meta-badge {
  font-size: 11px;
  font-weight: 500;
  padding: 1px 8px;
  border-radius: 999px;
  background: var(--bg-tertiary);
  color: var(--text-muted);
}
.meta-badge.panes { color: var(--accent); }
.meta-badge.surfaces { color: var(--color-success); }
.meta-badge.pinned { color: var(--warning); }
.meta-badge.selected { color: var(--warning); }
.meta-badge.active {
  background: rgba(88, 166, 255, 0.15);
  color: var(--accent);
}

/* ── Panes grid ─────────────────────────── */
.panes-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
  gap: 6px;
  padding: 0 14px 10px;
}
.pane-card {
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  overflow: hidden;
}
.pane-card.pane-focused {
  border-color: var(--accent);
}
.pane-card.pane-active:not(.pane-focused) {
  border-color: rgba(88, 166, 255, 0.4);
}
.pane-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 10px;
  background: var(--bg-tertiary);
  border-bottom: 1px solid var(--color-border);
  font-size: 12px;
}
.pane-ref {
  font-family: var(--font-mono);
  font-weight: 600;
  color: var(--text-secondary);
}
.pane-tag {
  font-size: 10px;
  font-weight: 600;
  padding: 1px 6px;
  border-radius: 4px;
  text-transform: uppercase;
  letter-spacing: 0.3px;
}
.pane-tag.focused {
  background: rgba(88, 166, 255, 0.15);
  color: var(--accent);
}
.pane-tag.active {
  background: rgba(63, 185, 80, 0.15);
  color: var(--color-success);
}
.pane-count {
  margin-left: auto;
  font-size: 11px;
  color: var(--text-muted);
}

/* ── Surface rows ───────────────────────── */
.surfaces-list {
  display: flex;
  flex-direction: column;
}
.surface-row {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 6px 10px;
  font-size: 12px;
  border-bottom: 1px solid var(--color-border);
  transition: background 0.1s;
}
.surface-row:last-child {
  border-bottom: none;
}
.surface-row.surf-active {
  background: rgba(88, 166, 255, 0.06);
}
.surface-row.surf-focused {
  background: rgba(88, 166, 255, 0.1);
  border-left: 2px solid var(--accent);
}
.surface-row.surf-browser {
  /* subtle tint for browser surfaces */
}
.surface-row:hover {
  background: rgba(255, 255, 255, 0.03);
}
.surf-icon {
  flex-shrink: 0;
  font-size: 14px;
  width: 20px;
  text-align: center;
}
.surf-type {
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--text-muted);
  width: 52px;
  flex-shrink: 0;
}
.surf-ref {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--text-muted);
  width: 64px;
  flex-shrink: 0;
}
.surf-title {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--text-secondary);
}
.surf-tty {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--text-muted);
  flex-shrink: 0;
}
.surf-url {
  font-family: var(--font-mono);
  font-size: 11px;
  color: var(--accent);
  flex-shrink: 0;
  max-width: 180px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  text-decoration: none;
}
.surf-url:hover {
  text-decoration: underline;
}
.surf-badges {
  display: flex;
  gap: 4px;
  flex-shrink: 0;
}
.badge-sm {
  font-size: 9px;
  font-weight: 600;
  padding: 1px 5px;
  border-radius: 3px;
  text-transform: uppercase;
  letter-spacing: 0.2px;
}
.badge-sm.active {
  background: rgba(63, 185, 80, 0.12);
  color: var(--color-success);
}
.badge-sm.focused {
  background: rgba(88, 166, 255, 0.15);
  color: var(--accent);
}
.badge-sm.selected {
  background: rgba(210, 153, 34, 0.12);
  color: var(--warning);
}
.badge-sm.here {
  background: rgba(139, 148, 158, 0.12);
  color: var(--text-muted);
}

/* ── Empty states ───────────────────────── */
.surfaces-empty,
.panes-empty,
.workspaces-empty {
  text-align: center;
  padding: 16px;
  font-size: 13px;
  color: var(--text-muted);
}
.surfaces-empty {
  padding: 12px;
  font-size: 12px;
}
</style>
