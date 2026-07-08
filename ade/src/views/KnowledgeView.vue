<script setup>
import { ref, computed, onMounted } from 'vue'
import { marked } from 'marked'

const root = ref(null)
const files = ref([])
const selected = ref(null)
const content = ref('')
const search = ref('')
let picker = null

const rendered = computed(() => marked(content.value))

function walk(dir, out = []) {
  if (!dir) return out
  const entries = [...dir.values()].filter(
    (e) => e.kind === 'directory' || e.name.endsWith('.md')
  )
  for (const e of entries) {
    if (e.kind === 'directory') {
      walk(e.createDirReader(), out)
    } else {
      out.push(e)
    }
  }
  return out
}

async function loadFiles() {
  try {
    if (picker) {
      try { await picker?.close?.() } catch {}
      picker = null
    }
    picker = root.value?.showDirectoryPicker?.()
    const base = await picker
    if (!base) return
    const entries = walk(base.createDirReader())
    files.value = await Promise.all(
      entries.map(async (entry) => ({
        name: entry.name,
        path: entry.webkitRelativePath || entry.name,
        _handle: entry,
      }))
    )
  } catch (e) {
    files.value = []
  }
}

async function openFile(file) {
  selected.value = file
  try {
    const handle = await file._handle?.getFile?.()
    content.value = await handle?.text?.()
  } catch (e) {
    content.value = '# Unable to load file'
  }
}

function filtered() {
  const q = search.value.trim().toLowerCase()
  if (!q) return files.value
  return files.value.filter((f) => f.name.toLowerCase().includes(q))
}

onMounted(() => {
  loadFiles()
})
</script>

<template>
  <div class="knowledge-view">
    <header class="view-header">
      <h1>Knowledge</h1>
      <input v-model="search" placeholder="Search notes..." />
      <button class="btn btn-primary" @click="loadFiles">Reload Vault</button>
    </header>

    <main class="knowledge-layout">
      <aside class="knowledge-sidebar">
        <div
          v-for="file in filtered()"
          :key="file.path"
          class="file-item"
          :class="{ selected: selected?.path === file.path }"
          @click="openFile(file)"
        >
          {{ file.name }}
        </div>
        <div v-if="!files.length" class="empty">No notes found.</div>
      </aside>

      <section class="knowledge-content">
        <article v-if="content" class="markdown" v-html="rendered"></article>
        <div v-else class="empty">Select a note to read.</div>
      </section>
    </main>
  </div>
</template>

<style scoped>
.knowledge-view {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--color-bg, #0d1117);
  color: var(--color-text, #c9d1d9);
}
.view-header {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 14px 20px;
  border-bottom: 1px solid var(--color-border, #30363d);
}
.view-header input {
  flex: 1;
  background: var(--bg-tertiary, #161b22);
  border: 1px solid var(--color-border, #30363d);
  color: var(--color-text, #c9d1d9);
  padding: 6px 10px;
  border-radius: 6px;
}
.knowledge-layout {
  display: flex;
  flex: 1;
  min-height: 0;
}
.knowledge-sidebar {
  width: 260px;
  border-right: 1px solid var(--color-border, #30363d);
  overflow-y: auto;
  padding: 8px;
}
.file-item {
  padding: 6px 8px;
  border-radius: 6px;
  cursor: pointer;
  font-size: 13px;
}
.file-item:hover {
  background: var(--bg-hover, #1c2128);
}
.file-item.selected {
  background: var(--accent, #58a6ff);
  color: #0d1117;
}
.knowledge-content {
  flex: 1;
  padding: 20px;
  overflow: auto;
}
.knowledge-content pre {
  white-space: pre-wrap;
  word-break: break-word;
  font-family: var(--font-mono, Menlo, monospace);
  font-size: 13px;
  line-height: 1.6;
}
.empty {
  color: var(--text-muted, #8b949e);
  font-size: 13px;
  padding: 12px;
}
</style>
