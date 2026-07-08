<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import TerminalPane from '../components/TerminalPane.vue'

// ── Split tree ──────────────────────────────────────
// node = { type: 'leaf', id, title, agentLabel?, role?, taskState? }
//      | { type: 'split', dir: 'row' | 'col', ratio, children: [node, node] }

let nextId = 1
function makeLeaf(meta = {}) {
  const id = nextId++
  return {
    type: 'leaf',
    id,
    title: `zsh ${id}`,
    agentLabel: meta.agentLabel || null,
    role: meta.role || null,
    taskState: meta.taskState || null,
  }
}

const tree = ref(makeLeaf())
const focusedId = ref(tree.value.id)
const editingId = ref(null)

// Flatten the tree into absolutely-positioned rectangles (percent units).
// Keeps the v-for flat so existing TerminalPane instances survive splits.
function layout(node, rect, out) {
  if (node.type === 'leaf') {
    out.push({ leaf: node, rect })
    return
  }
  const [a, b] = node.children
  const r = node.ratio ?? 0.5
  if (node.dir === 'row') {
    layout(a, { x: rect.x, y: rect.y, w: rect.w * r, h: rect.h }, out)
    layout(b, { x: rect.x + rect.w * r, y: rect.y, w: rect.w * (1 - r), h: rect.h }, out)
  } else {
    layout(a, { x: rect.x, y: rect.y, w: rect.w, h: rect.h * r }, out)
    layout(b, { x: rect.x, y: rect.y + rect.h * r, w: rect.w, h: rect.h * (1 - r) }, out)
  }
}

const leaves = computed(() => {
  const out = []
  layout(tree.value, { x: 0, y: 0, w: 100, h: 100 }, out)
  return out
})

function paneStyle(rect) {
  return {
    left: rect.x + '%',
    top: rect.y + '%',
    width: rect.w + '%',
    height: rect.h + '%',
  }
}

// ── Tree operations ─────────────────────────────────

function replaceNode(node, targetId, replacer) {
  if (node.type === 'leaf') {
    return node.id === targetId ? replacer(node) : node
  }
  return {
    ...node,
    children: [
      replaceNode(node.children[0], targetId, replacer),
      replaceNode(node.children[1], targetId, replacer),
    ],
  }
}

// Returns the tree with the leaf removed, collapsing its parent split.
// Returns null when the leaf was the root.
function removeLeaf(node, targetId) {
  if (node.type === 'leaf') {
    return node.id === targetId ? null : node
  }
  const [a, b] = node.children
  if (a.type === 'leaf' && a.id === targetId) return b
  if (b.type === 'leaf' && b.id === targetId) return a
  return {
    ...node,
    children: [removeLeaf(a, targetId), removeLeaf(b, targetId)],
  }
}

function splitLeaf(id, dir) {
  const fresh = makeLeaf()
  tree.value = replaceNode(tree.value, id, (leaf) => ({
    type: 'split',
    dir,
    ratio: 0.5,
    children: [leaf, fresh],
  }))
  focusedId.value = fresh.id
}

function closeLeaf(id) {
  const remaining = removeLeaf(tree.value, id)
  if (remaining === null) {
    // Never leave the view empty — replace the last pane with a fresh shell.
    tree.value = makeLeaf()
  } else {
    tree.value = remaining
  }
  if (focusedId.value === id) {
    const first = leaves.value[0]
    focusedId.value = first ? first.leaf.id : tree.value.id
  }
}

function splitRight(id) {
  splitLeaf(id, 'row')
}

function splitDown(id) {
  splitLeaf(id, 'col')
}

// ── Title editing ───────────────────────────────────

function startEditing(leaf) {
  editingId.value = leaf.id
}

function finishEditing(leaf, event) {
  const value = event.target.value.trim()
  if (value) leaf.title = value
  editingId.value = null
}

// ── Keyboard shortcuts ──────────────────────────────

function onKeydown(e) {
  const mod = e.metaKey || e.ctrlKey
  if (!mod) return
  if (e.key === 'd' || e.key === 'D') {
    e.preventDefault()
    if (e.shiftKey) splitDown(focusedId.value)
    else splitRight(focusedId.value)
  } else if (e.key === 'w' || e.key === 'W') {
    e.preventDefault()
    closeLeaf(focusedId.value)
  }
}

onMounted(() => {
  window.addEventListener('keydown', onKeydown)
})

onUnmounted(() => {
  window.removeEventListener('keydown', onKeydown)
})
</script>

<template>
  <div class="panes-view">
    <header class="view-header">
      <div class="title-group">
        <h1>Panes</h1>
        <span class="pane-count">{{ leaves.length }} pane{{ leaves.length !== 1 ? 's' : '' }}</span>
      </div>
      <div class="actions">
        <button class="btn btn-primary" @click="splitRight(focusedId)">+ New Pane</button>
        <span class="hint">⌘D split right · ⌘⇧D split down · ⌘W close</span>
      </div>
    </header>

    <main class="panes-grid">
      <div
        v-for="{ leaf, rect } in leaves"
        :key="leaf.id"
        class="pane-frame"
        :class="{ focused: leaf.id === focusedId }"
        :style="paneStyle(rect)"
        @mousedown="focusedId = leaf.id"
      >
        <div class="pane-bar">
          <span
            v-if="leaf.agentLabel"
            class="agent-chip"
            :class="leaf.taskState"
          >
            {{ leaf.role || leaf.agentLabel }}
          </span>
          <input
            v-if="editingId === leaf.id"
            class="pane-title-input"
            :value="leaf.title"
            autofocus
            @blur="finishEditing(leaf, $event)"
            @keydown.enter="finishEditing(leaf, $event)"
            @keydown.escape="editingId = null"
          />
          <span v-else class="pane-title" @dblclick="startEditing(leaf)">{{ leaf.title }}</span>
          <div class="pane-actions">
            <button class="pane-btn" title="Split right (⌘D)" @click.stop="splitRight(leaf.id)">⊞→</button>
            <button class="pane-btn" title="Split down (⌘⇧D)" @click.stop="splitDown(leaf.id)">⊞↓</button>
            <button class="pane-btn close" title="Close (⌘W)" @click.stop="closeLeaf(leaf.id)">✕</button>
          </div>
        </div>
        <div class="pane-body">
          <TerminalPane
            :terminalId="'panes-' + leaf.id"
            cmd="zsh"
            @closed="closeLeaf(leaf.id)"
          />
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.panes-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  color: var(--color-text, #c9d1d9);
  background: var(--color-bg, #0d1117);
}

/* ── Header ────────────────────────────── */
.view-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 20px;
  border-bottom: 1px solid var(--color-border, #30363d);
  flex-shrink: 0;
}
.title-group {
  display: flex;
  align-items: baseline;
  gap: 12px;
}
.title-group h1 {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary, #f0f6fc);
}
.pane-count {
  font-size: 12px;
  color: var(--text-muted, #8b949e);
}
.actions {
  display: flex;
  align-items: center;
  gap: 14px;
}
.hint {
  font-size: 11px;
  color: var(--text-muted, #8b949e);
  font-family: var(--font-mono, Menlo, monospace);
}
.btn {
  padding: 5px 12px;
  border-radius: 6px;
  border: 1px solid var(--color-border, #30363d);
  background: transparent;
  color: var(--color-text, #c9d1d9);
  font-size: 13px;
  cursor: pointer;
}
.btn-primary {
  background: var(--accent, #58a6ff);
  border-color: var(--accent, #58a6ff);
  color: #0d1117;
  font-weight: 600;
}
.btn-primary:hover {
  filter: brightness(1.1);
}

/* ── Tiled grid ────────────────────────── */
.panes-grid {
  position: relative;
  flex: 1;
  overflow: hidden;
  background: var(--color-border, #30363d);
}
.pane-frame {
  position: absolute;
  display: flex;
  flex-direction: column;
  border: 1px solid var(--color-border, #30363d);
  background: #0d1117;
  box-sizing: border-box;
  transition: left 0.12s ease, top 0.12s ease, width 0.12s ease, height 0.12s ease;
}
.pane-frame.focused {
  border-color: var(--accent, #58a6ff);
  z-index: 1;
}

/* ── Pane chrome ───────────────────────── */
.pane-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 3px 8px;
  background: var(--bg-tertiary, #161b22);
  border-bottom: 1px solid var(--color-border, #30363d);
  flex-shrink: 0;
  min-height: 24px;
}
.pane-title {
  font-family: var(--font-mono, Menlo, monospace);
  font-size: 11px;
  font-weight: 600;
  color: var(--text-secondary, #8b949e);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: default;
}
.pane-frame.focused .pane-title {
  color: var(--accent, #58a6ff);
}
.pane-title-input {
  font-family: var(--font-mono, Menlo, monospace);
  font-size: 11px;
  background: var(--color-surface, #161b22);
  border: 1px solid var(--accent, #58a6ff);
  border-radius: 4px;
  color: var(--color-text, #c9d1d9);
  padding: 1px 6px;
  outline: none;
  width: 140px;
}
.pane-actions {
  display: flex;
  gap: 2px;
  flex-shrink: 0;
}
.pane-btn {
  background: transparent;
  border: none;
  color: var(--text-muted, #8b949e);
  font-size: 11px;
  padding: 1px 5px;
  border-radius: 4px;
  cursor: pointer;
  line-height: 1.4;
}
.pane-btn:hover {
  background: var(--color-surface, #21262d);
  color: var(--color-text, #c9d1d9);
}
.pane-btn.close:hover {
  background: rgba(248, 81, 73, 0.15);
  color: var(--color-danger, #f85149);
}
.pane-body {
  flex: 1;
  min-height: 0;
  overflow: hidden;
}
.pane-body :deep(.terminal-pane) {
  min-height: 0;
}
.agent-chip {
  font-size: 10px;
  padding: 1px 6px;
  border-radius: 10px;
  background: var(--color-surface, #161b22);
  border: 1px solid var(--color-border, #30363d);
  color: var(--color-text-secondary, #8b949e);
  white-space: nowrap;
}
.agent-chip.running { border-color: var(--color-success, #3fb950); color: var(--color-success, #3fb950); }
.agent-chip.waiting { border-color: var(--color-warning, #d29922); color: var(--color-warning, #d29922); }
.agent-chip.failed { border-color: var(--color-danger, #f85149); color: var(--color-danger, #f85149); }
</style>
